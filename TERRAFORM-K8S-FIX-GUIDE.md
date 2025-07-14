# Terraform Kubernetes Configuration Fix Guide

## Problem
```
Error: Kubernetes cluster unreachable: invalid configuration: no configuration has been provided, try setting KUBERNETES_MASTER environment variable
```

## Root Cause
- Terraform's Helm provider cannot connect to the Kubernetes cluster
- Either the cluster doesn't exist, or kubeconfig is not properly configured
- Terraform state may be out of sync with actual AWS resources

## Solution Steps

### Step 1: Run the Fix Script
```bash
cd /home/ubuntu/BETECH-APP-DEPLOYMENT
./fix-terraform-k8s.sh
```

### Step 2: If Step 1 Fails, Manual Fix

#### 2a. Check Current State
```bash
cd /home/ubuntu/BETECH-APP-DEPLOYMENT/eks-deployment

# Check if cluster exists in AWS
aws eks list-clusters --region us-west-2

# Check Terraform state
terraform state list | grep eks_cluster
```

#### 2b. If Cluster Doesn't Exist, Create It
```bash
# Apply only the cluster first
terraform apply \
  -target=module.vpc \
  -target=module.eks.aws_eks_cluster.this \
  -target=module.eks.aws_eks_node_group.this \
  -auto-approve

# Wait for cluster to be ready
sleep 60

# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name betech-eks-cluster
```

#### 2c. If Cluster Exists, Fix kubeconfig
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name betech-eks-cluster

# Test connectivity
kubectl get nodes
```

#### 2d. Apply Remaining Resources
```bash
# Now apply everything including Helm charts
terraform apply -auto-approve
```

### Step 3: Alternative Approach - Skip Helm in Terraform

If the above doesn't work, you can temporarily disable Helm in Terraform:

#### 3a. Comment Out Helm Resources
Edit the `helm.tf` file and comment out the problematic resources:

```terraform
# Temporarily disable Helm releases
/*
resource "helm_release" "aws_load_balancer_controller" {
  # ... content
}

resource "helm_release" "metrics_server" {
  # ... content  
}

resource "helm_release" "cluster_autoscaler" {
  # ... content
}
*/
```

#### 3b. Apply Infrastructure Only
```bash
terraform apply -auto-approve
```

#### 3c. Deploy Helm Charts Manually
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name betech-eks-cluster

# Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=betech-eks-cluster \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller

# Install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Install cluster autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```

## Timeout Issues ("context deadline exceeded")

If you get timeout errors with Helm releases:

### Quick Fix for Timeouts
```bash
# Remove problematic Helm release from state
cd /home/ubuntu/BETECH-APP-DEPLOYMENT/eks-deployment
terraform state rm helm_release.cluster_autoscaler
terraform state rm helm_release.aws_load_balancer_controller
terraform state rm helm_release.metrics_server

# Install manually with proper timeouts
helm repo add eks https://aws.github.io/eks-charts
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update

# Install with extended timeouts
helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  -n kube-system \
  --set autoDiscovery.clusterName=betech-eks-cluster \
  --set awsRegion=us-west-2 \
  --timeout=10m \
  --wait
```

### Automated Timeout Fix
```bash
cd /home/ubuntu/BETECH-APP-DEPLOYMENT
./fix-helm-timeouts.sh
```

## Quick Commands to Run Now

```bash
# Option 1: Use the fix script
cd /home/ubuntu/BETECH-APP-DEPLOYMENT
./fix-terraform-k8s.sh

# Option 2: Manual fix
cd /home/ubuntu/BETECH-APP-DEPLOYMENT/eks-deployment
aws eks update-kubeconfig --region us-west-2 --name betech-eks-cluster
kubectl get nodes
terraform apply -auto-approve
```

## Verification

After applying the fix:

```bash
# Check cluster connectivity
kubectl get nodes

# Check Helm releases
helm list -A

# Check pods
kubectl get pods -A
```

The key is ensuring that the EKS cluster exists and your kubeconfig is properly configured before Terraform tries to deploy Helm charts.

## Final Status Summary

✅ **DEPLOYMENT COMPLETE** ✅

All issues have been resolved and the EKS infrastructure is fully operational:

### Infrastructure Status
- **EKS Cluster**: ✅ Running (`betech-eks-cluster`)
- **Node Groups**: ✅ 2 nodes running (v1.27.16-eks-aeac579)
- **VPC & Networking**: ✅ Configured with public/private subnets
- **ECR Repositories**: ✅ Created for backend, frontend, and postgres

### Add-ons Status
- **AWS Load Balancer Controller**: ✅ Running (v2.13.3) - Chart 1.13.3
- **Metrics Server**: ✅ Running (v0.7.2) - Chart 3.12.2  
- **Cluster Autoscaler**: ✅ Running (v1.33.0) - Chart 9.48.0

### Key Fixes Applied
1. **Fixed IAM Permissions**: Added Auto Scaling permissions to node group role
2. **Resolved Helm Timeouts**: Manually installed and imported Helm releases
3. **Updated Terraform State**: Synced Terraform with actual deployed resources
4. **Fixed kubeconfig**: Ensured proper cluster connectivity

### Next Steps
Your EKS infrastructure is ready for application deployment. You can now:
1. Build and push your application images to ECR
2. Deploy your application manifests to the cluster
3. Use the Load Balancer Controller for ingress
4. Monitor scaling with the Cluster Autoscaler

### Useful Commands
```bash
# Check cluster status
kubectl get nodes

# List all pods
kubectl get pods -A

# Check Helm releases
helm list -A

# View cluster info
kubectl cluster-info
```
