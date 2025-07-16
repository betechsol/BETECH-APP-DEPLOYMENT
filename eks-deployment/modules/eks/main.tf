# EKS Cluster Configuration

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                          = var.vpc_id
  subnet_ids                      = var.private_subnet_ids
  control_plane_subnet_ids        = var.private_subnet_ids
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access

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
      disk_size = var.node_group_disk_size

      # Use managed policies
      iam_role_use_name_prefix = false
      iam_role_name           = "betech-node-group-role"
      
      # Taints
      taints = []

      # Labels
      labels = {
        Environment = var.environment
        NodeGroup   = "betech-nodes"
      }

      tags = merge(var.common_tags, {
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
  }

  tags = merge(var.common_tags, {
    Name = var.cluster_name
  })
}
