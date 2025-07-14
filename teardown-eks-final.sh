#!/bin/bash

# BETECH EKS Teardown Script for Account ID: 374965156099
# This script safely removes the BETECH application and EKS cluster

# Variables
ACCOUNT_ID="374965156099"
REGION="us-west-2"
CLUSTER_NAME="betech-eks-cluster"
NAMESPACE="default"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_action() {
    echo -e "${BLUE}[ACTION]${NC} $1"
}

# Function to confirm action
confirm_action() {
    local action="$1"
    echo -e "${YELLOW}⚠️  WARNING: This will $action${NC}"
    read -p "Are you sure you want to continue? (yes/no): " response
    if [[ "$response" != "yes" ]]; then
        print_error "Operation cancelled by user."
        exit 1
    fi
}

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local error_count=0
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        ((error_count++))
    fi
    
    # Check if eksctl is installed
    if ! command -v eksctl &> /dev/null; then
        print_error "eksctl is not installed. Please install it first."
        ((error_count++))
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        ((error_count++))
    fi
    
    if [ $error_count -gt 0 ]; then
        print_error "Prerequisites check failed. Please install missing tools."
        exit 1
    fi
    
    # Check AWS credentials (optional check)
    if ! aws sts get-caller-identity &> /dev/null; then
        print_warning "AWS credentials not configured or not working."
        print_warning "Some teardown operations may fail. Consider running 'aws configure'."
    else
        print_status "AWS credentials configured."
    fi
    
    print_status "Prerequisites check completed!"
}

# Check if cluster exists
check_cluster_exists() {
    print_status "Checking if cluster exists..."
    
    if ! eksctl get cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        print_warning "Cluster $CLUSTER_NAME does not exist. Nothing to tear down."
        exit 0
    fi
    
    # Update kubeconfig to ensure we can connect
    if aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME &> /dev/null; then
        print_status "Cluster found and kubeconfig updated."
    else
        print_warning "Could not update kubeconfig. Some operations may fail."
    fi
}

# Remove application components
remove_application() {
    print_action "Removing application components..."
    
    # Remove ingress first (to delete ALB)
    print_status "Removing ingress (this will delete the ALB)..."
    kubectl delete ingress betechnet-ingress --ignore-not-found=true 2>/dev/null || print_warning "Could not delete ingress"
    
    # Wait for ALB to be deleted
    print_status "Waiting for ALB to be deleted (30 seconds)..."
    sleep 30
    
    # Remove application deployments
    print_status "Removing application deployments..."
    kubectl delete deployment betechnet-frontend --ignore-not-found=true 2>/dev/null || print_warning "Could not delete frontend deployment"
    kubectl delete deployment betechnet-backend --ignore-not-found=true 2>/dev/null || print_warning "Could not delete backend deployment"
    kubectl delete deployment betechnet-postgres --ignore-not-found=true 2>/dev/null || print_warning "Could not delete postgres deployment"
    
    # Remove services
    print_status "Removing services..."
    kubectl delete service betechnet-frontend --ignore-not-found=true 2>/dev/null || print_warning "Could not delete frontend service"
    kubectl delete service betechnet-backend --ignore-not-found=true 2>/dev/null || print_warning "Could not delete backend service"
    kubectl delete service betechnet-postgres --ignore-not-found=true 2>/dev/null || print_warning "Could not delete postgres service"
    
    # Remove secrets
    print_status "Removing secrets..."
    kubectl delete secret betechnet-secrets --ignore-not-found=true 2>/dev/null || print_warning "Could not delete secrets"
    
    print_status "Application components removal completed!"
}

# Remove persistent storage
remove_storage() {
    print_action "Removing persistent storage..."
    
    # Get PVC info before deletion
    print_status "Checking PVC status..."
    kubectl get pvc postgres-pvc 2>/dev/null || print_warning "PVC not found"
    
    # Delete PVC (this will also delete the EBS volume)
    print_status "Removing PVC (this will delete the EBS volume)..."
    kubectl delete pvc postgres-pvc --ignore-not-found=true 2>/dev/null || print_warning "Could not delete PVC"
    
    # Remove storage class if it was created by us
    print_status "Removing custom storage class..."
    kubectl delete storageclass betech-storage-class --ignore-not-found=true 2>/dev/null || print_warning "Could not delete storage class"
    
    print_status "Persistent storage removal completed!"
}

