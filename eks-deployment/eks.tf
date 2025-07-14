#BETECH-APP-DEPLOYMENT/terraform/eks.tf
# EKS Cluster Configuration

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  control_plane_subnet_ids        = module.vpc.private_subnets
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  # Cluster security group
  cluster_security_group_additional_rules = {
    ingress_nodes_443 = {
      description                = "Node groups to cluster API"
      protocol                   = "tcp"
      from_port                  = 443
      to_port                    = 443
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Node security group - empty to avoid conflicts with existing rules
  node_security_group_additional_rules = {}

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    betech_nodes = {
      name = "betech-node-group"

      instance_types = var.node_group_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_group_min_capacity
      max_size     = var.node_group_max_capacity
      desired_size = var.node_group_desired_capacity

      # Use the latest EKS Optimized AMI
      ami_type = "AL2_x86_64"

      # Enable IMDSv2
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "disabled"
      }

      # Node group configuration
      disk_size = 50

      # Taints
      taints = []

      # Labels
      labels = {
        Environment = var.environment
        NodeGroup   = "betech-nodes"
      }

      tags = merge(local.common_tags, {
        Name = "betech-node-group"
      })
    }
  }

  # EKS Add-ons
  cluster_addons = {
    coredns = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = aws_iam_role.ebs_csi_driver_role.arn
    }
  }

  #   # Cluster access entries
  #   enable_cluster_creator_admin_permissions = true

  #   tags = merge(local.common_tags, {
  #     Name = local.cluster_name
  #   })
}

# # Configure Kubernetes provider
# provider "kubernetes" {
#   host                   = module.eks.cluster_endpoint
#   cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
#   token                  = data.aws_eks_cluster_auth.cluster.token
# }

# provider "helm" {
#   kubernetes {
#     host                   = module.eks.cluster_endpoint
#     cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
#     token                  = data.aws_eks_cluster_auth.cluster.token
#   }
# }

# data "aws_eks_cluster_auth" "cluster" {
#   name = module.eks.cluster_name
# }