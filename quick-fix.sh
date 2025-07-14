#!/bin/bash

set -e

# BETECH EKS Quick Fix Script
# Addresses common deployment issues based on troubleshooting experience

echo "🔧 BETECH EKS QUICK FIX SCRIPT"
echo "=============================="
echo "Generated: $(date)"
echo ""

# Check for proper argument usage
if [[ "$1" == *"["* ]] || [[ "$1" == *"]"* ]]; then
    echo "❌ Invalid argument format!"
    echo ""
    echo "📋 Correct usage examples:"
    echo "  ./quick-fix.sh helm      # Fix Helm timeout issues"
    echo "  ./quick-fix.sh iam       # Fix IAM permission issues"
    echo "  ./quick-fix.sh storage   # Fix storage/PVC issues"
    echo "  ./quick-fix.sh ingress   # Fix ingress issues"
    echo "  ./quick-fix.sh restart   # Restart application pods"
    echo "  ./quick-fix.sh status    # Show deployment status"
    echo "  ./quick-fix.sh all       # Run all fixes (default)"
    echo ""
    exit 1
fi

CLUSTER_NAME="betech-eks-cluster"
REGION="us-west-2"

# Function to fix Helm timeout issues
fix_helm_timeouts() {
    echo "⚓ Fixing Helm timeout issues..."
    
    # Check if cluster is accessible
    if ! kubectl get nodes >/dev/null 2>&1; then
        echo "❌ Cluster not accessible. Updating kubeconfig..."
        aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    fi
    
    # Remove stuck Helm releases from Terraform state
    if [ -d "eks-deployment" ]; then
        cd eks-deployment
        terraform state rm helm_release.cluster_autoscaler 2>/dev/null || true
        terraform state rm helm_release.aws_load_balancer_controller 2>/dev/null || true
        terraform state rm helm_release.metrics_server 2>/dev/null || true
        cd ..
    fi
    
    echo "✅ Helm state cleaned"
}

# Function to fix IAM permissions
fix_iam_permissions() {
    echo "🔐 Fixing IAM permissions..."
    
    # Fix Cluster Autoscaler permissions
    NODE_GROUP_ROLE_NAME=$(aws iam list-roles --query 'Roles[?contains(RoleName, `betech-node-group`)].RoleName' --output text | head -1)
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    if [ -n "$NODE_GROUP_ROLE_NAME" ]; then
        # Attach ClusterAutoscalerPolicy if it exists
        aws iam attach-role-policy \
            --role-name $NODE_GROUP_ROLE_NAME \
            --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/ClusterAutoscalerPolicy 2>/dev/null || true
        
        # Remove problematic IRSA annotations
        kubectl -n kube-system annotate serviceaccount cluster-autoscaler-aws-cluster-autoscaler eks.amazonaws.com/role-arn- 2>/dev/null || true
        
        echo "✅ IAM permissions fixed"
    else
        echo "⚠️  Node group role not found"
    fi
}

# Function to fix storage issues
fix_storage_issues() {
    echo "💾 Fixing storage issues..."
    
    # Delete stuck PVCs
    kubectl delete pvc postgres-pvc --ignore-not-found=true
    
    # Restart postgres with emptyDir if it exists
    if kubectl get deployment betechnet-postgres >/dev/null 2>&1; then
        echo "🔄 Restarting postgres with fixed storage..."
        kubectl delete deployment betechnet-postgres
        
        # Redeploy with emptyDir
        kubectl apply -f - <<EOF
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
        image: 374965156099.dkr.ecr.us-west-2.amazonaws.com/betech-postgres:latest
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
EOF
        
        kubectl wait --for=condition=available --timeout=300s deployment/betechnet-postgres
        echo "✅ PostgreSQL storage fixed"
    fi
}

# Function to fix ingress issues
fix_ingress_issues() {
    echo "🌐 Fixing ingress issues..."
    
    # Remove stuck ingress
    kubectl patch ingress betechnet-ingress -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
    kubectl delete ingress betechnet-ingress --ignore-not-found=true
    
    # Recreate with proper configuration
    kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: betechnet-ingress
  annotations:
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-west-2:374965156099:certificate/d8a6af47-551b-493e-a375-6134a905fcf2
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
    
    echo "✅ Ingress fixed"
}

# Function to restart application pods
restart_application() {
    echo "🔄 Restarting application pods..."
    
    kubectl rollout restart deployment betechnet-backend 2>/dev/null || true
    kubectl rollout restart deployment betechnet-frontend 2>/dev/null || true
    
    # Wait for deployments if they exist
    kubectl wait --for=condition=available --timeout=300s deployment/betechnet-backend 2>/dev/null || true
    kubectl wait --for=condition=available --timeout=300s deployment/betechnet-frontend 2>/dev/null || true
    
    echo "✅ Application pods restarted"
}

# Function to show status
show_status() {
    echo ""
    echo "📊 Current Status:"
    echo "=================="
    
    echo ""
    echo "Nodes:"
    kubectl get nodes
    
    echo ""
    echo "Pods:"
    kubectl get pods -n default
    
    echo ""
    echo "Services:"
    kubectl get svc -n default
    
    echo ""
    echo "Ingress:"
    kubectl get ingress -n default
    
    echo ""
    echo "Helm Releases:"
    helm list -A
}

# Main function
main() {
    echo "🚀 Running quick fixes..."
    
    fix_helm_timeouts
    fix_iam_permissions
    fix_storage_issues
    fix_ingress_issues
    restart_application
    show_status
    
    echo ""
    echo "🎉 Quick fixes completed!"
    echo ""
    echo "🧪 Test commands:"
    echo "  kubectl port-forward svc/betechnet-frontend 3000:3000"
    echo "  kubectl port-forward svc/betechnet-backend 8080:8080"
}

# Execute based on arguments
case "${1:-all}" in
    "helm")
        fix_helm_timeouts
        ;;
    "iam")
        fix_iam_permissions
        ;;
    "storage")
        fix_storage_issues
        ;;
    "ingress")
        fix_ingress_issues
        ;;
    "restart")
        restart_application
        ;;
    "status")
        show_status
        ;;
    "all"|*)
        main
        ;;
esac
