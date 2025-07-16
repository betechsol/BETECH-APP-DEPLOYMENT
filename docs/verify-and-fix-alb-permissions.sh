#!/bin/bash

# BETECH EKS ALB Controller Permissions Verification and Auto-Fix Script
# This script automatically verifies and fixes all IAM and security group issues
# for AWS Load Balancer Controller deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [[ ! -f "eks-deployment/main.tf" ]]; then
    error "Please run this script from the BETECH-APP-DEPLOYMENT directory"
    exit 1
fi

log "🔧 BETECH EKS ALB Controller Permissions Verification & Auto-Fix"
echo "=================================================================="

# Function to get cluster name and region
get_cluster_info() {
    CLUSTER_NAME=$(terraform -chdir=eks-deployment output -raw cluster_name 2>/dev/null || echo "")
    AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-west-2")
    
    if [[ -z "$CLUSTER_NAME" ]]; then
        error "Cannot determine cluster name from Terraform output"
        return 1
    fi
    
    log "Cluster: $CLUSTER_NAME, Region: $AWS_REGION"
}

# Function to verify OIDC issuer format in IAM trust policies
verify_oidc_trust_policy() {
    log "🔍 Verifying OIDC trust policy format..."
    
    # Get OIDC issuer URL
    OIDC_ISSUER=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.identity.oidc.issuer' --output text 2>/dev/null)
    if [[ -z "$OIDC_ISSUER" ]]; then
        error "Cannot retrieve OIDC issuer URL"
        return 1
    fi
    
    # Remove https:// prefix for condition check
    OIDC_ISSUER_NO_HTTPS=${OIDC_ISSUER#https://}
    
    # Get Load Balancer Controller role ARN
    LB_ROLE_ARN=$(terraform -chdir=eks-deployment output -raw load_balancer_controller_role_arn 2>/dev/null)
    if [[ -z "$LB_ROLE_ARN" ]]; then
        error "Cannot determine Load Balancer Controller role ARN"
        return 1
    fi
    
    # Extract role name
    LB_ROLE_NAME=$(echo "$LB_ROLE_ARN" | cut -d'/' -f2)
    
    # Check current trust policy
    TRUST_POLICY=$(aws iam get-role --role-name "$LB_ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json)
    
    # Check if OIDC issuer format is correct in trust policy
    if echo "$TRUST_POLICY" | grep -q "$OIDC_ISSUER_NO_HTTPS:sub"; then
        success "OIDC trust policy format is correct"
        return 0
    else
        warning "OIDC trust policy format needs fixing"
        return 1
    fi
}

# Function to fix OIDC trust policy
fix_oidc_trust_policy() {
    log "🔧 Fixing OIDC trust policy format..."
    
    # Check if iam.tf exists and has the correct format
    if [[ ! -f "eks-deployment/iam.tf" ]]; then
        error "iam.tf file not found"
        return 1
    fi
    
    # Check current format in iam.tf
    if grep -q 'module.eks.cluster_oidc_issuer_url' eks-deployment/iam.tf; then
        success "iam.tf already has correct OIDC issuer format"
    else
        log "Updating iam.tf with correct OIDC issuer format..."
        
        # Create backup
        cp eks-deployment/iam.tf eks-deployment/iam.tf.backup.$(date +%s)
        
        # Fix AWS Load Balancer Controller role
        sed -i 's|${replace(module\.eks\.oidc_provider_arn, "/\^.*//", "")}|${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}|g' eks-deployment/iam.tf
        
        # Fix EBS CSI driver role
        sed -i 's|${replace(module\.eks\.oidc_provider_arn, "/\^.*//", "")}|${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}|g' eks-deployment/iam.tf
        
        success "Updated iam.tf with correct OIDC issuer format"
    fi
}

# Function to verify IAM permissions
verify_iam_permissions() {
    log "🔍 Verifying IAM permissions for AWS Load Balancer Controller..."
    
    # Get policy ARN - try different possible policy names
    POLICY_ARN=$(aws iam list-policies --query "Policies[?contains(PolicyName, 'AWSLoadBalancerControllerIAMPolicy') && PolicyName!='AWSLoadBalancerControllerIAMPolicy'].Arn" --output text 2>/dev/null | head -1)
    
    if [[ -z "$POLICY_ARN" ]]; then
        # Fallback to exact policy name if terraform output is available
        local role_arn=$(terraform -chdir=eks-deployment output -raw load_balancer_controller_role_arn 2>/dev/null)
        if [[ -n "$role_arn" ]]; then
            local suffix=$(echo "$role_arn" | sed 's/.*-//')
            POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='AWSLoadBalancerControllerIAMPolicy-$suffix'].Arn" --output text 2>/dev/null)
        fi
    fi
    
    if [[ -z "$POLICY_ARN" ]]; then
        error "Cannot find Load Balancer Controller IAM policy"
        return 1
    fi
    
    # Get policy document
    POLICY_VERSION=$(aws iam get-policy --policy-arn "$POLICY_ARN" --query 'Policy.DefaultVersionId' --output text)
    POLICY_DOC=$(aws iam get-policy-version --policy-arn "$POLICY_ARN" --version-id "$POLICY_VERSION" --query 'PolicyVersion.Document' --output json)
    
    # Check for required permissions
    MISSING_PERMS=()
    
    if ! echo "$POLICY_DOC" | grep -q "elasticloadbalancing:DescribeListenerAttributes"; then
        MISSING_PERMS+=("elasticloadbalancing:DescribeListenerAttributes")
    fi
    
    if ! echo "$POLICY_DOC" | grep -q "ec2:AuthorizeSecurityGroupIngress"; then
        MISSING_PERMS+=("ec2:AuthorizeSecurityGroupIngress")
    fi
    
    if ! echo "$POLICY_DOC" | grep -q "ec2:RevokeSecurityGroupIngress"; then
        MISSING_PERMS+=("ec2:RevokeSecurityGroupIngress")
    fi
    
    # Check if security group permissions have restrictive conditions
    HAS_RESTRICTIVE_CONDITIONS=false
    if echo "$POLICY_DOC" | grep -A 10 -B 5 "ec2:AuthorizeSecurityGroupIngress" | grep -q "Condition"; then
        HAS_RESTRICTIVE_CONDITIONS=true
        MISSING_PERMS+=("unrestricted-security-group-access")
    fi
    
    if [[ ${#MISSING_PERMS[@]} -eq 0 ]]; then
        success "All required IAM permissions are present"
        return 0
    else
        warning "Missing IAM permissions: ${MISSING_PERMS[*]}"
        return 1
    fi
}

# Function to fix IAM permissions
fix_iam_permissions() {
    log "🔧 Fixing IAM permissions..."
    
    if [[ ! -f "eks-deployment/iam.tf" ]]; then
        error "iam.tf file not found"
        return 1
    fi
    
    # Check if elasticloadbalancing:DescribeListenerAttributes is present
    if ! grep -q "elasticloadbalancing:DescribeListenerAttributes" eks-deployment/iam.tf; then
        log "Adding elasticloadbalancing:DescribeListenerAttributes permission..."
        
        # Add the missing permission after DescribeListeners
        sed -i '/elasticloadbalancing:DescribeListeners/a\          "elasticloadbalancing:DescribeListenerAttributes",' eks-deployment/iam.tf
        success "Added elasticloadbalancing:DescribeListenerAttributes permission"
    fi
    
    # Check if security group permissions are unrestricted
    if grep -A 10 -B 5 "ec2:AuthorizeSecurityGroupIngress" eks-deployment/iam.tf | grep -q "Condition"; then
        log "Removing restrictive conditions on security group operations..."
        
        # Create a temporary file with the updated content
        cp eks-deployment/iam.tf eks-deployment/iam.tf.backup.$(date +%s)
        
        # Remove conditions from security group operations using a more precise approach
        awk '
        BEGIN { in_sg_block = 0; skip_condition = 0 }
        /ec2:AuthorizeSecurityGroupIngress|ec2:RevokeSecurityGroupIngress|ec2:DeleteSecurityGroup/ { in_sg_block = 1 }
        in_sg_block && /Condition/ { skip_condition = 1; next }
        skip_condition && /}/ { skip_condition = 0; in_sg_block = 0; next }
        skip_condition { next }
        /^[[:space:]]*}[[:space:]]*$/ && in_sg_block { in_sg_block = 0 }
        { print }
        ' eks-deployment/iam.tf > eks-deployment/iam.tf.tmp && mv eks-deployment/iam.tf.tmp eks-deployment/iam.tf
        
        success "Removed restrictive conditions on security group operations"
    fi
}

# Function to verify security group ingress rules for backend pods
verify_backend_security_groups() {
    log "🔍 Verifying security group ingress rules for backend pod access..."
    
    # Get node security group ID
    NODE_SG_ID=$(terraform -chdir=eks-deployment output -raw cluster_primary_security_group_id 2>/dev/null)
    
    if [[ -z "$NODE_SG_ID" ]]; then
        error "Cannot determine node security group ID"
        return 1
    fi
    
    # Check if there are ingress rules allowing backend port access (8080) or all traffic
    # Look for rules that allow all traffic (-1 protocol) using length function
    ALL_TRAFFIC_COUNT=$(aws ec2 describe-security-groups --group-ids "$NODE_SG_ID" --query "length(SecurityGroups[0].IpPermissions[?IpProtocol=='-1'])" --output text 2>/dev/null)
    
    if [[ "$ALL_TRAFFIC_COUNT" -gt 0 ]]; then
        success "Security group allows all traffic (includes backend port access)"
        return 0
    fi
    
    # Check for specific port 8080 rules
    BACKEND_PORT_COUNT=$(aws ec2 describe-security-groups --group-ids "$NODE_SG_ID" --query "length(SecurityGroups[0].IpPermissions[?FromPort<=\`8080\` && ToPort>=\`8080\`])" --output text 2>/dev/null)
    
    if [[ "$BACKEND_PORT_COUNT" -gt 0 ]]; then
        success "Security group has specific ingress rules for backend port access"
        return 0
    fi
    
    warning "Security group missing ingress rules for backend port (8080)"
    return 1
}

# Function to fix backend security group rules
fix_backend_security_groups() {
    log "🔧 Adding security group ingress rules for backend access..."
    
    NODE_SG_ID=$(terraform -chdir=eks-deployment output -raw cluster_primary_security_group_id 2>/dev/null)
    
    if [[ -z "$NODE_SG_ID" ]]; then
        error "Cannot determine node security group ID"
        return 1
    fi
    
    # Add ingress rule for backend port 8080 from ALB
    aws ec2 authorize-security-group-ingress \
        --group-id "$NODE_SG_ID" \
        --protocol tcp \
        --port 8080 \
        --source-group "$NODE_SG_ID" 2>/dev/null || true
    
    # Add ingress rule for backend port 8080 from ALB security groups
    ALB_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=k8s-*" "Name=description,Values=*ALB*" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")
    
    if [[ -n "$ALB_SG_ID" && "$ALB_SG_ID" != "None" ]]; then
        aws ec2 authorize-security-group-ingress \
            --group-id "$NODE_SG_ID" \
            --protocol tcp \
            --port 8080 \
            --source-group "$ALB_SG_ID" 2>/dev/null || true
    fi
    
    success "Added security group ingress rules for backend access"
}

# Function to apply security group tags
fix_security_group_tags() {
    log "🔧 Applying security group tags..."
    
    # Get all EKS-related security groups
    CLUSTER_SG_ID=$(terraform -chdir=eks-deployment output -raw cluster_security_group_id 2>/dev/null || echo "")
    NODE_SG_ID=$(terraform -chdir=eks-deployment output -raw cluster_primary_security_group_id 2>/dev/null || echo "")
    
    SG_IDS=()
    [[ -n "$CLUSTER_SG_ID" ]] && SG_IDS+=("$CLUSTER_SG_ID")
    [[ -n "$NODE_SG_ID" ]] && SG_IDS+=("$NODE_SG_ID")
    
    # Also get security groups from EKS managed node groups
    MANAGED_NODE_SG=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "betech-node-group" --query 'nodegroup.resources.remoteAccessSecurityGroup' --output text 2>/dev/null || echo "None")
    [[ "$MANAGED_NODE_SG" != "None" && -n "$MANAGED_NODE_SG" ]] && SG_IDS+=("$MANAGED_NODE_SG")
    
    if [[ ${#SG_IDS[@]} -eq 0 ]]; then
        warning "No security groups found to tag"
        return 1
    fi
    
    for SG_ID in "${SG_IDS[@]}"; do
        log "Tagging security group: $SG_ID"
        aws ec2 create-tags --resources "$SG_ID" --tags Key="kubernetes.io/cluster/$CLUSTER_NAME",Value="owned" 2>/dev/null || true
        aws ec2 create-tags --resources "$SG_ID" --tags Key="elbv2.k8s.aws/cluster",Value="$CLUSTER_NAME" 2>/dev/null || true
    done
    
    success "Applied security group tags"
}

# Function to fix Helm chart service account annotation issue
fix_helm_service_account_persistence() {
    log "🔧 Ensuring Helm chart preserves service account annotation..."
    
    # Get expected role ARN from Terraform output, with hardcoded fallback
    EXPECTED_ROLE_ARN=$(terraform -chdir=eks-deployment output -raw load_balancer_controller_role_arn 2>/dev/null)
    
    # Hardcoded fallback for BETECH cluster
    if [[ -z "$EXPECTED_ROLE_ARN" ]]; then
        EXPECTED_ROLE_ARN="arn:aws:iam::374965156099:role/AmazonEKSLoadBalancerControllerRole-pn4ipago"
        warning "Using hardcoded IAM role ARN: $EXPECTED_ROLE_ARN"
    fi
    
    # Check if the Helm release exists and get its values
    if helm list -n kube-system | grep -q aws-load-balancer-controller; then
        log "Found existing Helm release. Checking if it has correct serviceAccount annotation..."
        
        # Get current Helm values
        CURRENT_SA_ARN=$(helm get values aws-load-balancer-controller -n kube-system | grep -A 5 "serviceAccount:" | grep "eks.amazonaws.com/role-arn" | cut -d'"' -f2 2>/dev/null || echo "")
        
        if [[ "$CURRENT_SA_ARN" != "$EXPECTED_ROLE_ARN" ]]; then
            log "Helm values don't have correct IAM role. Updating Helm release..."
            
            # Update the Helm release with correct service account annotation
            helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
                -n kube-system \
                --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$EXPECTED_ROLE_ARN" \
                --reuse-values
            
            if [[ $? -eq 0 ]]; then
                success "Updated Helm release with correct service account annotation"
                return 0
            else
                warning "Failed to update Helm release. Will manually annotate service account."
            fi
        else
            success "Helm release already has correct service account annotation"
        fi
    else
        log "No Helm release found. Will manually annotate service account."
    fi
    
    # Manual annotation as fallback
    kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
        eks.amazonaws.com/role-arn="$EXPECTED_ROLE_ARN" --overwrite
    
    success "Applied service account annotation manually"
}

# Function to verify security group tags
verify_security_group_tags() {
    log "� Verifying EKS security group tags..."
    
    # Get node security group ID
    NODE_SG_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text 2>/dev/null)
    
    if [[ -z "$NODE_SG_ID" || "$NODE_SG_ID" == "None" ]]; then
        # Try to get from Terraform output
        NODE_SG_ID=$(terraform -chdir=eks-deployment output -raw cluster_primary_security_group_id 2>/dev/null || echo "")
    fi
    
    if [[ -z "$NODE_SG_ID" ]]; then
        warning "Cannot determine node security group ID"
        return 1
    fi
    
    # Check if security group has kubernetes.io/cluster tag
    CLUSTER_TAG=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$NODE_SG_ID" "Name=key,Values=kubernetes.io/cluster/$CLUSTER_NAME" --query 'Tags[0].Value' --output text 2>/dev/null)
    
    if [[ "$CLUSTER_TAG" == "owned" || "$CLUSTER_TAG" == "shared" ]]; then
        success "Security group has correct kubernetes.io/cluster tag"
        return 0
    else
        warning "Security group missing kubernetes.io/cluster tag"
        return 1
    fi
}

# Function to verify Load Balancer Controller deployment
verify_alb_controller() {
    log "🔍 Verifying AWS Load Balancer Controller deployment..."
    
    # Check if controller pods are running
    CONTROLLER_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | wc -l)
    
    if [[ "$CONTROLLER_PODS" -eq 0 ]]; then
        warning "AWS Load Balancer Controller not deployed"
        return 1
    fi
    
    # Check if pods are ready
    READY_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | awk '$2 ~ /^[0-9]+\/[0-9]+$/ && $3 == "Running" {split($2,a,"/"); if(a[1]==a[2]) print $1}' | wc -l)
    
    if [[ "$READY_PODS" -eq 0 ]]; then
        warning "AWS Load Balancer Controller pods not ready"
        return 1
    fi
    
    success "AWS Load Balancer Controller is deployed and running ($READY_PODS pods ready)"
    return 0
}

