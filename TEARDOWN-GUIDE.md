# BETECH EKS Teardown Guide

## Overview
This guide explains how to safely tear down the BETECH EKS application and cluster using the provided teardown script.

## Script Location
- **Script**: `teardown-eks.sh`
- **Purpose**: Safely remove all BETECH EKS resources
- **Account**: AWS Account ID 374965156099
- **Region**: us-west-2

## Prerequisites
Before running the teardown script, ensure you have:

1. **AWS CLI** configured with appropriate credentials
2. **eksctl** installed and working
3. **kubectl** installed and working
4. **Docker** installed (optional, for image cleanup)
5. **Proper IAM permissions** to delete EKS resources

## Usage Options

### 1. Interactive Teardown (Recommended)
```bash
./teardown-eks.sh
```
- Includes multiple confirmation prompts
- Shows detailed information about what will be deleted
- Safest option for manual execution

### 2. Dry Run (Preview Only)
```bash
./teardown-eks.sh --dry-run
```
- Shows what would be deleted without actually deleting anything
- No confirmation prompts
- Perfect for planning and verification

### 3. Force Mode (Use with Caution)
```bash
./teardown-eks.sh --force
```
- Skips all confirmation prompts
- Proceeds directly with deletion
- **WARNING**: Use only when you're absolutely certain

### 4. Help Information
```bash
./teardown-eks.sh --help
```
- Shows usage information and examples

## What Gets Deleted

The teardown script removes resources in this order:

### 1. Application Components
- **Ingress**: `betechnet-ingress` (triggers ALB deletion)
- **Deployments**: 
  - `betechnet-frontend`
  - `betechnet-backend`
  - `betechnet-postgres`
- **Services**:
  - `betechnet-frontend`
  - `betechnet-backend`
  - `betechnet-postgres`
- **Secrets**: `betechnet-secrets`

### 2. Persistent Storage
- **PVC**: `postgres-pvc` (also deletes associated EBS volume)
- **Storage Class**: `betech-storage-class` (if custom)

### 3. AWS Load Balancer Controller
- **Helm Release**: `aws-load-balancer-controller` (if installed via Helm)
- **Kubernetes Manifests**: ALB controller deployments
- **IAM Service Account**: `aws-load-balancer-controller`

### 4. EBS CSI Driver
- **IAM Service Account**: `ebs-csi-controller-sa`

### 5. EKS Cluster
- **EKS Cluster**: `betech-eks-cluster`
- **Worker Nodes**: All managed node groups
- **VPC Components**: (if created by eksctl)
- **Security Groups**: Cluster-related security groups
- **IAM Roles**: EKS-related IAM roles

### 6. Additional IAM Policies
- **Custom Policies**: ALB additional permissions

### 7. Optional Cleanup
- **Docker Images**: Local Docker images (optional)
- **ECR Repositories**: All three repositories (optional)

## Safety Features

### Confirmation Prompts
- **Main Teardown**: Confirms complete teardown
- **Cluster Deletion**: Additional confirmation for cluster deletion
- **Docker Cleanup**: Optional Docker image removal
- **ECR Cleanup**: Optional ECR repository deletion

### Error Handling
- Graceful error handling for missing resources
- Continues execution even if some resources don't exist
- Detailed logging of all operations

### Verification
- Checks if cluster still exists after deletion
- Scans for orphaned EBS volumes
- Scans for orphaned security groups
- Provides status report on cleanup completion

## Example Execution

### Typical Interactive Session
```bash
$ ./teardown-eks.sh

[INFO] Starting BETECH EKS teardown...
[INFO] Checking prerequisites...
[INFO] Prerequisites check completed!

========================================
BETECH EKS TEARDOWN PLAN
========================================

This script will perform the following actions:

1. 🗑️  Remove application components (ingress, deployments, services)
2. 💾 Remove persistent storage (PVC and EBS volumes)
3. ⚖️  Remove AWS Load Balancer Controller
4. 💽 Remove EBS CSI Driver components
5. 🔥 Delete entire EKS cluster
6. 🐳 Clean up Docker images (optional)
7. 📦 Clean up ECR repositories (optional)
8. 🔐 Clean up additional IAM roles
9. ✅ Verify cleanup completion

⚠️  WARNING: This action is IRREVERSIBLE!
⚠️  All application data will be PERMANENTLY LOST!

⚠️  WARNING: This will PROCEED WITH COMPLETE TEARDOWN
Are you sure you want to continue? (yes/no): yes

[INFO] Cluster found and kubeconfig updated.
[ACTION] Removing application components...
[INFO] Removing ingress (this will delete the ALB)...
[INFO] Waiting for ALB to be deleted (30 seconds)...
[INFO] Removing application deployments...
...
```

## Post-Teardown Verification

After teardown completion, verify:

1. **AWS Console**: Check EKS, EC2, VPC services for remaining resources
2. **Billing**: Monitor AWS billing for any ongoing charges
3. **Local Environment**: Clean up local kubeconfig if needed

### Manual Cleanup Commands (if needed)
```bash
# Remove kubeconfig context
kubectl config delete-context arn:aws:eks:us-west-2:374965156099:cluster/betech-eks-cluster

# Check for orphaned EBS volumes
aws ec2 describe-volumes --region us-west-2 --filters "Name=tag:kubernetes.io/cluster/betech-eks-cluster,Values=owned"

# Check for orphaned security groups
aws ec2 describe-security-groups --region us-west-2 --filters "Name=tag:kubernetes.io/cluster/betech-eks-cluster,Values=owned"
```

## Troubleshooting

### Common Issues

1. **Script Hangs or Fails**
   - Check AWS credentials: `aws sts get-caller-identity`
   - Verify cluster exists: `eksctl get cluster --region us-west-2`
   - Check network connectivity

2. **Incomplete Cleanup**
   - Run verification commands manually
   - Use AWS console to check for remaining resources
   - Consider running the script again

3. **Permission Errors**
   - Ensure IAM user/role has necessary permissions
   - Check if MFA is required
   - Verify region settings

### Recovery Options

If teardown is interrupted:

1. **Resume from where it left off**: Run the script again
2. **Manual cleanup**: Use AWS console or CLI commands
3. **Partial cleanup**: Use `--dry-run` to see what remains

## Cost Considerations

- **EBS Volumes**: Deleted automatically with PVCs
- **Load Balancers**: Deleted with ingress removal
- **NAT Gateways**: Deleted with VPC (if created by eksctl)
- **EKS Cluster**: Stops charging immediately upon deletion
- **EC2 Instances**: Terminated with node groups

## Security Notes

- Script requires significant AWS permissions
- Consider using a dedicated teardown IAM role
- Audit logs are available in CloudTrail
- All data deletion is irreversible

## Related Scripts

- **`deploy-eks.sh`**: Deployment script
- **`verify-deployment.sh`**: Verification script
- **SCRIPTS-GUIDE.md**: Complete workflow guide
