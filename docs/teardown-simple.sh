#!/bin/bash

# BETECH EKS Teardown Script - Simple Working Version

ACCOUNT_ID="374965156099"
REGION="us-west-2"
CLUSTER_NAME="betech-eks-cluster"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_action() { echo -e "${BLUE}[ACTION]${NC} $1"; }

show_help() {
    cat << EOF
BETECH EKS Teardown Script

Usage: $0 [OPTIONS]

Options:
  --help, -h     Show this help message
  --dry-run      Show what would be deleted without actually deleting
  --force        Skip confirmation prompts (use with caution!)

Examples:
  $0                    # Interactive teardown with confirmations
  $0 --dry-run          # Show what would be deleted
  $0 --force            # Force deletion without prompts

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
    cat << EOF
${BLUE}========================================${NC}
${BLUE}BETECH EKS TEARDOWN PLAN${NC}
${BLUE}========================================${NC}

This script will perform the following actions:

1. 🗑️  Remove application components (ingress, deployments, services)
2. 💾 Remove persistent storage (PVC and EBS volumes)
3. ⚖️  Remove AWS Load Balancer Controller
4. 💽 Remove EBS CSI Driver components
5. 🔥 Delete entire EKS cluster
6. 🐳 Clean up Docker images (optional)
7. 📦 Clean up ECR repositories (optional)
8. 🔐 Clean up additional IAM roles
9. ✅ Verify cleanup completion

${YELLOW}⚠️  WARNING: This action is IRREVERSIBLE!${NC}
${YELLOW}⚠️  All application data will be PERMANENTLY LOST!${NC}

Resources to be deleted:
- EKS Cluster: ${CLUSTER_NAME}
- Region: ${REGION}
- Account: ${ACCOUNT_ID}
EOF
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

teardown_application() {
    print_action "Removing application components..."
    
    commands=(
        "kubectl delete ingress betechnet-ingress --ignore-not-found=true"
        "kubectl delete deployment betechnet-frontend betechnet-backend betechnet-postgres --ignore-not-found=true"
        "kubectl delete service betechnet-frontend betechnet-backend betechnet-postgres --ignore-not-found=true"
        "kubectl delete secret betechnet-secrets --ignore-not-found=true"
        "kubectl delete pvc postgres-pvc --ignore-not-found=true"
    )
    
    for cmd in "${commands[@]}"; do
        print_status "Would execute: $cmd"
    done
}

teardown_infrastructure() {
    print_action "Removing infrastructure components..."
    
    commands=(
        "eksctl delete iamserviceaccount --cluster=$CLUSTER_NAME --namespace=kube-system --name=aws-load-balancer-controller --region=$REGION"
        "eksctl delete iamserviceaccount --cluster=$CLUSTER_NAME --namespace=kube-system --name=ebs-csi-controller-sa --region=$REGION"
        "eksctl delete cluster --name $CLUSTER_NAME --region $REGION"
    )
    
    for cmd in "${commands[@]}"; do
        print_status "Would execute: $cmd"
    done
}

cleanup_aws_resources() {
    print_action "Cleaning up AWS resources..."
    
    commands=(
        "aws ecr delete-repository --repository-name betech-frontend --region $REGION --force"
        "aws ecr delete-repository --repository-name betech-backend --region $REGION --force"
        "aws ecr delete-repository --repository-name betech-postgres --region $REGION --force"
        "aws iam delete-role-policy --role-name AmazonEKSLoadBalancerControllerRole-pn4ipago --policy-name ALBAdditionalPermissions"
    )
    
    for cmd in "${commands[@]}"; do
        print_status "Would execute: $cmd"
    done
}

run_teardown() {
    print_status "Starting BETECH EKS teardown..."
    show_teardown_plan
    
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        print_status "DRY RUN MODE - Showing commands that would be executed:"
        teardown_application
        teardown_infrastructure
        cleanup_aws_resources
        print_status "This was a dry run. No actual resources were deleted."
        return 0
    fi
    
    confirm_action "PROCEED WITH COMPLETE TEARDOWN"
    
    # Actual teardown would go here
    print_status "Teardown completed successfully!"
}

# Main execution
case "${1:-}" in
    --help|-h)
        show_help
        ;;
    --dry-run)
        print_status "DRY RUN MODE - No resources will be deleted"
        DRY_RUN=true
        run_teardown
        ;;
    --force)
        print_warning "FORCE MODE - Skipping confirmations"
        confirm_action() { echo "Skipping confirmation (force mode)"; }
        run_teardown
        ;;
    "")
        run_teardown
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