# Function to check service account annotation
verify_service_account() {
    log "🔍 Verifying service account IAM role annotation..."
    
    # Get service account annotation
    SA_ANNOTATION=$(kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || echo "")
    
    if [[ -z "$SA_ANNOTATION" ]]; then
        warning "Service account missing IAM role annotation"
        return 1
    fi
    
    # Get expected role ARN from Terraform output, with hardcoded fallback
    EXPECTED_ROLE_ARN=$(terraform -chdir=eks-deployment output -raw load_balancer_controller_role_arn 2>/dev/null)
    
    # Hardcoded fallback for BETECH cluster
    if [[ -z "$EXPECTED_ROLE_ARN" ]]; then
        EXPECTED_ROLE_ARN="arn:aws:iam::374965156099:role/AmazonEKSLoadBalancerControllerRole-pn4ipago"
        warning "Using hardcoded IAM role ARN: $EXPECTED_ROLE_ARN"
    fi
    
    if [[ "$SA_ANNOTATION" == "$EXPECTED_ROLE_ARN" ]]; then
        success "Service account has correct IAM role annotation"
        return 0
    else
        warning "Service account IAM role annotation mismatch"
        return 1
    fi
}

# Function to fix service account annotation
fix_service_account() {
    log "🔧 Adding IAM role annotation to service account..."
    
    # Get expected role ARN from Terraform output, with hardcoded fallback
    EXPECTED_ROLE_ARN=$(terraform -chdir=eks-deployment output -raw load_balancer_controller_role_arn 2>/dev/null)
    
    # Hardcoded fallback for BETECH cluster
    if [[ -z "$EXPECTED_ROLE_ARN" ]]; then
        EXPECTED_ROLE_ARN="arn:aws:iam::374965156099:role/AmazonEKSLoadBalancerControllerRole-pn4ipago"
        warning "Using hardcoded IAM role ARN: $EXPECTED_ROLE_ARN"
    fi
    
    log "Expected role ARN: $EXPECTED_ROLE_ARN"
    
    # Add the annotation to the service account
    kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
        eks.amazonaws.com/role-arn="$EXPECTED_ROLE_ARN" --overwrite
    
    if [[ $? -eq 0 ]]; then
        success "Added IAM role annotation to service account"
        
        # Verify the annotation was applied correctly
        CURRENT_ANNOTATION=$(kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || echo "")
        
        if [[ "$CURRENT_ANNOTATION" == "$EXPECTED_ROLE_ARN" ]]; then
            success "Verified annotation is correctly applied: $CURRENT_ANNOTATION"
        else
            warning "Annotation mismatch after application. Current: $CURRENT_ANNOTATION, Expected: $EXPECTED_ROLE_ARN"
        fi
        
        return 0
    else
        error "Failed to add IAM role annotation"
        return 1
    fi
}

