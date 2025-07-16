#!/bin/bash

# BETECH EKS Deployment Script for Account ID: 374965156099
# This script deploys the BETECH application on EKS with ALB support

set -e

# Variables
ACCOUNT_ID="374965156099"
REGION="us-west-2"
CLUSTER_NAME="betech-eks-cluster"
NAMESPACE="default"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if eksctl is installed
    if ! command -v eksctl &> /dev/null; then
        print_error "eksctl is not installed. Please install it first."
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "All prerequisites met!"
}

# Create EKS cluster
create_eks_cluster() {
    print_status "Creating EKS cluster..."
    
    if eksctl get cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        print_warning "Cluster $CLUSTER_NAME already exists. Skipping creation."
    else
        eksctl create cluster -f manifests/eks-cluster-config.yaml
        print_status "EKS cluster created successfully!"
    fi
}

# Install AWS Load Balancer Controller
install_alb_controller() {
    print_status "Installing AWS Load Balancer Controller..."
    
    # Create IAM role for ALB controller with proper policy
    print_status "Creating IAM service account for ALB controller..."
    eksctl create iamserviceaccount \
        --cluster=$CLUSTER_NAME \
        --namespace=kube-system \
        --name=aws-load-balancer-controller \
        --role-name "AmazonEKSLoadBalancerControllerRole" \
        --attach-policy-arn=arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
        --override-existing-serviceaccounts \
        --approve \
        --region=$REGION || print_warning "IAM service account creation failed or already exists"
    
    # Install ALB controller via kubectl (more reliable than Helm for this use case)
    print_status "Installing ALB controller..."
    kubectl apply -f manifests/aws-load-balancer-controller.yaml
    
    # Wait for ALB controller to be ready
    print_status "Waiting for ALB controller to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system
    
    print_status "AWS Load Balancer Controller installed successfully!"
}

# Build and push Docker images
build_and_push_images() {
    print_status "Building and pushing Docker images..."
    
    # Login to ECR
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
    
    # Create ECR repositories if they don't exist
    aws ecr describe-repositories --repository-names betech-frontend --region $REGION || \
        aws ecr create-repository --repository-name betech-frontend --region $REGION
    
    aws ecr describe-repositories --repository-names betech-backend --region $REGION || \
        aws ecr create-repository --repository-name betech-backend --region $REGION
    
    aws ecr describe-repositories --repository-names betech-postgres --region $REGION || \
        aws ecr create-repository --repository-name betech-postgres --region $REGION
    
    # Build and push frontend image
    print_status "Building frontend image..."
    cd betech-login-frontend
    docker build -t betech-frontend:latest .
    docker tag betech-frontend:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-frontend:latest
    docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-frontend:latest
    cd ..
    
    # Build and push backend image
    print_status "Building backend image..."
    cd betech-login-backend
    docker build -t betech-backend:latest .
    docker tag betech-backend:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-backend:latest
    docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-backend:latest
    cd ..
    
    # Build and push postgres image
    print_status "Building postgres image..."
    cd betech-postgresql-db
    docker build -t betech-postgres:latest .
    docker tag betech-postgres:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-postgres:latest
    docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-postgres:latest
    cd ..
    
    print_status "All images built and pushed successfully!"
}

# Deploy storage class and PVC
deploy_storage() {
    print_status "Deploying storage components..."
    
    # Check if gp2 storage class exists (it should be default)
    if kubectl get storageclass gp2 &> /dev/null; then
        print_status "Using existing gp2 storage class"
    else
        print_warning "gp2 storage class not found, creating custom storage class..."
        kubectl apply -f persistent-volume-claim/manifests/storageclass.yaml
    fi
    
    # Apply PVC
    kubectl apply -f persistent-volume-claim/manifests/pvc.yaml
    
    # Wait for PVC to be bound
    print_status "Waiting for PVC to be bound..."
    kubectl wait --for=condition=Bound pvc/postgres-pvc --timeout=300s
    
    print_status "Storage components deployed successfully!"
}

# Deploy application components
deploy_application() {
    print_status "Deploying application components..."
    
    # Apply secrets
    kubectl apply -f manifests/secrets.yaml
    
    # Deploy PostgreSQL
    kubectl apply -f manifests/postgres-deployment.yaml
    
    # Wait for PostgreSQL to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/betechnet-postgres
    
    # Deploy backend
    kubectl apply -f manifests/backend-deployment.yaml
    
    # Wait for backend to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/betechnet-backend
    
    # Deploy frontend
    kubectl apply -f manifests/frontend-deployment.yaml
    
    # Wait for frontend to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/betechnet-frontend
    
    # Deploy ingress
    kubectl apply -f manifests/ingress.yaml
    
    print_status "Application components deployed successfully!"
}

# Get application URL
get_application_url() {
    print_status "Getting application URL..."
    
    # Wait for ALB to be provisioned
    print_status "Waiting for ALB to be provisioned (this may take a few minutes)..."
    sleep 60
    
    # Check ingress status multiple times
    for i in {1..10}; do
        ALB_URL=$(kubectl get ingress betechnet-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        
        if [ -n "$ALB_URL" ]; then
            break
        fi
        
        print_status "Waiting for ALB... (attempt $i/10)"
        sleep 30
    done
    
    if [ -n "$ALB_URL" ]; then
        print_status "✅ Application Load Balancer provisioned successfully!"
        print_status "🌐 ALB URL: $ALB_URL"
        print_status "🌐 Application URL: https://betech-app.betechsol.com/"
        print_status ""
        print_status "📋 Next steps:"
        print_status "1. Verify your DNS points betech-app.betechsol.com to $ALB_URL"
        print_status "2. Check target group health in AWS Console"
        print_status "3. Test the application at https://betech-app.betechsol.com/"
    else
        print_warning "⚠️  ALB URL not available yet."
        print_warning "Run 'kubectl get ingress' to check status later."
    fi
    
    # Show pod status
    print_status "📊 Current pod status:"
    kubectl get pods -o wide
    
    # Show PVC status
    print_status "💾 Storage status:"
    kubectl get pvc
}

# Main deployment function
main() {
    print_status "Starting BETECH EKS deployment..."
    
    check_prerequisites
    create_eks_cluster
    install_alb_controller
    build_and_push_images
    deploy_storage
    deploy_application
    get_application_url
    
    print_status "Deployment completed successfully!"
    print_status "Run 'kubectl get pods' to check the status of your pods"
    print_status "Run 'kubectl get ingress' to check the ingress status"
}

# Run main function
main "$@"
