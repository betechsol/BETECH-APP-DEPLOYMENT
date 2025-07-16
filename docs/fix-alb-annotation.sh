#!/bin/bash

# Quick fix for AWS Load Balancer Controller service account annotation
# This script ensures the correct IAM role annotation is applied and persists

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "\033[0;31m❌ $1\033[0m"
}

# Hardcoded IAM role ARN for BETECH cluster
HARDCODED_ROLE_ARN="arn:aws:iam::374965156099:role/AmazonEKSLoadBalancerControllerRole-pn4ipago"

log "🔧 ALB Controller Service Account Annotation Fix"
echo "==============================================="

# Function to get expected role ARN (with hardcoded fallback)
get_expected_role_arn() {
    local terraform_arn=$(terraform -chdir=eks-deployment output -raw load_balancer_controller_role_arn 2>/dev/null || echo "")
    
    if [[ -n "$terraform_arn" ]]; then
        log "Using role ARN from Terraform: $terraform_arn"
        echo "$terraform_arn"
    else
        warning "Using hardcoded role ARN: $HARDCODED_ROLE_ARN"
        echo "$HARDCODED_ROLE_ARN"
    fi
}

# Function to check current annotation
check_current_annotation() {
    local current=$(kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || echo "")
    echo "$current"
}

# Function to apply annotation
apply_annotation() {
    local role_arn="$1"
    kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
        eks.amazonaws.com/role-arn="$role_arn" --overwrite
}

# Function to restart controller
restart_controller() {
    log "Restarting AWS Load Balancer Controller..."
    kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
    kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s
}

# Main execution
main() {
    # Get expected role ARN
    EXPECTED_ROLE_ARN=$(get_expected_role_arn)
    
    # Check current annotation
    CURRENT_ANNOTATION=$(check_current_annotation)
    
    log "Expected: $EXPECTED_ROLE_ARN"
    log "Current:  $CURRENT_ANNOTATION"
    
    if [[ "$CURRENT_ANNOTATION" == "$EXPECTED_ROLE_ARN" ]]; then
        success "Service account annotation is already correct"
        
        # Check if controller pods are running
        RUNNING_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers | grep "Running" | wc -l)
        success "ALB Controller pods running: $RUNNING_PODS"
        
        return 0
    fi
    
    # Apply the correct annotation
    log "Applying correct IAM role annotation..."
    if apply_annotation "$EXPECTED_ROLE_ARN"; then
        success "Applied annotation: $EXPECTED_ROLE_ARN"
    else
        error "Failed to apply annotation"
        exit 1
    fi
    
    # Verify annotation was applied
    VERIFIED_ANNOTATION=$(check_current_annotation)
    if [[ "$VERIFIED_ANNOTATION" == "$EXPECTED_ROLE_ARN" ]]; then
        success "Annotation verified: $VERIFIED_ANNOTATION"
    else
        warning "Annotation verification failed. Current: $VERIFIED_ANNOTATION"
    fi
    
    # Restart controller to pick up the new annotation
    if restart_controller; then
        success "Controller restarted successfully"
    else
        warning "Controller restart had issues"
    fi
    
    # Final verification after restart
    sleep 5
    FINAL_ANNOTATION=$(check_current_annotation)
    
    if [[ "$FINAL_ANNOTATION" == "$EXPECTED_ROLE_ARN" ]]; then
        success "Final verification: Annotation persisted after restart"
        success "🎉 ALB Controller service account annotation fixed!"
    else
        warning "Final verification: Annotation changed after restart"
        log "Final: $FINAL_ANNOTATION"
        log "Expected: $EXPECTED_ROLE_ARN"
        
        # Re-apply if it changed
        log "Re-applying annotation..."
        apply_annotation "$EXPECTED_ROLE_ARN"
        success "Re-applied annotation as failsafe"
    fi
    
    # Show current status
    echo ""
    log "Current ALB Controller status:"
    kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
    echo ""
    kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o yaml | grep -A 2 -B 2 "eks.amazonaws.com/role-arn"
}

# Run main function
main "$@"
