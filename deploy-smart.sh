#!/bin/bash

# BETECH EKS Deployment Launcher
# Handles the current situation where infrastructure already exists

set -e

echo "🚀 BETECH EKS DEPLOYMENT LAUNCHER"
echo "=================================="
echo "Generated: $(date)"
echo ""

CLUSTER_NAME="betech-eks-cluster"
REGION="us-west-2"

# Check current status
echo "🔍 Checking current deployment status..."

# Check if cluster exists
if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION >/dev/null 2>&1; then
    echo "✅ EKS cluster exists"
    
    # Update kubeconfig
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    
    # Check if we can connect
    if kubectl get nodes >/dev/null 2>&1; then
        echo "✅ Cluster is accessible"
        
        # Check application status
        echo ""
        echo "📊 Current Application Status:"
        kubectl get pods -n default 2>/dev/null || echo "No application pods found"
        
        echo ""
        echo "🎯 Recommended Actions:"
        echo "  1. Deploy/Update Application: ./deploy-application-only.sh"
        echo "  2. Fix Issues: ./quick-fix.sh"
        echo "  3. Check Status: ./quick-fix.sh status"
        
        echo ""
        read -p "Would you like to deploy/update the application? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "🚀 Starting application deployment..."
            ./deploy-application-only.sh
        fi
        
    else
        echo "⚠️  Cluster exists but not accessible"
        echo "🔧 Running quick fix..."
        ./quick-fix.sh helm
    fi
    
else
    echo "❌ EKS cluster does not exist"
    echo ""
    echo "🎯 You need to deploy infrastructure first:"
    echo "  1. Go to eks-deployment directory: cd eks-deployment"
    echo "  2. Initialize Terraform: terraform init"
    echo "  3. Deploy infrastructure: terraform plan && terraform apply"
    echo "  4. Return here and run: ./deploy-application-only.sh"
    echo ""
    
    read -p "Would you like to deploy infrastructure now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🏗️  Starting infrastructure deployment..."
        cd eks-deployment
        
        if [ ! -d ".terraform" ]; then
            echo "🔧 Initializing Terraform..."
            terraform init
        fi
        
        echo "📋 Planning infrastructure..."
        terraform plan -out=tfplan
        
        echo "🚀 Applying infrastructure..."
        terraform apply tfplan
        
        echo "⏳ Waiting for cluster to be ready..."
        aws eks wait cluster-active --name $CLUSTER_NAME --region $REGION
        
        cd ..
        echo "✅ Infrastructure deployed!"
        echo "🚀 Now deploying application..."
        ./deploy-application-only.sh
    fi
fi