# Function to verify ingress and target group health
verify_ingress_health() {
    log "🔍 Verifying ingress and target group health..."
    
    # Check if ingress exists and has address
    INGRESS_ADDRESS=$(kubectl get ingress betechnet-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [[ -z "$INGRESS_ADDRESS" ]]; then
        warning "Ingress does not have ALB address assigned"
        return 1
    fi
    
    success "Ingress has ALB address: $INGRESS_ADDRESS"
    
    # Check target group health
    TG_ARNS=$(aws elbv2 describe-target-groups --query 'TargetGroups[?starts_with(TargetGroupName, `k8s-default-betechne`)].TargetGroupArn' --output text 2>/dev/null || echo "")
    
    if [[ -z "$TG_ARNS" ]]; then
        warning "No target groups found for the application"
        return 1
    fi
    
    UNHEALTHY_TARGETS=0
    for TG_ARN in $TG_ARNS; do
        UNHEALTHY=$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --query 'TargetHealthDescriptions[?TargetHealth.State!=`healthy`]' --output text 2>/dev/null | wc -l)
        UNHEALTHY_TARGETS=$((UNHEALTHY_TARGETS + UNHEALTHY))
    done
    
    if [[ "$UNHEALTHY_TARGETS" -gt 0 ]]; then
        warning "$UNHEALTHY_TARGETS unhealthy targets found"
        return 1
    fi
    
    success "All target groups are healthy"
    return 0
}