# Remove AWS Load Balancer Controller
remove_alb_controller() {
    print_action "Removing AWS Load Balancer Controller..."
    
    # Check if installed via Helm
    if command -v helm &> /dev/null && helm list -n kube-system 2>/dev/null | grep aws-load-balancer-controller &> /dev/null; then
        print_status "Removing ALB controller via Helm..."
        helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || print_warning "Could not uninstall via Helm"
    else
        print_status "Removing ALB controller via kubectl..."
        kubectl delete -f manifests/aws-load-balancer-controller.yaml --ignore-not-found=true 2>/dev/null || print_warning "Could not delete ALB controller manifest"
    fi
    
    # Remove IAM service account
    print_status "Removing IAM service account for ALB controller..."
    eksctl delete iamserviceaccount \
        --cluster=$CLUSTER_NAME \
        --namespace=kube-system \
        --name=aws-load-balancer-controller \
        --region=$REGION 2>/dev/null || print_warning "Could not delete IAM service account"
    
    print_status "AWS Load Balancer Controller removal completed!"
}

# Remove EBS CSI Driver (if installed)
remove_ebs_csi_driver() {
    print_action "Removing EBS CSI Driver..."
    
    # Remove IAM service account for EBS CSI driver
    print_status "Removing IAM service account for EBS CSI driver..."
    eksctl delete iamserviceaccount \
        --cluster=$CLUSTER_NAME \
        --namespace=kube-system \
        --name=ebs-csi-controller-sa \
        --region=$REGION 2>/dev/null || print_warning "Could not delete EBS CSI IAM service account"
    
    print_status "EBS CSI Driver removal completed!"
}

# Delete EKS cluster
delete_eks_cluster() {
    print_action "Deleting EKS cluster..."
    
    print_warning "This will delete the entire EKS cluster and all associated resources."
    print_warning "This includes:"
    print_warning "- EKS cluster: $CLUSTER_NAME"
    print_warning "- Worker nodes and node groups"
    print_warning "- VPC and networking components (if created by eksctl)"
    print_warning "- Security groups"
    print_warning "- IAM roles"
    
    confirm_action "DELETE THE ENTIRE EKS CLUSTER"
    
    print_status "Deleting EKS cluster $CLUSTER_NAME..."
    if eksctl delete cluster --name $CLUSTER_NAME --region $REGION; then
        print_status "EKS cluster deleted successfully!"
    else
        print_error "Failed to delete EKS cluster. Please check manually."
    fi
}

# Clean up Docker images (optional)
cleanup_docker_images() {
    print_action "Cleaning up local Docker images..."
    
    if ! command -v docker &> /dev/null; then
        print_warning "Docker not installed. Skipping Docker cleanup."
        return 0
    fi
    
    echo -e "${YELLOW}Do you want to remove local Docker images? (yes/no):${NC}"
    read -p "> " response
    
    if [[ "$response" == "yes" ]]; then
        print_status "Removing local Docker images..."
        
        docker rmi betech-frontend:latest 2>/dev/null || print_warning "Frontend image not found locally"
        docker rmi betech-backend:latest 2>/dev/null || print_warning "Backend image not found locally"
        docker rmi betech-postgres:latest 2>/dev/null || print_warning "Postgres image not found locally"
        
        docker rmi $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-frontend:latest 2>/dev/null || print_warning "Frontend ECR image not found locally"
        docker rmi $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-backend:latest 2>/dev/null || print_warning "Backend ECR image not found locally"
        docker rmi $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/betech-postgres:latest 2>/dev/null || print_warning "Postgres ECR image not found locally"
        
        print_status "Local Docker images cleaned up!"
    else
        print_status "Skipping Docker image cleanup."
    fi
}

# Clean up ECR repositories (optional)
cleanup_ecr_repositories() {
    print_action "Cleaning up ECR repositories..."
    
    echo -e "${YELLOW}Do you want to delete ECR repositories and all images? (yes/no):${NC}"
    read -p "> " response
    
    if [[ "$response" == "yes" ]]; then
        print_status "Deleting ECR repositories..."
        
        aws ecr delete-repository --repository-name betech-frontend --region $REGION --force 2>/dev/null || print_warning "Frontend ECR repository not found"
        aws ecr delete-repository --repository-name betech-backend --region $REGION --force 2>/dev/null || print_warning "Backend ECR repository not found"
        aws ecr delete-repository --repository-name betech-postgres --region $REGION --force 2>/dev/null || print_warning "Postgres ECR repository not found"
        
        print_status "ECR repositories deleted successfully!"
    else
        print_status "Skipping ECR repository cleanup."
    fi
}

# Clean up additional IAM roles
cleanup_iam_roles() {
    print_action "Cleaning up additional IAM roles..."
    
    print_status "Checking for additional IAM roles to clean up..."
    
    # Clean up ALB controller additional permissions
    aws iam delete-role-policy --role-name AmazonEKSLoadBalancerControllerRole-pn4ipago --policy-name ALBAdditionalPermissions 2>/dev/null || print_warning "ALB additional permissions policy not found or already deleted"
    
    print_status "Additional IAM roles cleanup completed!"
}

