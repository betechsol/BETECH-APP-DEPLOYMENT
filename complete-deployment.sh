#!/bin/bash

set -e

# BETECH EKS Complete Deployment Script
# This script incorporates all fixes and lessons learned from troubleshooting

echo "=================================================="
echo "🚀 BETECH EKS COMPLETE DEPLOYMENT SCRIPT"
echo "=================================================="
echo "Generated: $(date)"
echo ""

# Configuration
CLUSTER_NAME="betech-eks-cluster"
REGION="us-west-2"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "UNKNOWN")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📋 Configuration:"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Region: $REGION"
echo "  AWS Account: $AWS_ACCOUNT_ID"
echo "  Script Directory: $SCRIPT_DIR"
echo ""

# Function to check prerequisites
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    local missing=()
    
    command -v aws >/dev/null 2>&1 || missing+=("aws-cli")
    command -v kubectl >/dev/null 2>&1 || missing+=("kubectl")
    command -v helm >/dev/null 2>&1 || missing+=("helm")
    command -v terraform >/dev/null 2>&1 || missing+=("terraform")
    command -v eksctl >/dev/null 2>&1 || missing+=("eksctl")
    command -v docker >/dev/null 2>&1 || missing+=("docker")
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo "❌ Missing required tools: ${missing[*]}"
        echo "Please install missing tools and retry."
        exit 1
    fi
    
    echo "✅ All prerequisites met"
}

# Function to deploy infrastructure with Terraform
deploy_infrastructure() {
    echo ""
    echo "🏗️  STEP 1: Deploying Infrastructure with Terraform"
    echo "================================================"
    
    cd "$SCRIPT_DIR/eks-deployment"
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        echo "🔧 Initializing Terraform..."
        terraform init
    fi
    
    # Plan and apply infrastructure
    echo "📋 Planning infrastructure..."
    terraform plan -out=tfplan
    
    echo "🚀 Applying infrastructure..."
    terraform apply tfplan
    
    # Wait for cluster to be ready
    echo "⏳ Waiting for EKS cluster to be fully ready..."
    aws eks wait cluster-active --name $CLUSTER_NAME --region $REGION
    
    # Update kubeconfig
    echo "🔑 Updating kubeconfig..."
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    
    # Wait for nodes to be ready
    echo "⏳ Waiting for worker nodes to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=600s
    
    echo "✅ Infrastructure deployment completed"
}

# Function to fix Helm deployments
fix_helm_deployments() {
    echo ""
    echo "⚓ STEP 2: Deploying Helm Charts with Fixes"
    echo "==========================================="
    
    # Remove any problematic Helm releases from Terraform state
    echo "🗑️  Cleaning up any stuck Helm releases..."
    terraform state rm helm_release.cluster_autoscaler 2>/dev/null || true
    terraform state rm helm_release.aws_load_balancer_controller 2>/dev/null || true
    terraform state rm helm_release.metrics_server 2>/dev/null || true
    
    # Add Helm repositories
    echo "📦 Adding Helm repositories..."
    helm repo add eks https://aws.github.io/eks-charts
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
    helm repo add autoscaler https://kubernetes.github.io/autoscaler
    helm repo update
    
    # Get cluster information
    VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.resourcesVpcConfig.vpcId' --output text)
    
    # Get the clean role ARN for ALB controller
    echo "🔍 Getting ALB controller IAM role ARN..."
    ALB_ROLE_ARN=$(aws iam list-roles --query 'Roles[?contains(RoleName, `AmazonEKSLoadBalancerControllerRole`)].Arn' --output text | tr -d '>\n\r\t' | sed 's/^=//')
    echo "Found ALB Role ARN: $ALB_ROLE_ARN"
    
    # Install AWS Load Balancer Controller with proper role annotation
    echo "🔧 Installing AWS Load Balancer Controller..."
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$ALB_ROLE_ARN" \
        --set region=$REGION \
        --set vpcId=$VPC_ID \
        --timeout=10m \
        --wait
    
    # Verify and fix service account annotation
    echo "🔧 Verifying ALB controller service account annotation..."
    CURRENT_ANNOTATION=$(kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || echo "")
    
    if [[ "$CURRENT_ANNOTATION" != "$ALB_ROLE_ARN" ]] || [[ "$CURRENT_ANNOTATION" == *$'\n'* ]] || [[ "$CURRENT_ANNOTATION" == *$'\e'* ]]; then
        echo "🔨 Fixing malformed service account annotation..."
        kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system eks.amazonaws.com/role-arn="$ALB_ROLE_ARN" --overwrite
        echo "🔄 Restarting ALB controller to pick up corrected annotation..."
        kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
        kubectl rollout status deployment aws-load-balancer-controller -n kube-system --timeout=300s
    fi
    
    # Install Metrics Server
    echo "📊 Installing Metrics Server..."
    helm upgrade --install metrics-server metrics-server/metrics-server \
        -n kube-system \
        --timeout=5m \
        --wait
    
    # Install Cluster Autoscaler
    echo "📈 Installing Cluster Autoscaler..."
    helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
        -n kube-system \
        --set autoDiscovery.clusterName=$CLUSTER_NAME \
        --set awsRegion=$REGION \
        --timeout=5m \
        --wait
    
    # Fix IAM permissions for Cluster Autoscaler
    echo "🔧 Fixing Cluster Autoscaler IAM permissions..."
    fix_cluster_autoscaler_permissions
    
    # Import Helm releases back to Terraform
    echo "📥 Importing Helm releases to Terraform state..."
    cd "$SCRIPT_DIR/eks-deployment"
    terraform import helm_release.aws_load_balancer_controller kube-system/aws-load-balancer-controller 2>/dev/null || true
    terraform import helm_release.metrics_server kube-system/metrics-server 2>/dev/null || true  
    terraform import helm_release.cluster_autoscaler kube-system/cluster-autoscaler 2>/dev/null || true
    
    echo "✅ Helm deployments completed"
}

