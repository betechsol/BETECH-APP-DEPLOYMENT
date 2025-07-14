#!/bin/bash

# BETECH EKS Terraform Validation Script
# Account ID: 374965156099
# Region: us-west-2

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate EKS cluster
validate_cluster() {
    print_status "Validating EKS cluster..."
    
    # Check cluster status
    if kubectl cluster-info &> /dev/null; then
        print_status "✓ EKS cluster is accessible"
    else
        print_error "✗ EKS cluster is not accessible"
        return 1
    fi
    
    # Check nodes
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    if [ "$NODE_COUNT" -gt 0 ]; then
        print_status "✓ $NODE_COUNT nodes are ready"
        kubectl get nodes
    else
        print_error "✗ No nodes found"
        return 1
    fi
}

# Validate deployments
validate_deployments() {
    print_status "Validating deployments..."
    
    # Check PostgreSQL
    if kubectl get deployment betechnet-postgres &> /dev/null; then
        if kubectl rollout status deployment/betechnet-postgres --timeout=60s &> /dev/null; then
            print_status "✓ PostgreSQL deployment is ready"
        else
            print_warning "⚠ PostgreSQL deployment is not ready"
        fi
    else
        print_warning "⚠ PostgreSQL deployment not found"
    fi
    
    # Check Backend
    if kubectl get deployment betechnet-backend &> /dev/null; then
        if kubectl rollout status deployment/betechnet-backend --timeout=60s &> /dev/null; then
            print_status "✓ Backend deployment is ready"
        else
            print_warning "⚠ Backend deployment is not ready"
        fi
    else
        print_warning "⚠ Backend deployment not found"
    fi
    
    # Check Frontend
    if kubectl get deployment betechnet-frontend &> /dev/null; then
        if kubectl rollout status deployment/betechnet-frontend --timeout=60s &> /dev/null; then
            print_status "✓ Frontend deployment is ready"
        else
            print_warning "⚠ Frontend deployment is not ready"
        fi
    else
        print_warning "⚠ Frontend deployment not found"
    fi
}

# Validate services
validate_services() {
    print_status "Validating services..."
    
    # List all services
    kubectl get services
    
    # Check if services have endpoints
    for service in betechnet-postgres betechnet-backend betechnet-frontend; do
        if kubectl get service $service &> /dev/null; then
            ENDPOINTS=$(kubectl get endpoints $service -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
            if [ -n "$ENDPOINTS" ]; then
                print_status "✓ Service $service has endpoints"
            else
                print_warning "⚠ Service $service has no endpoints"
            fi
        else
            print_warning "⚠ Service $service not found"
        fi
    done
}

# Validate ingress
validate_ingress() {
    print_status "Validating ingress..."
    
    if kubectl get ingress betechnet-ingress &> /dev/null; then
        ALB_HOST=$(kubectl get ingress betechnet-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$ALB_HOST" ]; then
            print_status "✓ Ingress has ALB endpoint: $ALB_HOST"
            
            # Test ALB connectivity
            print_status "Testing ALB connectivity..."
            if curl -s -o /dev/null -w "%{http_code}" "http://$ALB_HOST" | grep -q "200\|404\|503"; then
                print_status "✓ ALB is responding"
            else
                print_warning "⚠ ALB is not responding (this might be normal if services are starting)"
            fi
        else
            print_warning "⚠ Ingress ALB is still being created"
        fi
    else
        print_warning "⚠ Ingress not found"
    fi
}

# Validate AWS Load Balancer Controller
validate_alb_controller() {
    print_status "Validating AWS Load Balancer Controller..."
    
    if kubectl get deployment aws-load-balancer-controller -n kube-system &> /dev/null; then
        if kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=60s &> /dev/null; then
            print_status "✓ AWS Load Balancer Controller is ready"
        else
            print_warning "⚠ AWS Load Balancer Controller is not ready"
        fi
    else
        print_error "✗ AWS Load Balancer Controller not found"
        return 1
    fi
}

# Validate storage
validate_storage() {
    print_status "Validating storage..."
    
    # Check PVCs
    if kubectl get pvc postgres-pvc &> /dev/null; then
        PVC_STATUS=$(kubectl get pvc postgres-pvc -o jsonpath='{.status.phase}')
        if [ "$PVC_STATUS" == "Bound" ]; then
            print_status "✓ PostgreSQL PVC is bound"
        else
            print_warning "⚠ PostgreSQL PVC status: $PVC_STATUS"
        fi
    else
        print_warning "⚠ PostgreSQL PVC not found"
    fi
    
    # Check storage class
    if kubectl get storageclass ebs-sc &> /dev/null; then
        print_status "✓ EBS storage class exists"
    else
        print_warning "⚠ EBS storage class not found"
    fi
}

# Validate ECR repositories
validate_ecr() {
    print_status "Validating ECR repositories..."
    
    for repo in betech-frontend betech-backend betech-postgres; do
        if aws ecr describe-repositories --repository-names $repo --region us-west-2 &> /dev/null; then
            print_status "✓ ECR repository $repo exists"
        else
            print_warning "⚠ ECR repository $repo not found"
        fi
    done
}

# Generate deployment report
generate_report() {
    print_status "Generating deployment report..."
    
    echo "==============================================="
    echo "BETECH EKS Deployment Validation Report"
    echo "==============================================="
    echo "Date: $(date)"
    echo "Cluster: betech-eks-cluster"
    echo "Region: us-west-2"
    echo "Account: 374965156099"
    echo "==============================================="
    
    echo -e "\n--- Cluster Information ---"
    kubectl cluster-info
    
    echo -e "\n--- Node Information ---"
    kubectl get nodes -o wide
    
    echo -e "\n--- Namespace Information ---"
    kubectl get namespaces
    
    echo -e "\n--- Deployment Status ---"
    kubectl get deployments
    
    echo -e "\n--- Service Status ---"
    kubectl get services
    
    echo -e "\n--- Ingress Status ---"
    kubectl get ingress
    
    echo -e "\n--- Pod Status ---"
    kubectl get pods -o wide
    
    echo -e "\n--- Persistent Volume Claims ---"
    kubectl get pvc
    
    echo -e "\n--- Storage Classes ---"
    kubectl get storageclass
    
    echo -e "\n--- Events (Recent) ---"
    kubectl get events --sort-by=.metadata.creationTimestamp | tail -20
    
    echo "==============================================="
    echo "Report generated successfully!"
    echo "==============================================="
}

# Main validation function
main() {
    print_status "Starting BETECH EKS deployment validation..."
    
    validate_cluster
    validate_alb_controller
    validate_deployments
    validate_services
    validate_ingress
    validate_storage
    validate_ecr
    generate_report
    
    print_status "Validation completed!"
}

# Run validation
main