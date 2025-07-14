#!/bin/bash

echo "=== FIXING IAM PERMISSIONS FOR EKS ADD-ONS ==="

# Note: The cluster name may need to be adjusted based on your eksctl cluster name
CLUSTER_NAME="betech-cluster"  # Update this if different

echo "Fixing ALB Controller IAM permissions..."
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
  --override-existing-serviceaccounts \
  --approve

echo "Fixing EBS CSI Controller IAM permissions..."
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=ebs-csi-controller-sa \
  --attach-policy-arn=arn:aws:iam::aws:policy/service-role/Amazon_EBS_CSI_DriverPolicy \
  --override-existing-serviceaccounts \
  --approve

echo "Restarting ALB Controller to pick up new permissions..."
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system

echo "Restarting EBS CSI Controller to pick up new permissions..."
kubectl rollout restart deployment ebs-csi-controller -n kube-system

echo "Waiting for controllers to restart..."
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system
kubectl wait --for=condition=available --timeout=300s deployment/ebs-csi-controller -n kube-system

echo "Checking ingress status after ALB controller restart..."
sleep 30
kubectl get ingress

echo "=== IAM FIX COMPLETED ==="
echo "Note: It may take 5-10 minutes for the ALB to be provisioned and assigned an address."
echo "Monitor progress with: kubectl describe ingress betechnet-ingress"
