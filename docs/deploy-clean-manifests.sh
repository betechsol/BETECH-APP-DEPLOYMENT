#!/bin/bash

echo "🚀 Deploying BETECH Application (Clean Version)"
echo "=============================================="

# Files to exclude from deployment (problematic ones)
EXCLUDE_FILES=(
    "aws-load-balancer-controller.yaml"  # Already deployed via Helm
    "eks-cluster-config.yaml"            # Not a Kubernetes resource
    "postgres-deployment.yaml"           # Use our fixed version with emptyDir
)

# Create a temporary directory for clean manifests
mkdir -p manifests-clean
cd manifests

echo "📋 Preparing clean manifests..."

# Copy all files except excluded ones
for file in *.yaml; do
    skip=false
    for exclude in "${EXCLUDE_FILES[@]}"; do
        if [[ "$file" == "$exclude" ]]; then
            echo "⏭️  Skipping: $file (excluded)"
            skip=true
            break
        fi
    done
    
    if [[ "$skip" == false ]]; then
        echo "✅ Including: $file"
        cp "$file" "../manifests-clean/"
    fi
done

cd ../manifests-clean

echo ""
echo "🔍 Applying clean manifests..."
for file in *.yaml; do
    echo "📄 Applying: $file"
    if kubectl apply -f "$file"; then
        echo "✅ Success: $file"
    else
        echo "❌ Failed: $file"
    fi
    echo ""
done

cd ..

echo "📊 Checking deployment status..."
kubectl get pods -n default
echo ""

echo "🌐 Checking services..."
kubectl get svc -n default
echo ""

echo "🔗 Checking ingress..."
kubectl get ingress -n default
echo ""

echo "🎉 Clean deployment completed!"
echo ""
echo "🧪 To test the application:"
echo "   Frontend: kubectl port-forward svc/betechnet-frontend 3000:3000"
echo "   Backend:  kubectl port-forward svc/betechnet-backend 8080:8080"
