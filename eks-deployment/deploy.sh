#!/bin/bash

# BETECH EKS Terraform Deployment Script
# Account ID: 374965156099
# Region: us-west-2

set -e

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

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Please configure AWS CLI first."
        exit 1
    fi
    
    print_status "All prerequisites are met."
}

# Initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    terraform init -upgrade
}

# Plan Terraform deployment
plan_terraform() {
    print_status "Planning Terraform deployment..."
    terraform plan -out=tfplan
}

# Apply Terraform deployment
apply_terraform() {
    print_status "Applying Terraform deployment..."
    terraform apply tfplan
    
    # Configure kubectl
    print_status "Configuring kubectl..."
    aws eks update-kubeconfig --region us-west-2 --name betech-eks-cluster
    
    # Wait for cluster to be ready
    print_status "Waiting for cluster to be ready..."
    kubectl wait --for=condition=ready nodes --all --timeout=300s
}

# Deploy Kubernetes applications
deploy_applications() {
    print_status "Deploying Kubernetes applications..."
    
    # Navigate to the parent directory to access the k8s manifests
    cd ..
    
    # Deploy storage components
    print_status "Deploying storage components..."
    kubectl apply -f persistent-volume-claim/manifests/
    
    # Deploy secrets
    print_status "Deploying secrets..."
    kubectl apply -f manifests/secrets.yaml
    
    # Deploy PostgreSQL
    print_status "Deploying PostgreSQL..."
    kubectl apply -f manifests/postgres-deployment.yaml
    kubectl wait --for=condition=available --timeout=300s deployment/betechnet-postgres
    
    # Deploy backend
    print_status "Deploying backend..."
    kubectl apply -f manifests/backend-deployment.yaml
    kubectl wait --for=condition=available --timeout=300s deployment/betechnet-backend
    
    # Deploy frontend
    print_status "Deploying frontend..."
    kubectl apply -f manifests/frontend-deployment.yaml
    kubectl wait --for=condition=available --timeout=300s deployment/betechnet-frontend
    
    # Deploy ingress
    print_status "Deploying ingress..."
    kubectl apply -f manifests/ingress.yaml
    
    cd eks-deployment
}

# Get deployment information
get_deployment_info() {
    print_status "Getting deployment information..."
    
    # Get cluster info
    echo "Cluster Information:"
    terraform output cluster_name
    terraform output cluster_endpoint
    
    # Get ECR repository URLs
    echo -e "\nECR Repository URLs:"
    terraform output ecr_repository_urls
    
    # Get LoadBalancer URL
    echo -e "\nApplication Load Balancer URL:"
    kubectl get ingress betechnet-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "ALB is still being created..."
    
    # Get kubectl config command
    echo -e "\nKubectl configuration command:"
    terraform output kubectl_config_command
    
    # Get ECR login command
    echo -e "\nECR login command:"
    terraform output ecr_login_command
}

# Main deployment function
main() {
    print_status "Starting BETECH EKS deployment..."
    
    check_prerequisites
    init_terraform
    plan_terraform
    
    # Ask for confirmation
    echo -e "\n${YELLOW}Do you want to proceed with the deployment? (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        apply_terraform
        
        # Wait for ALB controller to be ready
        print_status "Waiting for AWS Load Balancer Controller to be ready..."
        sleep 60
        
        deploy_applications
        get_deployment_info
        
        print_status "Deployment completed successfully!"
        print_warning "Please remember to:"
        print_warning "1. Update your DNS records to point to the ALB"
        print_warning "2. Configure SSL certificate in the ingress"
        print_warning "3. Build and push your container images to ECR"
    else
        print_status "Deployment cancelled."
    fi
}

# Cleanup function
cleanup() {
    print_status "Cleaning up resources..."
    
    # Delete Kubernetes resources
    cd ..
    kubectl delete -f manifests/ingress.yaml --ignore-not-found=true
    kubectl delete -f manifests/frontend-deployment.yaml --ignore-not-found=true
    kubectl delete -f manifests/backend-deployment.yaml --ignore-not-found=true
    kubectl delete -f manifests/postgres-deployment.yaml --ignore-not-found=true
    kubectl delete -f manifests/secrets.yaml --ignore-not-found=true
    kubectl delete -f persistent-volume-claim/manifests/ --ignore-not-found=true
    
    cd eks-deployment
    
    # Destroy Terraform resources
    terraform destroy -auto-approve
    
    print_status "Cleanup completed."
}

# Check command line arguments
if [ "$1" == "destroy" ]; then
    cleanup
else
    main
fi