#!/bin/bash

# BETECH EKS Terraform Deployment Script
# Account ID: 374965156099
# Region: us-west-2
# Updated with lessons learned from successful deployment

set -e
set -o pipefail

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
    
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install Helm first."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
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
    
    # Fix EKS cluster access for current IAM role
    print_status "Setting up EKS cluster access..."
    CURRENT_ROLE_ARN=$(aws sts get-caller-identity --query 'Arn' --output text | sed 's/:assumed-role\/\([^\/]*\)\/.*/:role\/\1/')
    
    # Add current IAM role to EKS cluster access entries
    print_status "Adding IAM role to EKS cluster access entries..."
    aws eks create-access-entry \
        --cluster-name betech-eks-cluster \
        --principal-arn "$CURRENT_ROLE_ARN" \
        --type STANDARD \
        --region us-west-2 2>/dev/null || echo "Access entry may already exist"
    
    # Associate cluster admin policy
    aws eks associate-access-policy \
        --cluster-name betech-eks-cluster \
        --principal-arn "$CURRENT_ROLE_ARN" \
        --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy" \
        --access-scope type=cluster \
        --region us-west-2 2>/dev/null || echo "Policy may already be associated"
    
    # Update kubeconfig again after access setup
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
    
    # First, install required infrastructure components
    print_status "Installing EBS CSI Driver..."
    kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.35" || echo "EBS CSI Driver may already be installed"
    
    # Get EBS CSI driver role ARN and annotate service account
    cd eks-deployment
    EBS_ROLE_ARN=$(terraform output -raw ebs_csi_driver_role_arn)
    cd ..
    
    print_status "Configuring EBS CSI Driver with IAM role..."
    kubectl annotate serviceaccount ebs-csi-controller-sa -n kube-system \
        eks.amazonaws.com/role-arn="$EBS_ROLE_ARN" --overwrite
    
    # Restart EBS CSI controller to pick up annotation
    kubectl rollout restart deployment/ebs-csi-controller -n kube-system
    kubectl wait --for=condition=available --timeout=120s deployment/ebs-csi-controller -n kube-system
    
    # Install AWS Load Balancer Controller
    print_status "Installing AWS Load Balancer Controller..."
    cd eks-deployment
    ALB_ROLE_ARN=$(terraform output -raw load_balancer_controller_role_arn)
    cd ..
    
    # Add Helm repo if not exists
    helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || echo "EKS repo already exists"
    helm repo update
    
    # Install ALB Controller
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        --namespace kube-system \
        --set clusterName=betech-eks-cluster \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$ALB_ROLE_ARN" \
        --set region=us-west-2
    
    # Fix ALB Controller permissions
    print_status "Adding additional EC2 permissions for ALB Controller..."
    ALB_ROLE_NAME=$(echo "$ALB_ROLE_ARN" | cut -d'/' -f2)
    aws iam put-role-policy --role-name "$ALB_ROLE_NAME" --policy-name AdditionalEC2Permissions --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:CreateSecurityGroup",
                    "ec2:AuthorizeSecurityGroupIngress",
                    "ec2:AuthorizeSecurityGroupEgress",
                    "ec2:DeleteSecurityGroup",
                    "ec2:RevokeSecurityGroupIngress",
                    "ec2:RevokeSecurityGroupEgress",
                    "ec2:CreateTags",
                    "ec2:DeleteTags"
                ],
                "Resource": "*"
            }
        ]
    }'
    
    # Wait for ALB controller to be ready
    kubectl wait --for=condition=available --timeout=180s deployment/aws-load-balancer-controller -n kube-system
    
    # Build and push Docker images
    print_status "Building and pushing Docker images to ECR..."
    if [ -f "build-and-push-images.sh" ]; then
        chmod +x build-and-push-images.sh
        ./build-and-push-images.sh
    else
        print_warning "build-and-push-images.sh not found. Please ensure Docker images are available in ECR."
    fi
    
    # Deploy storage components
    print_status "Deploying storage components..."
    kubectl apply -f persistent-volume-claim/manifests/
    
    # Wait for storage class to be ready
    sleep 10
    
    # Deploy secrets
    print_status "Deploying secrets..."
    kubectl apply -f manifests/secrets.yaml
    
    # Deploy PostgreSQL
    print_status "Deploying PostgreSQL..."
    kubectl apply -f manifests/postgres-deployment.yaml
    
    # Wait for PostgreSQL with better error handling
    print_status "Waiting for PostgreSQL to be ready..."
    for i in {1..30}; do
        if kubectl get pods -l app=betechnet-postgres | grep -q "Running"; then
            print_status "PostgreSQL is running"
            break
        elif [ $i -eq 30 ]; then
            print_error "PostgreSQL failed to start within timeout"
            kubectl logs -l app=betechnet-postgres --tail=20
            exit 1
        else
            echo "Waiting for PostgreSQL... ($i/30)"
            sleep 10
        fi
    done
    
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
    
    # Wait for ALB to be provisioned
    print_status "Waiting for Application Load Balancer to be provisioned..."
    for i in {1..20}; do
        ALB_ADDRESS=$(kubectl get ingress betechnet-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
        if [ -n "$ALB_ADDRESS" ]; then
            print_status "ALB is ready: $ALB_ADDRESS"
            break
        elif [ $i -eq 20 ]; then
            print_warning "ALB is still being provisioned. Check events for any issues."
            kubectl get events --sort-by=.metadata.creationTimestamp | tail -5
        else
            echo "Waiting for ALB... ($i/20)"
            sleep 30
        fi
    done
    
    cd eks-deployment
}

