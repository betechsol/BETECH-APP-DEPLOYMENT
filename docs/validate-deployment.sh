#!/bin/bash

# BETECH EKS Validation Script
# This script validates the EKS deployment for account ID: 374965156099

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

# Check cluster status
check_cluster_status() {
    print_status "Checking cluster status..."
    
    if kubectl cluster-info &> /dev/null; then
        print_status "✓ Cluster is accessible"
        kubectl get nodes
    else
        print_error "✗ Cannot access cluster"
        exit 1
    fi
}

# Check pod status
check_pod_status() {
    print_status "Checking pod status..."
    
    kubectl get pods -o wide
    
    # Check if all pods are running
    FAILED_PODS=$(kubectl get pods --field-selector=status.phase!=Running --no-headers | wc -l)
    if [ "$FAILED_PODS" -eq 0 ]; then
        print_status "✓ All pods are running"
    else
        print_warning "⚠ Some pods are not running"
        kubectl get pods --field-selector=status.phase!=Running
    fi
}

# Check service status
check_service_status() {
    print_status "Checking service status..."
    
    kubectl get services
    
    # Check if services have endpoints
    for service in betechnet-frontend betechnet-backend betechnet-postgres; do
        ENDPOINTS=$(kubectl get endpoints $service -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || echo "none")
        if [ "$ENDPOINTS" != "none" ]; then
            print_status "✓ Service $service has endpoints"
        else
            print_warning "⚠ Service $service has no endpoints"
        fi
    done
}

# Check ingress status
check_ingress_status() {
    print_status "Checking ingress status..."
    
    kubectl get ingress betechnet-ingress
    
    ALB_URL=$(kubectl get ingress betechnet-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "none")
    if [ "$ALB_URL" != "none" ]; then
        print_status "✓ ALB URL: $ALB_URL"
        
        # Test connectivity
        if curl -s -o /dev/null -w "%{http_code}" "http://$ALB_URL" | grep -q "200\|302\|404"; then
            print_status "✓ ALB is responding"
        else
            print_warning "⚠ ALB is not responding yet (may still be provisioning)"
        fi
    else
        print_warning "⚠ ALB URL not available yet"
    fi
}

# Check PVC status
check_pvc_status() {
    print_status "Checking PVC status..."
    
    kubectl get pvc
    
    PVC_STATUS=$(kubectl get pvc postgres-pvc -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    if [ "$PVC_STATUS" = "Bound" ]; then
        print_status "✓ PVC is bound"
    else
        print_warning "⚠ PVC status: $PVC_STATUS"
    fi
}

# Check ALB controller
check_alb_controller() {
    print_status "Checking AWS Load Balancer Controller..."
    
    ALB_CONTROLLER_STATUS=$(kubectl get deployment aws-load-balancer-controller -n kube-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$ALB_CONTROLLER_STATUS" -gt 0 ]; then
        print_status "✓ AWS Load Balancer Controller is running"
    else
        print_warning "⚠ AWS Load Balancer Controller is not running"
        kubectl get pods -n kube-system | grep aws-load-balancer-controller
    fi
}

# Test database connectivity
test_database_connectivity() {
    print_status "Testing database connectivity..."
    
    # Get postgres pod name
    POSTGRES_POD=$(kubectl get pods -l app=betechnet-postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "none")
    
    if [ "$POSTGRES_POD" != "none" ]; then
        # Test database connection
        if kubectl exec $POSTGRES_POD -- psql -U admin -d betech_db -c "SELECT 1;" &> /dev/null; then
            print_status "✓ Database is accessible"
        else
            print_warning "⚠ Database connection failed"
        fi
    else
        print_warning "⚠ PostgreSQL pod not found"
    fi
}

# Test backend API
test_backend_api() {
    print_status "Testing backend API..."
    
    # Skip if cluster is not accessible
    if ! kubectl cluster-info &> /dev/null; then
        print_warning "⚠ Cluster not accessible, skipping backend API test"
        return
    fi
    
    # Check if backend service exists
    if ! kubectl get service betechnet-backend &> /dev/null; then
        print_warning "⚠ Backend service not found, skipping API test"
        return
    fi
    
    # Port forward to backend service
    kubectl port-forward service/betechnet-backend 8080:8080 &
    PF_PID=$!
    sleep 5
    
    # Test API endpoint
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/api/health" | grep -q "200\|404"; then
        print_status "✓ Backend API is responding"
    else
        print_warning "⚠ Backend API is not responding"
    fi
    
    # Kill port-forward
    kill $PF_PID 2>/dev/null || true
}

# Generate deployment report
generate_report() {
    print_status "Generating deployment report..."
    
    REPORT_FILE="deployment-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > $REPORT_FILE << EOF
BETECH EKS Deployment Report
Generated: $(date)
Account ID: 374965156099
Region: us-west-2
Cluster: betech-eks-cluster

=== CLUSTER STATUS ===
$(kubectl get nodes)

=== POD STATUS ===
$(kubectl get pods -o wide)

=== SERVICE STATUS ===
$(kubectl get services)

=== INGRESS STATUS ===
$(kubectl get ingress)

=== PVC STATUS ===
$(kubectl get pvc)

=== ALB CONTROLLER STATUS ===
$(kubectl get deployment aws-load-balancer-controller -n kube-system)

=== RECENT EVENTS ===
$(kubectl get events --sort-by=.metadata.creationTimestamp | tail -20)

EOF
    
    print_status "Report saved to: $REPORT_FILE"
}

# Main validation function
main() {
    print_status "Starting BETECH EKS validation..."
    
    check_cluster_status
    check_pod_status
    check_service_status
    check_ingress_status
    check_pvc_status
    check_alb_controller
    test_database_connectivity
    test_backend_api
    generate_report
    
    print_status "Validation completed!"
    print_status "Check the generated report for detailed information"
}

# Run main function
main "$@"