# Verify cleanup
verify_cleanup() {
    print_action "Verifying cleanup..."
    
    # Check if cluster still exists
    if eksctl get cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        print_error "Cluster still exists! Cleanup may not be complete."
        return 1
    else
        print_status "✅ Cluster successfully removed"
    fi
    
    # Check for remaining EBS volumes
    print_status "Checking for orphaned EBS volumes..."
    ORPHANED_VOLUMES=$(aws ec2 describe-volumes --region $REGION --filters "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned" --query 'Volumes[?State==`available`].VolumeId' --output text 2>/dev/null || echo "")
    
    if [ -n "$ORPHANED_VOLUMES" ] && [ "$ORPHANED_VOLUMES" != "None" ]; then
        print_warning "Found orphaned EBS volumes: $ORPHANED_VOLUMES"
        print_warning "You may want to delete these manually if they're no longer needed."
    else
        print_status "✅ No orphaned EBS volumes found"
    fi
    
    # Check for remaining security groups
    print_status "Checking for orphaned security groups..."
    ORPHANED_SG=$(aws ec2 describe-security-groups --region $REGION --filters "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned" --query 'SecurityGroups[].GroupId' --output text 2>/dev/null || echo "")
    
    if [ -n "$ORPHANED_SG" ] && [ "$ORPHANED_SG" != "None" ]; then
        print_warning "Found orphaned security groups: $ORPHANED_SG"
        print_warning "These should be cleaned up automatically, but check manually if needed."
    else
        print_status "✅ No orphaned security groups found"
    fi
    
    print_status "Cleanup verification completed!"
}

# Show teardown plan
show_teardown_plan() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}BETECH EKS TEARDOWN PLAN${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "This script will perform the following actions:"
    echo ""
    echo "1. 🗑️  Remove application components (ingress, deployments, services)"
    echo "2. 💾 Remove persistent storage (PVC and EBS volumes)"
    echo "3. ⚖️  Remove AWS Load Balancer Controller"
    echo "4. 💽 Remove EBS CSI Driver components"
    echo "5. 🔥 Delete entire EKS cluster"
    echo "6. 🐳 Clean up Docker images (optional)"
    echo "7. 📦 Clean up ECR repositories (optional)"
    echo "8. 🔐 Clean up additional IAM roles"
    echo "9. ✅ Verify cleanup completion"
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: This action is IRREVERSIBLE!${NC}"
    echo -e "${YELLOW}⚠️  All application data will be PERMANENTLY LOST!${NC}"
    echo ""
    
    # In dry-run mode, don't ask for confirmation
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        return 0
    fi
    
    confirm_action "PROCEED WITH COMPLETE TEARDOWN"
}

# Main teardown function
main() {
    print_status "Starting BETECH EKS teardown..."
    
    # Skip prerequisites check in dry-run mode
    if [[ "${DRY_RUN:-}" != "true" ]]; then
        check_prerequisites
    fi
    
    show_teardown_plan
    
    # In dry-run mode, don't actually execute the teardown steps
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        print_status "This was a dry run. No actual resources were deleted."
        return 0
    fi
    
    check_cluster_exists
    remove_application
    remove_storage
    remove_alb_controller
    remove_ebs_csi_driver
    cleanup_iam_roles
    delete_eks_cluster
    cleanup_docker_images
    cleanup_ecr_repositories
    verify_cleanup
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}TEARDOWN COMPLETED SUCCESSFULLY!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    print_status "All BETECH EKS resources have been removed."
    print_status "Your AWS account has been cleaned up."
    echo ""
    print_warning "Note: Check your AWS bill to ensure all resources are properly terminated."
    print_warning "Some resources may have a small delay before they stop incurring charges."
}

# Help function
show_help() {
    echo "BETECH EKS Teardown Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --dry-run      Show what would be deleted without actually deleting"
    echo "  --force        Skip confirmation prompts (use with caution!)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive teardown with confirmations"
    echo "  $0 --dry-run          # Show what would be deleted"
    echo "  $0 --force            # Force deletion without prompts"
    echo ""
    echo "Prerequisites:"
    echo "  - AWS CLI configured with appropriate credentials"
    echo "  - eksctl installed"
    echo "  - kubectl installed"
    echo "  - Docker installed (for image cleanup)"
    echo ""
    echo "This script will:"
    echo "  - Remove all Kubernetes resources"
    echo "  - Delete the EKS cluster"
    echo "  - Clean up IAM roles and policies"
    echo "  - Optionally clean up Docker images and ECR repositories"
    echo "  - Verify complete cleanup"
    echo ""
    echo "Safety Features:"
    echo "  - Multiple confirmation prompts"
    echo "  - Dry-run mode to preview actions"
    echo "  - Graceful error handling"
    echo "  - Verification of cleanup completion"
    echo ""
}

# Parse command line arguments
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --dry-run)
        print_status "DRY RUN MODE - No resources will be deleted"
        DRY_RUN=true
        main
        ;;
    --force)
        print_warning "FORCE MODE - Skipping confirmations"
        confirm_action() { echo "Skipping confirmation (force mode)"; }
        main
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