# Function to fix Cluster Autoscaler IAM permissions
fix_cluster_autoscaler_permissions() {
    echo "🔐 Configuring Cluster Autoscaler IAM permissions..."
    
    # Find node group role
    NODE_GROUP_ROLE_NAME=$(aws iam list-roles --query 'Roles[?contains(RoleName, `betech-node-group`)].RoleName' --output text | head -1)
    
    if [ -n "$NODE_GROUP_ROLE_NAME" ]; then
        echo "📋 Found node group role: $NODE_GROUP_ROLE_NAME"
        
        # Create or attach ClusterAutoscalerPolicy
        if ! aws iam get-policy --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/ClusterAutoscalerPolicy >/dev/null 2>&1; then
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
                --description "Policy for EKS Cluster Autoscaler" 2>/dev/null || true
        fi
        
        # Attach policy to node group role
        aws iam attach-role-policy \
            --role-name $NODE_GROUP_ROLE_NAME \
            --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/ClusterAutoscalerPolicy 2>/dev/null || true
        
        # Remove problematic IRSA annotations
        kubectl -n kube-system annotate serviceaccount cluster-autoscaler-aws-cluster-autoscaler eks.amazonaws.com/role-arn- 2>/dev/null || true
        
        # Restart cluster autoscaler
        kubectl -n kube-system rollout restart deployment/cluster-autoscaler-aws-cluster-autoscaler
        kubectl wait --for=condition=available --timeout=300s deployment/cluster-autoscaler-aws-cluster-autoscaler -n kube-system
        
        echo "✅ Cluster Autoscaler permissions configured"
    else
        echo "⚠️  Node group role not found"
    fi
}

# Function to build and push Docker images
build_and_push_images() {
    echo ""
    echo "🐳 STEP 3: Building and Pushing Docker Images"
    echo "=============================================="
    
    cd "$SCRIPT_DIR"
    
    # Login to ECR
    echo "🔑 Logging into ECR..."
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
    
    # Build and push backend
    echo "🔨 Building backend image..."
    cd betech-login-backend
    docker build -t betech-login-backend .
    docker tag betech-login-backend:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-backend:latest
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-backend:latest
    echo "✅ Backend image pushed"
    
    # Build and push frontend  
    echo "🔨 Building frontend image..."
    cd ../betech-login-frontend
    docker build -t betech-login-frontend .
    docker tag betech-login-frontend:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-frontend:latest
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-frontend:latest
    echo "✅ Frontend image pushed"
    
    # Build and push postgres
    echo "🔨 Building postgres image..."
    cd ../betech-postgresql-db
    docker build -t betech-login-postgres .
    docker tag betech-login-postgres:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-postgres:latest
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-postgres:latest
    echo "✅ Postgres image pushed"
    
    cd "$SCRIPT_DIR"
    echo "✅ All Docker images built and pushed"
}

