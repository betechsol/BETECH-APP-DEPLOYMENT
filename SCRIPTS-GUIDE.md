# BETECH EKS Deployment & Teardown Scripts

## 📋 Quick Reference Guide

### 🚀 Deployment Script: `deploy-eks.sh`

**Purpose**: Deploys the complete BETECH application on AWS EKS with ALB support.

#### Usage:
```bash
# Make executable
chmod +x deploy-eks.sh

# Run deployment
./deploy-eks.sh
```

#### What it does:
1. ✅ **Prerequisites Check**: Verifies eksctl, kubectl, AWS CLI, and credentials
2. 🏗️ **EKS Cluster**: Creates cluster using `manifests/eks-cluster-config.yaml`
3. ⚖️ **ALB Controller**: Installs AWS Load Balancer Controller with proper IAM
4. 🐳 **Docker Images**: Builds and pushes all images to ECR
5. 💾 **Storage**: Deploys PVC with gp2 storage class
6. 🚀 **Application**: Deploys PostgreSQL → Backend → Frontend → Ingress
7. 🌐 **URL**: Provides ALB URL and DNS instructions

#### Prerequisites:
- AWS CLI configured with proper credentials
- Docker installed and running
- eksctl installed
- kubectl installed

---

### 🗑️ Teardown Script: `teardown-eks.sh`

**Purpose**: Safely removes all BETECH EKS resources in the correct order.

#### Usage:
```bash
# Make executable
chmod +x teardown-eks.sh

# Interactive teardown (recommended)
./teardown-eks.sh

# Show what would be deleted (dry run)
./teardown-eks.sh --dry-run

# Force deletion without confirmations (dangerous!)
./teardown-eks.sh --force

# Show help
./teardown-eks.sh --help
```

#### What it does:
1. 🗑️ **Application**: Removes ingress (deletes ALB), deployments, services
2. 💾 **Storage**: Removes PVC and EBS volumes (DATA LOSS!)
3. ⚖️ **ALB Controller**: Uninstalls controller and IAM service account
4. 💽 **EBS CSI**: Removes EBS CSI driver components
5. 🔐 **IAM Cleanup**: Removes additional IAM policies
6. 🔥 **Cluster**: Deletes entire EKS cluster and VPC
7. 🐳 **Docker** (Optional): Removes local Docker images
8. 📦 **ECR** (Optional): Deletes ECR repositories
9. ✅ **Verification**: Checks for orphaned resources

#### Safety Features:
- **Multiple Confirmations**: Asks for confirmation before destructive actions
- **Dry Run Mode**: Shows what would be deleted without doing it
- **Order Matters**: Deletes resources in correct dependency order
- **Orphan Detection**: Checks for leftover EBS volumes and security groups
- **Force Mode**: For automated scenarios (use with extreme caution)

---

## 🔄 Complete Workflow Examples

### Fresh Deployment:
```bash
# 1. Deploy everything
./deploy-eks.sh

# 2. Wait for completion and test
kubectl get pods
kubectl get ingress
curl -k https://betech-app.betechsol.com/

# 3. Verify with verification script
./verify-deployment.sh
```

### Testing/Development Cycle:
```bash
# Deploy
./deploy-eks.sh

# Test your changes...

# Quick teardown for testing
./teardown-eks.sh --force

# Redeploy with changes
./deploy-eks.sh
```

### Production Deployment:
```bash
# 1. Dry run to see what will be deployed
./deploy-eks.sh --help  # (add dry-run if you modify script)

# 2. Deploy with verification
./deploy-eks.sh

# 3. Full verification
./verify-deployment.sh

# 4. Monitor and validate
kubectl get all
kubectl logs -f deployment/betechnet-backend
```

### Safe Teardown:
```bash
# 1. Check what will be deleted
./teardown-eks.sh --dry-run

# 2. Backup any important data first!

# 3. Interactive teardown with confirmations
./teardown-eks.sh

# 4. Verify cleanup
aws eks list-clusters --region us-west-2
```

---

## ⚠️ Important Notes

### Data Loss Warning:
- **Teardown deletes ALL data permanently!**
- PVC deletion removes EBS volumes and all database data
- ECR repository deletion removes all Docker images
- No recovery possible after teardown

### Cost Optimization:
- **EKS Cluster**: ~$0.10/hour (~$72/month)
- **Worker Nodes**: 2 × t3.medium = ~$0.08/hour (~$60/month)
- **ALB**: ~$0.025/hour (~$18/month)
- **EBS Storage**: 10GB × $0.10/GB/month = ~$1/month
- **Total**: ~$150/month

### Security Considerations:
- Scripts require full AWS admin permissions
- ALB is internet-facing (ensure proper security groups)
- Use specific IAM policies in production
- Review all IAM roles and permissions

### Troubleshooting:
```bash
# Check cluster status
kubectl cluster-info

# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check EBS CSI driver logs
kubectl logs -n kube-system deployment/ebs-csi-controller

# Check application logs
kubectl logs deployment/betechnet-backend
kubectl logs deployment/betechnet-frontend

# Debug ingress
kubectl describe ingress betechnet-ingress

# Debug PVC
kubectl describe pvc postgres-pvc
```

---

## 📞 Support Commands

### Quick Status Check:
```bash
# All-in-one status
kubectl get all && kubectl get pvc && kubectl get ingress

# Detailed verification
./verify-deployment.sh
```

### Emergency Cleanup:
```bash
# If normal teardown fails
./teardown-eks.sh --force

# Manual cluster deletion
eksctl delete cluster --name betech-eks-cluster --region us-west-2
```

---

**Remember**: Always run `--dry-run` first when testing scripts in production! 🚨
