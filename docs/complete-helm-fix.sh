#!/bin/bash

echo "🔧 Completing Helm timeout fix - IAM permissions and verification..."

CLUSTER_NAME="betech-eks-cluster"
NODE_GROUP_ROLE_NAME="betech-node-group-eks-node-group-20250713223323474900000002"
ACCOUNT_ID="374965156099"

# Check if ClusterAutoscalerPolicy exists
echo "📋 Checking ClusterAutoscalerPolicy..."
if aws iam get-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/ClusterAutoscalerPolicy >/dev/null 2>&1; then
    echo "✅ ClusterAutoscalerPolicy exists"
    aws iam attach-role-policy \
        --role-name $NODE_GROUP_ROLE_NAME \
        --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/ClusterAutoscalerPolicy 2>/dev/null || echo "Policy already attached"
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
        --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/ClusterAutoscalerPolicy
        
    echo "✅ ClusterAutoscalerPolicy created and attached"
fi

# Remove any IRSA annotations that might cause issues
echo "🧹 Cleaning up any problematic IRSA annotations..."
kubectl -n kube-system annotate serviceaccount cluster-autoscaler-aws-cluster-autoscaler eks.amazonaws.com/role-arn- 2>/dev/null || echo "No IRSA annotation to remove"

# Restart cluster autoscaler to pick up new permissions
echo "🔄 Restarting cluster autoscaler to apply new permissions..."
kubectl -n kube-system rollout restart deployment/cluster-autoscaler-aws-cluster-autoscaler

# Wait for deployment to be ready
echo "⏳ Waiting for cluster autoscaler to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cluster-autoscaler-aws-cluster-autoscaler -n kube-system

echo "✅ Verifying installations..."
echo "🔍 Checking Helm releases:"
helm list -A

echo ""
echo "🔍 Checking pod status:"
kubectl get pods -n kube-system | grep -E "(aws-load-balancer|metrics-server|cluster-autoscaler)"

echo ""
echo "🔍 Checking Cluster Autoscaler for errors..."
sleep 15  # Give it time to start
CA_POD=$(kubectl get pods -n kube-system -l "app.kubernetes.io/name=aws-cluster-autoscaler" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$CA_POD" ]; then
    echo "📋 Cluster Autoscaler logs (last 10 lines):"
    kubectl logs -n kube-system $CA_POD --tail=10 | grep -E "(ERROR|FATAL|AccessDenied)" && echo "⚠️  Found errors in logs" || echo "✅ No errors found in logs"
else
    echo "⚠️  Cluster Autoscaler pod not found"
fi

echo ""
echo "🎉 Helm installations completed successfully!"
echo ""
echo "📝 Next steps:"
echo "   1. Import Helm releases back into Terraform (optional)"
echo "   2. Run 'terraform plan' to see if there are any drift issues" 
echo "   3. Deploy application components"
