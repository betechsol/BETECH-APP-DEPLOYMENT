#!/bin/bash

# BETECH EKS Teardown Verification Script
echo "=================================================="
echo "🔍 BETECH EKS TEARDOWN VERIFICATION"
echo "=================================================="
echo "Generated: $(date)"
echo ""

CLUSTER_NAME="betech-eks-cluster"
REGION="us-west-2"
ACCOUNT_ID="374965156099"

echo "🔍 Checking EKS Cluster Status..."
CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "  Status: $CLUSTER_STATUS"
    if [ "$CLUSTER_STATUS" = "DELETING" ]; then
        echo "  ⏳ Cluster is being deleted..."
    else
        echo "  ⚠️  Cluster still exists with status: $CLUSTER_STATUS"
    fi
else
    echo "  ✅ Cluster not found (successfully deleted)"
fi

echo ""
echo "🔍 Checking Node Groups..."
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query 'nodegroups' --output text 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$NODE_GROUPS" ]; then
    echo "  ⚠️  Node groups still exist: $NODE_GROUPS"
else
    echo "  ✅ No node groups found"
fi

echo ""
echo "🔍 Checking Load Balancers..."
ALB_COUNT=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-default-betechne`)].LoadBalancerName' --output text 2>/dev/null | wc -w)
if [ "$ALB_COUNT" -gt 0 ]; then
    echo "  ⚠️  $ALB_COUNT ALB(s) still exist"
    aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-default-betechne`)].{Name:LoadBalancerName,State:State.Code}' --output table 2>/dev/null
else
    echo "  ✅ No BETECH ALBs found"
fi

echo ""
echo "🔍 Checking ECR Repositories..."
BETECH_REPOS=$(aws ecr describe-repositories --region $REGION --query 'repositories[?contains(repositoryName, `betech`)].repositoryName' --output text 2>/dev/null)
if [ -n "$BETECH_REPOS" ]; then
    echo "  ⚠️  ECR repositories still exist: $BETECH_REPOS"
else
    echo "  ✅ No BETECH ECR repositories found"
fi

echo ""
echo "🔍 Checking IAM Roles..."
BETECH_ROLES=$(aws iam list-roles --query 'Roles[?contains(RoleName, `betech`) || contains(RoleName, `AmazonEKSLoadBalancerControllerRole`)].RoleName' --output text 2>/dev/null)
if [ -n "$BETECH_ROLES" ]; then
    echo "  ⚠️  IAM roles still exist:"
    echo "$BETECH_ROLES" | tr '\t' '\n' | sed 's/^/    - /'
else
    echo "  ✅ No BETECH IAM roles found"
fi

echo ""
echo "🔍 Checking CloudFormation Stacks..."
BETECH_STACKS=$(aws cloudformation list-stacks --region $REGION --query 'StackSummaries[?contains(StackName, `betech`) || contains(StackName, `eksctl`)].{Name:StackName,Status:StackStatus}' --output text 2>/dev/null | grep -v DELETE_COMPLETE)
if [ -n "$BETECH_STACKS" ]; then
    echo "  ⚠️  CloudFormation stacks still exist:"
    echo "$BETECH_STACKS" | sed 's/^/    /'
else
    echo "  ✅ No active BETECH CloudFormation stacks found"
fi

echo ""
echo "📋 Teardown Summary:"
echo "==================="

# Count remaining resources
CLUSTER_EXISTS=0
if [ "$CLUSTER_STATUS" != "" ] && [ "$CLUSTER_STATUS" != "DELETING" ]; then
    CLUSTER_EXISTS=1
fi

NODE_GROUP_EXISTS=0
if [ -n "$NODE_GROUPS" ]; then
    NODE_GROUP_EXISTS=1
fi

if [ $CLUSTER_EXISTS -eq 0 ] && [ $NODE_GROUP_EXISTS -eq 0 ] && [ "$ALB_COUNT" -eq 0 ]; then
    echo "  ✅ Primary EKS resources successfully removed"
else
    echo "  ⚠️  Some resources still exist and may need manual cleanup"
fi

if [ -z "$BETECH_REPOS" ] && [ -z "$BETECH_ROLES" ]; then
    echo "  ✅ Supporting resources (ECR, IAM) cleaned up"
else
    echo "  ⚠️  Some supporting resources remain"
fi

echo ""
if [ $CLUSTER_EXISTS -eq 0 ] && [ $NODE_GROUP_EXISTS -eq 0 ] && [ "$ALB_COUNT" -eq 0 ] && [ -z "$BETECH_REPOS" ]; then
    echo "🎉 TEARDOWN COMPLETED SUCCESSFULLY!"
    echo "   All major BETECH EKS resources have been removed."
else
    echo "⚠️  TEARDOWN PARTIALLY COMPLETE"
    echo "   Some resources may need additional time or manual cleanup."
    echo ""
    echo "💡 Next Steps:"
    if [ $CLUSTER_EXISTS -eq 1 ]; then
        echo "   - Wait for cluster deletion to complete"
    fi
    if [ $NODE_GROUP_EXISTS -eq 1 ]; then
        echo "   - Wait for node group deletion to complete"
    fi
    if [ "$ALB_COUNT" -gt 0 ]; then
        echo "   - ALBs should be cleaned up automatically"
    fi
    if [ -n "$BETECH_ROLES" ]; then
        echo "   - Consider manually removing remaining IAM roles"
    fi
    echo ""
    echo "   Run this script again in 5-10 minutes to check progress."
fi

echo ""
echo "=================================================="