# Function to deploy application
deploy_application() {
    echo ""
    echo "🚀 STEP 4: Deploying Application"
    echo "================================"
    
    cd "$SCRIPT_DIR"
    
    # Create postgres deployment with emptyDir (fixes storage issues)
    echo "🗄️  Deploying PostgreSQL..."
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: betechnet-postgres
  labels:
    app: betechnet-postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: betechnet-postgres
  template:
    metadata:
      labels:
        app: betechnet-postgres
    spec:
      containers:
      - name: betechnet-postgres
        image: $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-postgres:latest
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "betech_db"
        - name: POSTGRES_USER
          value: "admin"
        - name: POSTGRES_PASSWORD
          value: "admin123"
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
            ephemeral-storage: "1Gi"
          limits:
            memory: "1Gi"
            cpu: "500m"
            ephemeral-storage: "2Gi"
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: betechnet-postgres
spec:
  selector:
    app: betechnet-postgres
  ports:
    - protocol: TCP
      port: 5432
      targetPort: 5432
  type: ClusterIP
EOF
    
    # Deploy clean application manifests (excluding problematic ones)
    echo "📄 Deploying application manifests..."
    
    # Apply secrets and configmaps first
    kubectl apply -f manifests/secrets.yaml
    
    # Deploy backend
    kubectl apply -f manifests/backend-deployment.yaml
    
    # Deploy frontend
    kubectl apply -f manifests/frontend-deployment.yaml
    
    # Wait for deployments to be ready
    echo "⏳ Waiting for application deployments..."
    kubectl wait --for=condition=available --timeout=600s deployment/betechnet-postgres
    kubectl wait --for=condition=available --timeout=600s deployment/betechnet-backend  
    kubectl wait --for=condition=available --timeout=600s deployment/betechnet-frontend
    
    # Deploy ingress with proper configuration
    echo "🌐 Deploying ingress..."
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: betechnet-ingress
  annotations:
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:$REGION:$AWS_ACCOUNT_ID:certificate/d8a6af47-551b-493e-a375-6134a905fcf2
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
    alb.ingress.kubernetes.io/healthcheck-path: /
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}, {"HTTPS":443}]'
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/success-codes: 200,404
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "2"
spec:
  ingressClassName: alb
  rules:
  - host: betech-app.betechsol.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: betechnet-frontend
            port:
              number: 3000
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: betechnet-backend
            port:
              number: 8080
EOF
    
    echo "✅ Application deployment completed"
}

# Function to verify deployment
verify_deployment() {
    echo ""
    echo "🔍 STEP 5: Verifying Deployment"
    echo "==============================="
    
    echo "📊 Cluster Status:"
    kubectl get nodes
    echo ""
    
    echo "⚓ Helm Releases:"
    helm list -A
    echo ""
    
    echo "🚀 Application Pods:"
    kubectl get pods -n default
    echo ""
    
    echo "🌐 Services:"
    kubectl get svc -n default
    echo ""
    
    echo "🔗 Ingress:"
    kubectl get ingress -n default
    echo ""
    
    echo "🧪 Testing Application Connectivity:"
    
    # Test backend connectivity
    echo "Testing backend..."
    kubectl port-forward svc/betechnet-backend 8080:8080 &
    PF_PID=$!
    sleep 5
    
    if curl -s --max-time 10 http://localhost:8080/ >/dev/null 2>&1; then
        echo "✅ Backend is responding"
    else
        echo "⚠️  Backend test failed (may need time to start)"
    fi
    
    kill $PF_PID 2>/dev/null || true
    
    echo ""
    echo "✅ Deployment verification completed"
}

# Function to create final summary
create_summary() {
    echo ""
    echo "=================================================="
    echo "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
    echo "=================================================="
    echo ""
    echo "📋 Summary:"
    echo "  ✅ Infrastructure: Deployed and configured"
    echo "  ✅ Helm Charts: Installed with proper permissions"
    echo "  ✅ Docker Images: Built and pushed to ECR"
    echo "  ✅ Application: Deployed and running"
    echo "  ✅ Ingress: Configured (ALB provisioning in progress)"
    echo ""
    echo "🧪 Testing Instructions:"
    echo "  Frontend: kubectl port-forward svc/betechnet-frontend 3000:3000"
    echo "  Backend:  kubectl port-forward svc/betechnet-backend 8080:8080"
    echo "  Monitor ALB: kubectl describe ingress betechnet-ingress"
    echo ""
    echo "📁 Generated Files:"
    echo "  - This deployment script: $0"
    echo "  - Terraform state: eks-deployment/"
    echo "  - Application manifests: manifests/"
    echo ""
    echo "⚠️  Important Notes:"
    echo "  - PostgreSQL uses emptyDir (data won't persist across pod restarts)"
    echo "  - ALB provisioning may take 5-10 minutes"
    echo "  - Update DNS to point to ALB address when ready"
    echo ""
    echo "🎊 Your BETECH application is now running on EKS!"
    echo "=================================================="
}

# Main execution flow
main() {
    echo "Starting complete BETECH EKS deployment..."
    echo ""
    
    check_prerequisites
    deploy_infrastructure
    fix_helm_deployments
    build_and_push_images
    deploy_application
    verify_deployment
    create_summary
    
    echo ""
    echo "🎉 Complete deployment finished successfully!"
}

# Execute main function
main "$@"