# Get deployment information
get_deployment_info() {
    print_status "Getting deployment information..."
    
    # Get cluster info
    echo ""
    echo "🏗️ Cluster Information:"
    echo "======================="
    echo "Cluster Name: $(terraform output -raw cluster_name)"
    echo "Cluster Endpoint: $(terraform output -raw cluster_endpoint)"
    echo ""
    
    # Get ECR repository URLs
    echo "🏪 ECR Repository URLs:"
    echo "======================"
    terraform output ecr_repository_urls
    echo ""
    
    # Get LoadBalancer URL
    echo "🌐 Application Load Balancer:"
    echo "============================="
    ALB_HOSTNAME=$(kubectl get ingress betechnet-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$ALB_HOSTNAME" ]; then
        echo "ALB URL: http://$ALB_HOSTNAME"
        echo "HTTPS URL: https://$ALB_HOSTNAME"
        echo ""
        echo "🔗 Application URLs:"
        echo "Frontend: http://$ALB_HOSTNAME"
        echo "Backend API: http://$ALB_HOSTNAME/api"
    else
        echo "ALB is still being created. Check status with:"
        echo "kubectl get ingress betechnet-ingress"
    fi
    echo ""
    
    # Get kubectl config command
    echo "⚙️ Useful Commands:"
    echo "=================="
    echo "Kubectl config: $(terraform output -raw kubectl_config_command)"
    echo "ECR login: $(terraform output -raw ecr_login_command)"
    echo ""
    
    # Display application status
    echo "📊 Application Status:"
    echo "====================="
    kubectl get pods -l 'app in (betechnet-postgres,betechnet-backend,betechnet-frontend)' -o wide
    echo ""
}

# Verification function
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Check cluster access
    if ! kubectl get nodes &> /dev/null; then
        print_error "Cannot access Kubernetes cluster"
        return 1
    fi
    
    # Check all pods are running
    print_status "Checking pod status..."
    if ! kubectl get pods -l 'app in (betechnet-postgres,betechnet-backend,betechnet-frontend)' | grep -v "Running" | grep -q "0/"; then
        print_status "All application pods are running"
    else
        print_warning "Some pods may not be fully ready yet"
    fi
    
    # Check ingress
    print_status "Checking ingress status..."
    ALB_ADDRESS=$(kubectl get ingress betechnet-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$ALB_ADDRESS" ]; then
        print_status "Load balancer is ready: $ALB_ADDRESS"
        
        # Test connectivity (optional)
        print_status "Testing load balancer connectivity..."
        if curl -s --connect-timeout 10 "http://$ALB_ADDRESS" > /dev/null; then
            print_status "Load balancer is responding to requests"
        else
            print_warning "Load balancer may still be initializing"
        fi
    else
        print_warning "Load balancer is still being provisioned"
    fi
    
    print_status "Deployment verification completed"
}

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=$1
    print_error "Error occurred in deployment script at line $line_number (exit code: $exit_code)"
    print_error "Checking cluster status for debugging..."
    
    # Basic debugging information
    if command -v kubectl &> /dev/null; then
        echo ""
        echo "Cluster nodes:"
        kubectl get nodes 2>/dev/null || echo "Unable to get nodes"
        
        echo ""
        echo "Recent events:"
        kubectl get events --sort-by=.metadata.creationTimestamp | tail -10 2>/dev/null || echo "Unable to get events"
        
        echo ""
        echo "Pod status:"
        kubectl get pods -A 2>/dev/null || echo "Unable to get pods"
    fi
    
    echo ""
    print_error "Deployment failed. You can:"
    print_error "1. Check the error above and retry"
    print_error "2. Run './deploy.sh destroy' to clean up and start over"
    print_error "3. Debug manually using kubectl commands"
    
    exit $exit_code
}

