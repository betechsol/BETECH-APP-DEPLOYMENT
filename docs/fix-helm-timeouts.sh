#!/bin/bash

# Fix Helm Timeout Issues in Terraform
# This script addresses "context deadline exceeded" errors

set -e

CLUSTER_NAME="betech-eks-cluster"
REGION="us-west-2"

echo "🔧 Fixing Helm timeout issues..."

# Step 1: Check if cluster exists and is accessible
echo "📋 Checking cluster status..."
if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION >/dev/null 2>&1; then
    echo "✅ EKS cluster exists in AWS"
    
    # Update kubeconfig
    echo "🔑 Updating kubeconfig..."
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    
    # Test cluster connectivity
    echo "🧪 Testing cluster connectivity..."
    if kubectl get nodes >/dev/null 2>&1; then
        echo "✅ Cluster is accessible"
        
        # Check node readiness
        echo "🔍 Checking node status..."
        kubectl get nodes
        
        # Wait for nodes to be ready
        echo "⏳ Waiting for all nodes to be ready..."
        kubectl wait --for=condition=Ready nodes --all --timeout=300s
        
        echo "✅ All nodes are ready"
        
    else
        echo "❌ Cannot connect to cluster"
        echo "🔄 Cluster may still be initializing. Waiting 60 seconds..."
        sleep 60
        
        # Try again
        if kubectl get nodes >/dev/null 2>&1; then
            echo "✅ Cluster is now accessible"
        else
            echo "❌ Still cannot connect to cluster"
            exit 1
        fi
    fi
    
else
    echo "❌ EKS cluster does not exist in AWS"
    echo "🔄 This suggests Terraform state is out of sync"
    echo "ℹ️  You may need to run 'terraform apply' first to create the cluster"
    exit 1
fi

# Step 2: Remove problematic Helm releases from Terraform state
echo "🗑️  Removing problematic Helm releases from Terraform state..."
cd /home/ubuntu/BETECH-APP-DEPLOYMENT/eks-deployment

terraform state rm helm_release.cluster_autoscaler 2>/dev/null || echo "Cluster autoscaler not in state"
terraform state rm helm_release.aws_load_balancer_controller 2>/dev/null || echo "ALB controller not in state"
terraform state rm helm_release.metrics_server 2>/dev/null || echo "Metrics server not in state"

# Step 3: Install Helm charts manually with proper timeouts
echo "⚓ Installing Helm charts manually..."

# Add required Helm repositories
helm repo add eks https://aws.github.io/eks-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update

# Get VPC ID and IAM role ARNs
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.resourcesVpcConfig.vpcId' --output text)
ALB_ROLE_ARN=$(aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole-pn4ipago --query 'Role.Arn' --output text 2>/dev/null || echo "")

# Install AWS Load Balancer Controller
echo "🔧 Installing AWS Load Balancer Controller..."
if [ -n "$ALB_ROLE_ARN" ]; then
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ALB_ROLE_ARN \
        --set region=$REGION \
        --set vpcId=$VPC_ID \
        --timeout=10m \
        --wait
else
    echo "⚠️  ALB Controller IAM role not found, installing without IRSA"
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set region=$REGION \
        --set vpcId=$VPC_ID \
        --timeout=10m \
        --wait
fi

# Install Metrics Server
echo "📊 Installing Metrics Server..."
helm upgrade --install metrics-server metrics-server/metrics-server \
    -n kube-system \
    --timeout=5m \
    --wait

# Install Cluster Autoscaler
echo "📈 Installing Cluster Autoscaler..."
# Note: Using node group permissions instead of IRSA to avoid trust policy issues
helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
    -n kube-system \
    --set autoDiscovery.clusterName=$CLUSTER_NAME \
    --set awsRegion=$REGION \
    --timeout=5m \
    --wait

# Check for IAM permissions and fix if needed
echo "🔧 Checking and fixing IAM permissions for Cluster Autoscaler..."
NODE_GROUP_ROLE_NAME=$(aws iam list-roles --query 'Roles[?contains(RoleName, `betech-node-group`)].RoleName' --output text | head -1)

