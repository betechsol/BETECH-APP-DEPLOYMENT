# BETECH EKS ALB Controller Verification & Auto-Fix Script

## Overview
This script automatically verifies and fixes all IAM, OIDC, and security group issues required for AWS Load Balancer Controller deployment and proper application connectivity in the BETECH EKS cluster.

## Script Location
- **Main verification script**: `/home/ubuntu/BETECH-APP-DEPLOYMENT/verify-and-fix-alb-permissions.sh`
- **Quick annotation fix**: `/home/ubuntu/BETECH-APP-DEPLOYMENT/fix-alb-annotation.sh`

## Usage

### Quick Fix for Service Account Annotation (Recommended)
```bash
./fix-alb-annotation.sh
```
*This script specifically fixes the service account annotation issue with hardcoded fallback*

### Full Verification (All checks)
```bash
./verify-and-fix-alb-permissions.sh --verify-only
```

### Full Automatic Fix Mode
```bash
./verify-and-fix-alb-permissions.sh --fix
```

### Help
```bash
./verify-and-fix-alb-permissions.sh --help
```

## What the Script Verifies and Fixes

### 1. OIDC Trust Policy Format ✅
- **Verifies**: IAM role trust policies use correct OIDC issuer format
- **Issue**: Trust policies using incorrect issuer format preventing role assumption
- **Fix**: Updates `iam.tf` with correct `module.eks.cluster_oidc_issuer_url` format
- **Auto-applies**: Terraform changes to update IAM roles

### 2. IAM Permissions ✅
- **Verifies**: AWS Load Balancer Controller has all required permissions
- **Required Permissions**:
  - `elasticloadbalancing:DescribeListenerAttributes`
  - `ec2:AuthorizeSecurityGroupIngress`
  - `ec2:RevokeSecurityGroupIngress`
- **Issue**: Missing permissions preventing ALB provisioning
- **Fix**: Adds missing permissions to `iam.tf` and removes restrictive conditions
- **Auto-applies**: Terraform changes to update IAM policy

### 3. Security Group Tags ✅
- **Verifies**: EKS security groups have proper tags for ALB controller discovery
- **Required Tags**:
  - `kubernetes.io/cluster/<cluster-name>=owned`
  - `elbv2.k8s.aws/cluster=<cluster-name>`
- **Issue**: Missing tags preventing controller from managing security groups
- **Fix**: Applies tags to all EKS-related security groups
- **Direct AWS API**: No Terraform required

### 4. Backend Pod Security Group Access ✅
- **Verifies**: Security group rules allow backend pod access on port 8080
- **Checks**: All traffic rules (-1 protocol) or specific port 8080 rules
- **Issue**: ALB cannot reach backend pods
- **Fix**: Adds ingress rules for port 8080 from ALB security groups
- **Direct AWS API**: No Terraform required

### 5. Load Balancer Controller Deployment ✅
- **Verifies**: AWS Load Balancer Controller pods are running and ready
- **Issue**: Controller not deployed or not ready
- **Action**: Reports status, requires manual deployment if missing

### 6. Service Account Annotation ✅
- **Verifies**: Service account has correct IAM role annotation
- **Issue**: Service account cannot assume IAM role for ALB operations
- **Fix**: Automatically adds the correct `eks.amazonaws.com/role-arn` annotation
- **Auto-applies**: Restarts controller pods to pick up new permissions

### 7. Ingress and Target Group Health ✅
- **Verifies**: ALB is provisioned and target groups are healthy
- **Checks**: Ingress has ALB address and all targets are healthy
- **Issue**: ALB not working or targets unhealthy
- **Action**: Reports status and waits for health checks

### 8. Application Accessibility ✅
- **Tests**: HTTP redirect, HTTPS frontend, backend API connectivity
- **Verifies**: End-to-end application functionality through ALB
- **Issue**: Application not accessible via ALB
- **Action**: Reports connectivity status

## Current Status (Last Update - July 14, 2025 12:11 UTC)

✅ **Service Account Annotation Issue RESOLVED**

### 🔧 **Hardcoded IAM Role ARN Solution Applied:**

**Issue**: The service account annotation was getting reverted after ALB controller restarts, causing the annotation to be lost.

**Root Cause**: The Helm chart installation didn't include the correct IAM role ARN, so restarts would revert to the default (empty) annotation.

**Solution**: Implemented hardcoded IAM role ARN fallback in the verification script:
```bash
HARDCODED_ROLE_ARN="arn:aws:iam::374965156099:role/AmazonEKSLoadBalancerControllerRole-pn4ipago"
```

### 📁 **New Fix Script Created:**
- **`fix-alb-annotation.sh`** - Dedicated script for fixing service account annotation issues
- **Automatic detection** of Terraform output with hardcoded fallback
- **Verification before/after restart** to ensure annotation persistence
- **Automatic re-application** if annotation gets reverted

### ✅ **Current Verification Status:**
1. ✅ OIDC trust policy format is correct
2. ✅ All required IAM permissions are present
3. ✅ Security group has correct kubernetes.io/cluster tag  
4. ✅ Security group allows all traffic (includes backend port access)
5. ✅ AWS Load Balancer Controller is deployed and running (2 pods ready)
6. ✅ **Service account has correct IAM role annotation (FIXED with hardcoded fallback)**
7. ✅ Ingress and target group health verified
8. ✅ Application accessibility tests pass

**Application URL**: https://betech-app.betechsol.com (via ALB)
**ALB Address**: k8s-default-betechne-273078bb02-1163304503.us-west-2.elb.amazonaws.com

## Automation Features

- **Intelligent Detection**: Finds IAM policies by pattern matching when exact names vary
- **Safe Backups**: Creates timestamped backups before modifying `iam.tf`
- **Terraform Integration**: Automatically applies Terraform changes when needed
- **Pod Restart**: Restarts ALB controller pods to pick up new permissions
- **Health Monitoring**: Waits for target groups to become healthy after changes
- **Comprehensive Testing**: End-to-end connectivity verification

## Error Handling

- **Graceful Failures**: Continues verification even if individual checks fail
- **Detailed Logging**: Color-coded output with timestamps
- **Issue Counting**: Reports total number of issues found
- **Fix Confirmation**: Shows what was actually fixed
- **Rollback Safety**: Backup files allow manual rollback if needed

## Integration with Deployment Workflow

This script is designed to be run:
1. **After infrastructure deployment** - When EKS cluster is ready
2. **After ALB controller installation** - When Helm chart is deployed
3. **Before application testing** - To ensure connectivity
4. **During troubleshooting** - To diagnose ALB issues

## Dependencies

- AWS CLI configured with proper credentials
- kubectl configured for EKS cluster
- Terraform state available in `eks-deployment/` directory
- EKS cluster and ALB controller already deployed

## Success Criteria

The script considers the setup successful when:
- All IAM permissions are correctly configured
- OIDC trust relationships are properly formatted
- Security groups allow necessary traffic
- ALB controller is running and healthy
- Application is accessible through the ALB
- All target groups show healthy status
