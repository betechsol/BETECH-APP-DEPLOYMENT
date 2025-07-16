#!/bin/bash

# BETECH EKS Deployment Status Verification Script
echo "=================================================="
echo "🔍 BETECH EKS DEPLOYMENT STATUS VERIFICATION"
echo "=================================================="
echo "Generated: $(date)"
echo ""

CLUSTER_NAME="betech-eks-cluster"
REGION="us-west-2"

# Check cluster status
echo "📊 EKS Cluster Status:"
aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text
echo ""

# Check nodes
echo "🖥️  Worker Nodes:"
kubectl get nodes -o wide
echo ""

# Check system pods
echo "🔧 System Pods (kube-system):"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl get pods -n kube-system -l app=metrics-server
kubectl get pods -n kube-system -l app.kubernetes.io/name=cluster-autoscaler
echo ""

# Check application pods
echo "🚀 Application Pods:"
kubectl get pods -o wide
echo ""

# Check services
echo "🌐 Services:"
kubectl get svc
echo ""

# Check ingress
echo "🔗 Ingress:"
kubectl get ingress
echo ""

# Check ingress details
if kubectl get ingress betechnet-ingress >/dev/null 2>&1; then
    echo "📋 Ingress Details:"
    ALB_ADDRESS=$(kubectl get ingress betechnet-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    echo "ALB Address: $ALB_ADDRESS"
    
    if [ -n "$ALB_ADDRESS" ]; then
        echo ""
        echo "🧪 Testing ALB Connectivity:"
        echo "Frontend (HTTP redirect):"
        curl -I http://$ALB_ADDRESS --connect-timeout 5 -H "Host: betech-app.betechsol.com" 2>/dev/null | head -2
        
        echo "Frontend (HTTPS):"
        curl -I https://$ALB_ADDRESS --connect-timeout 5 -k -H "Host: betech-app.betechsol.com" 2>/dev/null | head -2
        
        echo "Backend API:"
        curl -I https://$ALB_ADDRESS/api/login --connect-timeout 5 -k -H "Host: betech-app.betechsol.com" 2>/dev/null | head -2
    fi
fi

echo ""

# Check ALB controller logs for errors
echo "📝 Recent ALB Controller Events:"
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=5 --since=5m 2>/dev/null | grep -E "(error|Error|ERROR|warn|Warn|WARN)" || echo "No recent errors found"

echo ""

# Summary
echo "📋 Deployment Summary:"
CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text)
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep Ready | wc -l)
APP_PODS=$(kubectl get pods --no-headers 2>/dev/null | grep -v Terminating | wc -l)
RUNNING_PODS=$(kubectl get pods --no-headers 2>/dev/null | grep Running | wc -l)
ALB_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | grep Running | wc -l)

echo "  ✅ Cluster Status: $CLUSTER_STATUS"
echo "  ✅ Worker Nodes: $READY_NODES/$NODE_COUNT ready"
echo "  ✅ Application Pods: $RUNNING_PODS/$APP_PODS running"
echo "  ✅ ALB Controller Pods: $ALB_PODS/2 running"

if kubectl get ingress betechnet-ingress >/dev/null 2>&1; then
    ALB_ADDRESS=$(kubectl get ingress betechnet-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -n "$ALB_ADDRESS" ]; then
        echo "  ✅ ALB: Provisioned and accessible"
    else
        echo "  ⏳ ALB: Provisioning in progress"
    fi
else
    echo "  ❌ ALB: Ingress not found"
fi

echo ""
echo "🎉 Verification completed!"

# Provide next steps
echo ""
echo "🔗 Access URLs:"
if [ -n "$ALB_ADDRESS" ]; then
    echo "  Frontend: https://$ALB_ADDRESS (with Host: betech-app.betechsol.com header)"
    echo "  Backend API: https://$ALB_ADDRESS/api/* (with Host: betech-app.betechsol.com header)"
    echo ""
    echo "📝 DNS Update Required:"
    echo "  Point betech-app.betechsol.com to: $ALB_ADDRESS"
else
    echo "  Waiting for ALB to be provisioned..."
    echo "  Run this script again in a few minutes."
fi

echo ""
echo "=================================================="
