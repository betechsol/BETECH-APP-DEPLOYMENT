#!/bin/bash

# Fix Cluster Autoscaler IAM Permissions

echo "🔧 Fixing Cluster Autoscaler IAM permissions..."

# Get the node group role name
NODE_GROUP_ROLE_NAME="betech-node-group-eks-node-group-20250713223323474900000002"

# Create IAM policy for cluster autoscaler
cat > /tmp/cluster-autoscaler-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": "*"
        }
    ]
}
EOF

echo "📄 Creating IAM policy for cluster autoscaler..."
aws iam create-policy \
    --policy-name ClusterAutoscalerPolicy \
    --policy-document file:///tmp/cluster-autoscaler-policy.json \
    --description "Policy for EKS Cluster Autoscaler" \
    || echo "Policy might already exist, continuing..."

echo "🔗 Attaching policy to node group role..."
aws iam attach-role-policy \
    --role-name ${NODE_GROUP_ROLE_NAME} \
    --policy-arn arn:aws:iam::374965156099:policy/ClusterAutoscalerPolicy

echo "✅ Verifying attached policies..."
aws iam list-attached-role-policies --role-name ${NODE_GROUP_ROLE_NAME}

echo "🔄 Restarting cluster autoscaler deployment..."
kubectl -n kube-system rollout restart deployment/cluster-autoscaler-aws-cluster-autoscaler

echo "⏳ Waiting for cluster autoscaler to restart..."
kubectl -n kube-system rollout status deployment/cluster-autoscaler-aws-cluster-autoscaler --timeout=120s

echo "🔍 Checking cluster autoscaler pod status..."
kubectl -n kube-system get pods -l "app.kubernetes.io/name=aws-cluster-autoscaler"

echo "📋 Checking cluster autoscaler logs..."
kubectl -n kube-system logs -l "app.kubernetes.io/name=aws-cluster-autoscaler" --tail=20

echo "✅ Cluster Autoscaler permissions fix completed!"
