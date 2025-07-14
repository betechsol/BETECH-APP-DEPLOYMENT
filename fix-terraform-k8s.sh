#!/bin/bash

# Fix Terraform Kubernetes Configuration Issues
# This script resolves the kubeconfig and Helm connectivity problems

set -e

CLUSTER_NAME="betech-eks-cluster"
REGION="us-west-2"

echo "🔧 Fixing Terraform Kubernetes configuration..."

# Step 1: Check if cluster exists
echo "📋 Checking if EKS cluster exists..."
if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION >/dev/null 2>&1; then
    echo "✅ EKS cluster exists"
    
    # Step 2: Update kubeconfig
    echo "🔑 Updating kubeconfig..."
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    
    # Step 3: Test connectivity
    echo "🧪 Testing cluster connectivity..."
    if kubectl get nodes >/dev/null 2>&1; then
        echo "✅ Kubernetes cluster is reachable"
        
        # Step 4: Apply only infrastructure first (without Helm)
        echo "🏗️  Applying infrastructure without Helm charts..."
        cd /home/ubuntu/BETECH-APP-DEPLOYMENT/eks-deployment
        
        # Apply everything except Helm releases
        terraform apply \
            -target=module.vpc \
            -target=module.eks \
            -target=aws_ecr_repository.betech_frontend \
            -target=aws_ecr_repository.betech_backend \
            -target=aws_ecr_repository.betech_postgres \
            -target=aws_iam_policy.aws_load_balancer_controller_policy \
            -target=aws_iam_role.aws_load_balancer_controller_role \
            -target=aws_iam_policy.cluster_autoscaler_policy \
            -target=aws_iam_role.cluster_autoscaler_role \
            -target=aws_iam_role.ebs_csi_driver_role \
            -auto-approve
        
        # Step 5: Now apply Helm charts
        echo "⚓ Applying Helm charts..."
        terraform apply -auto-approve
        
        echo "🎉 Terraform Kubernetes configuration fixed!"
        
    else
        echo "❌ Cannot connect to Kubernetes cluster"
        echo "💡 Try running: aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME"
        exit 1
    fi
    
else
    echo "❌ EKS cluster does not exist"
    echo "🔨 Creating cluster first..."
    
    # Apply infrastructure to create cluster
    cd /home/ubuntu/BETECH-APP-DEPLOYMENT/eks-deployment
    terraform apply \
        -target=module.vpc \
        -target=module.eks \
        -auto-approve
    
    # Wait for cluster to be ready
    echo "⏳ Waiting for cluster to be ready..."
    sleep 60
    
    # Update kubeconfig
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    
    # Apply remaining resources
    echo "🚀 Applying remaining resources..."
    terraform apply -auto-approve
    
    echo "🎉 EKS cluster created and configured!"
fi

echo ""
echo "📊 Cluster Status:"
kubectl get nodes
echo ""
echo "🔍 Available namespaces:"
kubectl get namespaces