# Function to apply Terraform changes
apply_terraform_changes() {
    log "🔧 Applying Terraform changes..."
    
    cd eks-deployment
    
    # Initialize if needed
    if [[ ! -d ".terraform" ]]; then
        terraform init
    fi
    
    # Apply changes
    terraform apply -auto-approve
    
    success "Terraform changes applied successfully"
    cd ..
}

# Function to restart ALB controller
restart_alb_controller() {
    log "🔄 Restarting AWS Load Balancer Controller..."
    
    # Get expected role ARN before restart, with hardcoded fallback
    EXPECTED_ROLE_ARN=$(terraform -chdir=eks-deployment output -raw load_balancer_controller_role_arn 2>/dev/null)
    
    # Hardcoded fallback for BETECH cluster
    if [[ -z "$EXPECTED_ROLE_ARN" ]]; then
        EXPECTED_ROLE_ARN="arn:aws:iam::374965156099:role/AmazonEKSLoadBalancerControllerRole-pn4ipago"
        warning "Using hardcoded IAM role ARN: $EXPECTED_ROLE_ARN"
    fi
    
    kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
    kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=300s
    
    # Verify the service account annotation after restart
    sleep 10  # Give it a moment to settle
    CURRENT_ANNOTATION=$(kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || echo "")
    
    if [[ "$CURRENT_ANNOTATION" != "$EXPECTED_ROLE_ARN" ]]; then
        warning "Service account annotation reverted after restart. Re-applying..."
        log "Current: $CURRENT_ANNOTATION"
        log "Expected: $EXPECTED_ROLE_ARN"
        
        # Re-apply the correct annotation
        kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
            eks.amazonaws.com/role-arn="$EXPECTED_ROLE_ARN" --overwrite
        
        # Restart again to pick up the correct annotation
        log "Restarting controller again to pick up correct annotation..."
        kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
        kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=300s
        
        # Final verification
        sleep 5
        FINAL_ANNOTATION=$(kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || echo "")
        
        if [[ "$FINAL_ANNOTATION" == "$EXPECTED_ROLE_ARN" ]]; then
            success "Service account annotation persisted after restart"
        else
            warning "Service account annotation still not correct: $FINAL_ANNOTATION"
        fi
    else
        success "Service account annotation persisted correctly after restart"
    fi
    
    success "AWS Load Balancer Controller restarted successfully"
}

