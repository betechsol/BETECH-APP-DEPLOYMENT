#!/bin/bash

# BETECH EKS Teardown Script
# Safely removes all BETECH EKS resources

ACCOUNT_ID="374965156099"
REGION="us-west-2"
CLUSTER_NAME="betech-eks-cluster"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_action() { echo -e "${BLUE}[ACTION]${NC} $1"; }

show_help() {
    cat << 'EOF'
BETECH EKS Teardown Script

Usage: ./teardown-eks.sh [OPTIONS]

Options:
  --help, -h     Show this help message
  --dry-run      Show what would be deleted without actually deleting
  --force        Skip confirmation prompts (use with caution!)

Examples:
  ./teardown-eks.sh                    # Interactive teardown with confirmations
  ./teardown-eks.sh --dry-run          # Show what would be deleted
  ./teardown-eks.sh --force            # Force deletion without prompts

This script safely removes all BETECH EKS resources including:
- Kubernetes deployments and services
- Application Load Balancer (ALB)
- Persistent storage (EBS volumes)
- EKS cluster and node groups
- IAM roles and policies
- Optionally: Docker images and ECR repositories

WARNING: This action is IRREVERSIBLE!
EOF
}

show_teardown_plan() {
    echo -e "${BLUE}========================================"
    echo -e "BETECH EKS TEARDOWN PLAN"
    echo -e "========================================${NC}"
    echo ""
    echo "This script will delete the following resources:"
    echo ""
    echo "1. 🗑️  Application components (ingress, deployments, services)"
    echo "2. 💾 Persistent storage (PVC and EBS volumes)"
    echo "3. ⚖️  AWS Load Balancer Controller"
    echo "4. 💽 EBS CSI Driver components"
    echo "5. 🔥 EKS cluster and all associated resources"
    echo "6. 📦 ECR repositories (optional)"
    echo "7. 🔐 Additional IAM policies"
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: This action is IRREVERSIBLE!"
    echo -e "⚠️  All application data will be PERMANENTLY LOST!${NC}"
    echo ""
    echo "Cluster: $CLUSTER_NAME"
    echo "Region: $REGION"
    echo "Account: $ACCOUNT_ID"
    echo ""
}

confirm_action() {
    local action="$1"
    echo -e "${YELLOW}⚠️  WARNING: This will $action${NC}"
    read -p "Are you sure you want to continue? (yes/no): " response
    if [[ "$response" != "yes" ]]; then
        print_error "Operation cancelled by user."
        exit 1
    fi
}

check_prerequisites() {
    local errors=0
    
    if ! command -v kubectl >/dev/null 2>&1; then
        print_error "kubectl not found"
        ((errors++))
    fi
    
    if ! command -v eksctl >/dev/null 2>&1; then
        print_error "eksctl not found"
        ((errors++))
    fi
    
    if ! command -v aws >/dev/null 2>&1; then
        print_error "aws CLI not found"
        ((errors++))
    fi
    
    if [ $errors -gt 0 ]; then
        print_error "Missing required tools. Please install them first."
        exit 1
    fi
    
    print_status "Prerequisites check passed"
}

execute_teardown() {
    print_status "Starting teardown execution..."
    
    # Check if cluster exists
    if ! eksctl get cluster --name $CLUSTER_NAME --region $REGION >/dev/null 2>&1; then
        print_warning "Cluster $CLUSTER_NAME does not exist. Nothing to tear down."
        exit 0
    fi
    
    # Update kubeconfig
    print_status "Updating kubeconfig..."
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME 2>/dev/null || {
        print_warning "Could not update kubeconfig. Continuing..."
    }
    
    # Remove application components
    print_action "Removing application components..."
    kubectl delete ingress betechnet-ingress --ignore-not-found=true 2>/dev/null || true
    print_status "Waiting 30 seconds for ALB deletion..."
    sleep 30
    
    kubectl delete deployment betechnet-frontend betechnet-backend betechnet-postgres --ignore-not-found=true 2>/dev/null || true
    kubectl delete service betechnet-frontend betechnet-backend betechnet-postgres --ignore-not-found=true 2>/dev/null || true
    kubectl delete secret betechnet-secrets --ignore-not-found=true 2>/dev/null || true
    kubectl delete pvc postgres-pvc --ignore-not-found=true 2>/dev/null || true
    
    # Remove controllers
    print_action "Removing AWS Load Balancer Controller..."
    eksctl delete iamserviceaccount \
        --cluster=$CLUSTER_NAME \
        --namespace=kube-system \
        --name=aws-load-balancer-controller \
        --region=$REGION 2>/dev/null || true
    
    print_action "Removing EBS CSI Driver..."
    eksctl delete iamserviceaccount \
        --cluster=$CLUSTER_NAME \
        --namespace=kube-system \
        --name=ebs-csi-controller-sa \
        --region=$REGION 2>/dev/null || true
    
    # Clean up IAM policies
    print_action "Cleaning up additional IAM policies..."
    aws iam delete-role-policy \
        --role-name AmazonEKSLoadBalancerControllerRole-pn4ipago \
        --policy-name ALBAdditionalPermissions 2>/dev/null || true
    
    # Ask about ECR cleanup
    if [[ "${FORCE_MODE:-}" != "true" ]]; then
        echo -e "${YELLOW}Do you want to delete ECR repositories? (yes/no):${NC}"
        read -p "> " ecr_response
    else
        ecr_response="no"
    fi
    
    if [[ "$ecr_response" == "yes" ]]; then
        print_action "Deleting ECR repositories..."
        aws ecr delete-repository --repository-name betech-frontend --region $REGION --force 2>/dev/null || true
        aws ecr delete-repository --repository-name betech-backend --region $REGION --force 2>/dev/null || true
        aws ecr delete-repository --repository-name betech-postgres --region $REGION --force 2>/dev/null || true
    fi
    
    # Delete cluster
    print_action "Deleting EKS cluster..."
    if [[ "${FORCE_MODE:-}" != "true" ]]; then
        confirm_action "DELETE THE ENTIRE EKS CLUSTER"
    fi
    
    print_status "Deleting cluster... This may take 10-15 minutes."
    if eksctl delete cluster --name $CLUSTER_NAME --region $REGION; then
        print_status "✅ EKS cluster deleted successfully!"
    else
        print_error "Failed to delete EKS cluster"
        exit 1
    fi
    
    # Verify
    print_action "Verifying cleanup..."
    if eksctl get cluster --name $CLUSTER_NAME --region $REGION >/dev/null 2>&1; then
        print_error "Cluster still exists!"
        exit 1
    else
        print_status "✅ Cluster successfully removed"
    fi
    
    print_status "🎉 Teardown completed successfully!"
}

main() {
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --dry-run)
            print_status "DRY RUN MODE - No resources will be deleted"
            show_teardown_plan
            print_status "This was a dry run. No actual resources were deleted."
            exit 0
            ;;
        --force)
            print_warning "FORCE MODE - Skipping confirmations"
            FORCE_MODE=true
            confirm_action() { echo "Skipping confirmation (force mode)"; }
            ;;
        "")
            # Interactive mode
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    
    show_teardown_plan
    
    if [[ "${1:-}" != "--dry-run" ]]; then
        confirm_action "PROCEED WITH COMPLETE TEARDOWN"
        check_prerequisites
        execute_teardown
    fi
}

main "$@"