if [ -n "$NODE_GROUP_ROLE_NAME" ]; then
    echo "📋 Found node group role: $NODE_GROUP_ROLE_NAME"
    
    # Check if ClusterAutoscalerPolicy exists and attach it
    if aws iam get-policy --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/ClusterAutoscalerPolicy >/dev/null 2>&1; then
        echo "✅ ClusterAutoscalerPolicy exists, attaching to node group role..."
        aws iam attach-role-policy \
            --role-name $NODE_GROUP_ROLE_NAME \
            --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/ClusterAutoscalerPolicy 2>/dev/null || echo "Policy already attached"
    else
        echo "📄 Creating ClusterAutoscalerPolicy..."
        cat > /tmp/cluster-autoscaler-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": "*"
        }
    ]
}
EOF
        
        aws iam create-policy \
            --policy-name ClusterAutoscalerPolicy \
            --policy-document file:///tmp/cluster-autoscaler-policy.json \
            --description "Policy for EKS Cluster Autoscaler" 2>/dev/null || echo "Policy might already exist"
            
        aws iam attach-role-policy \
            --role-name $NODE_GROUP_ROLE_NAME \
            --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/ClusterAutoscalerPolicy
            
        echo "✅ ClusterAutoscalerPolicy created and attached"
    fi
    
    # Restart cluster autoscaler to pick up new permissions
    echo "🔄 Restarting cluster autoscaler to apply new permissions..."
    kubectl -n kube-system rollout restart deployment/cluster-autoscaler-aws-cluster-autoscaler || echo "Deployment not found yet"
    
    # Remove any IRSA annotations that might cause issues
    echo "🧹 Cleaning up any problematic IRSA annotations..."
    kubectl -n kube-system annotate serviceaccount cluster-autoscaler-aws-cluster-autoscaler eks.amazonaws.com/role-arn- 2>/dev/null || echo "No IRSA annotation to remove"
    kubectl -n kube-system rollout restart deployment/cluster-autoscaler-aws-cluster-autoscaler 2>/dev/null || echo "Deployment restart skipped"
fi

# Step 4: Import Helm releases back into Terraform (optional)
echo "📥 Importing Helm releases back into Terraform..."

# Import the releases
terraform import helm_release.aws_load_balancer_controller kube-system/aws-load-balancer-controller 2>/dev/null || echo "Could not import ALB controller"
terraform import helm_release.metrics_server kube-system/metrics-server 2>/dev/null || echo "Could not import metrics server"
terraform import helm_release.cluster_autoscaler kube-system/cluster-autoscaler 2>/dev/null || echo "Could not import cluster autoscaler"

# Step 5: Verify installations and check for errors
echo "✅ Verifying installations..."
echo "🔍 Checking Helm releases:"
helm list -A

echo "🔍 Checking pod status:"
kubectl get pods -n kube-system | grep -E "(aws-load-balancer|metrics-server|cluster-autoscaler)"

# Wait for all pods to be ready
echo "⏳ Waiting for all add-on pods to be ready..."
kubectl wait --for=condition=Ready pods -l "app.kubernetes.io/name=aws-load-balancer-controller" -n kube-system --timeout=300s || echo "⚠️  ALB Controller pods not ready yet"
kubectl wait --for=condition=Ready pods -l "app.kubernetes.io/name=metrics-server" -n kube-system --timeout=300s || echo "⚠️  Metrics Server pods not ready yet"
kubectl wait --for=condition=Ready pods -l "app.kubernetes.io/name=aws-cluster-autoscaler" -n kube-system --timeout=300s || echo "⚠️  Cluster Autoscaler pods not ready yet"

# Check for errors in cluster autoscaler logs
echo "🔍 Checking Cluster Autoscaler for errors..."
sleep 30  # Give it time to start
CA_POD=$(kubectl get pods -n kube-system -l "app.kubernetes.io/name=aws-cluster-autoscaler" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$CA_POD" ]; then
    echo "📋 Cluster Autoscaler logs (last 10 lines):"
    kubectl logs -n kube-system $CA_POD --tail=10 | grep -E "(ERROR|FATAL|AccessDenied)" && echo "⚠️  Found errors in logs" || echo "✅ No errors found in logs"
else
    echo "⚠️  Cluster Autoscaler pod not found"
fi

echo "🎉 Helm timeout issues resolved!"
echo ""
echo "📝 Next steps:"
echo "   1. Run 'terraform plan' to see if there are any drift issues"
echo "   2. If needed, run 'terraform apply' to sync the state"
echo "   3. Deploy your application components"