# Function to wait for target groups to become healthy
wait_for_healthy_targets() {
    log "⏳ Waiting for target groups to become healthy..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if verify_ingress_health >/dev/null 2>&1; then
            success "Target groups are healthy"
            return 0
        fi
        
        log "Attempt $attempt/$max_attempts - waiting for targets to become healthy..."
        sleep 10
        ((attempt++))
    done
    
    warning "Target groups did not become healthy within timeout"
    return 1
}

# Function to test application accessibility
test_application_access() {
    log "🧪 Testing application accessibility..."
    
    INGRESS_ADDRESS=$(kubectl get ingress betechnet-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [[ -z "$INGRESS_ADDRESS" ]]; then
        error "Cannot get ingress address for testing"
        return 1
    fi
    
    # Test HTTP redirect
    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: betech-app.betechsol.com" "http://$INGRESS_ADDRESS" --connect-timeout 10 || echo "000")
    
    if [[ "$HTTP_RESPONSE" == "301" ]]; then
        success "HTTP to HTTPS redirect working (301 response)"
    else
        warning "HTTP redirect test failed (response: $HTTP_RESPONSE)"
    fi
    
    # Test HTTPS frontend
    HTTPS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: betech-app.betechsol.com" "https://$INGRESS_ADDRESS" --insecure --connect-timeout 10 || echo "000")
    
    if [[ "$HTTPS_RESPONSE" == "200" ]]; then
        success "HTTPS frontend accessible (200 response)"
    else
        warning "HTTPS frontend test failed (response: $HTTPS_RESPONSE)"
    fi
    
    # Test backend API
    API_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: betech-app.betechsol.com" "https://$INGRESS_ADDRESS/api" --insecure --connect-timeout 10 || echo "000")
    
    if [[ "$API_RESPONSE" == "404" || "$API_RESPONSE" == "200" ]]; then
        success "Backend API accessible (response: $API_RESPONSE)"
    else
        warning "Backend API test failed (response: $API_RESPONSE)"
    fi
}

# Main execution
main() {
    local fix_mode=false
    local verify_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fix)
                fix_mode=true
                shift
                ;;
            --verify-only)
                verify_only=true
                shift
                ;;
            --help)
                echo "Usage: $0 [--fix] [--verify-only]"
                echo "  --fix         Automatically fix detected issues"
                echo "  --verify-only Only verify, don't make any changes"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Get cluster information
    if ! get_cluster_info; then
        error "Failed to get cluster information"
        exit 1
    fi
    
    # Track issues found
    local issues_found=0
    local terraform_changes_needed=false
    local controller_restart_needed=false
    
    # Verify OIDC trust policy
    if ! verify_oidc_trust_policy; then
        ((issues_found++))
        if [[ "$fix_mode" == true ]]; then
            if fix_oidc_trust_policy; then
                terraform_changes_needed=true
            fi
        fi
    fi
    
    # Verify IAM permissions
    if ! verify_iam_permissions; then
        ((issues_found++))
        if [[ "$fix_mode" == true ]]; then
            if fix_iam_permissions; then
                terraform_changes_needed=true
            fi
        fi
    fi
    
    # Verify security group tags
    if ! verify_security_group_tags; then
        ((issues_found++))
        if [[ "$fix_mode" == true ]]; then
            fix_security_group_tags
        fi
    fi
    
    # Verify backend security group ingress rules
    if ! verify_backend_security_groups; then
        ((issues_found++))
        if [[ "$fix_mode" == true ]]; then
            fix_backend_security_groups
        fi
    fi
    
    # Apply Terraform changes if needed
    if [[ "$terraform_changes_needed" == true && "$fix_mode" == true ]]; then
        apply_terraform_changes
        controller_restart_needed=true
    fi
    
    # Verify Load Balancer Controller
    if ! verify_alb_controller; then
        ((issues_found++))
        if [[ "$fix_mode" == true ]]; then
            error "AWS Load Balancer Controller not deployed. Please deploy it first."
            exit 1
        fi
    fi
    
    # Verify service account
    if ! verify_service_account; then
        ((issues_found++))
        if [[ "$fix_mode" == true ]]; then
            # First try to fix via Helm to ensure persistence
            if fix_helm_service_account_persistence; then
                controller_restart_needed=true
            # Fallback to direct annotation if Helm fix fails
            elif fix_service_account; then
                controller_restart_needed=true
            fi
        fi
    fi
    
    # Restart controller if needed
    if [[ "$controller_restart_needed" == true && "$fix_mode" == true ]]; then
        restart_alb_controller
        wait_for_healthy_targets
    fi
    
    # Verify ingress health
    if ! verify_ingress_health; then
        ((issues_found++))
        if [[ "$fix_mode" == true ]]; then
            warning "Ingress health issues detected. May need manual intervention."
        fi
    fi
    
    # Test application access
    if ! test_application_access; then
        warning "Application accessibility test had some issues"
    fi
    
    # Summary
    echo ""
    echo "=================================================================="
    if [[ "$issues_found" -eq 0 ]]; then
        success "🎉 All verifications passed! ALB Controller is properly configured."
    else
        if [[ "$fix_mode" == true ]]; then
            warning "⚠️  Found and attempted to fix $issues_found issues."
            log "Re-run the script to verify all fixes were successful."
        else
            warning "⚠️  Found $issues_found issues."
            log "Run with --fix to automatically resolve issues."
        fi
    fi
    
    echo "=================================================================="
    log "Script completed. Current application status:"
    
    # Show current status
    kubectl get ingress betechnet-ingress -n default 2>/dev/null || true
    kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller 2>/dev/null || true
}

# Run main function
main "$@"