# Set error trap
trap 'handle_error $LINENO' ERR

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
        # Run deployment verification
        verify_deployment
        
        print_status "Deployment completed successfully!"
        print_status ""
        print_status "🎉 BETECH EKS DEPLOYMENT COMPLETED! 🎉"
        print_status ""
        print_warning "📋 Next Steps:"
        print_warning "1. Update DNS records to point 'betech-app.betechsol.com' to the ALB"
        print_warning "2. SSL certificate is configured in the ingress for HTTPS"
        print_warning "3. Monitor application health and logs"
        print_warning "4. Set up monitoring and alerting as needed"
    else
        print_status "Deployment cancelled."
    fi
}

# Cleanup function
cleanup() {
    print_status "Cleaning up resources..."
    
    # Delete Kubernetes resources
    cd ..
    
    print_status "Removing ingress and load balancer..."
    kubectl delete -f manifests/ingress.yaml --ignore-not-found=true
    
    print_status "Removing application deployments..."
    kubectl delete -f manifests/frontend-deployment.yaml --ignore-not-found=true
    kubectl delete -f manifests/backend-deployment.yaml --ignore-not-found=true
    kubectl delete -f manifests/postgres-deployment.yaml --ignore-not-found=true
    
    print_status "Removing secrets and storage..."
    kubectl delete -f manifests/secrets.yaml --ignore-not-found=true
    kubectl delete -f persistent-volume-claim/manifests/ --ignore-not-found=true
    
    print_status "Removing Helm releases..."
    helm uninstall aws-load-balancer-controller -n kube-system --ignore-not-found || echo "ALB Controller not found"
    
    print_status "Removing EBS CSI Driver..."
    kubectl delete -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.35" --ignore-not-found=true || echo "EBS CSI Driver cleanup completed"
    
    cd eks-deployment
    
    # Wait a bit for cleanup to complete
    print_status "Waiting for resources to be cleaned up..."
    sleep 30
    
    # Empty ECR repositories before destroying infrastructure
    print_status "Emptying ECR repositories..."
    ACCOUNT_ID="374965156099"
    REGION="us-west-2"
    
    # List of ECR repositories to clean
    ECR_REPOS=("betech-backend" "betech-frontend" "betech-postgres")
    
    for repo in "${ECR_REPOS[@]}"; do
        print_status "Emptying ECR repository: $repo"
        
        # Get list of image tags in the repository
        IMAGE_TAGS=$(aws ecr list-images --repository-name "$repo" --region "$REGION" --query 'imageIds[*].imageTag' --output text 2>/dev/null || echo "")
        
        if [ -n "$IMAGE_TAGS" ] && [ "$IMAGE_TAGS" != "None" ]; then
            # Delete all images in the repository
            for tag in $IMAGE_TAGS; do
                print_status "Deleting image: $repo:$tag"
                aws ecr batch-delete-image \
                    --repository-name "$repo" \
                    --region "$REGION" \
                    --image-ids imageTag="$tag" >/dev/null 2>&1 || echo "Failed to delete $repo:$tag (may not exist)"
            done
        fi
        
        # Also delete any untagged images
        UNTAGGED_IMAGES=$(aws ecr list-images --repository-name "$repo" --region "$REGION" --filter tagStatus=UNTAGGED --query 'imageIds[*].imageDigest' --output text 2>/dev/null || echo "")
        
        if [ -n "$UNTAGGED_IMAGES" ] && [ "$UNTAGGED_IMAGES" != "None" ]; then
            for digest in $UNTAGGED_IMAGES; do
                print_status "Deleting untagged image: $repo@$digest"
                aws ecr batch-delete-image \
                    --repository-name "$repo" \
                    --region "$REGION" \
                    --image-ids imageDigest="$digest" >/dev/null 2>&1 || echo "Failed to delete untagged image (may not exist)"
            done
        fi
        
        print_status "ECR repository $repo is now empty"
    done
    
    # Destroy Terraform resources
    print_status "Destroying Terraform infrastructure..."
    terraform destroy -auto-approve
    
    print_status "Cleanup completed."
}

# Check command line arguments
if [ "$1" == "destroy" ]; then
    cleanup
else
    main
fi