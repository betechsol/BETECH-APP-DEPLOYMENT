#!/bin/bash

# Clean up and deploy BETECH application manifests
set -e

echo "🧹 Cleaning up existing application resources..."

# Delete any existing application resources (not infrastructure)
kubectl delete deployment betechnet-backend betechnet-frontend betechnet-postgres 2>/dev/null || echo "  └── Application deployments not found"
kubectl delete service betechnet-backend betechnet-frontend betechnet-postgres 2>/dev/null || echo "  └── Application services not found"
kubectl delete ingress betechnet-ingress 2>/dev/null || echo "  └── Ingress not found"
kubectl delete pvc postgres-pvc 2>/dev/null || echo "  └── PVC not found"
kubectl delete secret rds-postgres-secret 2>/dev/null || echo "  └── Secret not found"
kubectl delete configmap postgres-initdb 2>/dev/null || echo "  └── ConfigMap not found"
kubectl delete serviceaccount betechnet-backend 2>/dev/null || echo "  └── Service account not found"
kubectl delete role backend-role 2>/dev/null || echo "  └── Role not found"
kubectl delete rolebinding backend-rolebinding 2>/dev/null || echo "  └── Role binding not found"

echo ""
echo "✅ Cleanup completed!"
echo ""
echo "🚀 Deploying BETECH application..."

# Apply the fixed manifests (excluding infrastructure components)
kubectl apply -f /home/ubuntu/BETECH-APP-DEPLOYMENT/manifests-fixed/

echo ""
echo "⏳ Waiting for deployments to be ready..."

# Wait for deployments to be ready
kubectl wait --for=condition=Available deployment/betechnet-backend --timeout=300s || echo "⚠️  Backend deployment timeout"
kubectl wait --for=condition=Available deployment/betechnet-frontend --timeout=300s || echo "⚠️  Frontend deployment timeout"
kubectl wait --for=condition=Available deployment/betechnet-postgres --timeout=300s || echo "⚠️  Postgres deployment timeout"

echo ""
echo "🔍 Checking deployment status..."
kubectl get deployments
echo ""
kubectl get services
echo ""
kubectl get ingress

echo ""
echo "🎯 Getting Load Balancer URL..."
ALB_URL=$(kubectl get ingress betechnet-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Not ready yet")
if [ "$ALB_URL" != "Not ready yet" ]; then
    echo "🌐 Application URL: https://$ALB_URL"
else
    echo "⏳ Load balancer is being provisioned. Check again in a few minutes with:"
    echo "   kubectl get ingress betechnet-ingress"
fi

echo ""
echo "✅ BETECH application deployment completed!"
