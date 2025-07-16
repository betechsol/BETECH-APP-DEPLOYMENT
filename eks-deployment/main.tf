# BETECH EKS Cluster Terraform Configuration
# Account ID: 374965156099
# Region: us-west-2

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Local variables
locals {
  cluster_name = "betech-eks-cluster"
  account_id   = data.aws_caller_identity.current.account_id

  common_tags = {
    Environment = var.environment
    Project     = "BETECH"
    ManagedBy   = "Terraform"
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  cluster_name           = local.cluster_name
  vpc_cidr              = var.vpc_cidr
  private_subnets       = var.private_subnets
  public_subnets        = var.public_subnets
  enable_nat_gateway    = var.enable_nat_gateway
  single_nat_gateway    = var.single_nat_gateway
  enable_vpn_gateway    = var.enable_vpn_gateway
  enable_dns_hostnames  = var.enable_dns_hostnames
  enable_dns_support    = var.enable_dns_support
  common_tags           = local.common_tags
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  cluster_name                      = local.cluster_name
  cluster_version                   = var.cluster_version
  vpc_id                           = module.vpc.vpc_id
  private_subnet_ids               = module.vpc.private_subnets
  cluster_endpoint_private_access  = true
  cluster_endpoint_public_access   = true
  node_group_instance_types        = var.node_group_instance_types
  node_group_desired_capacity      = var.node_group_desired_capacity
  node_group_max_capacity          = var.node_group_max_capacity
  node_group_min_capacity          = var.node_group_min_capacity
  node_group_disk_size             = 50
  environment                      = var.environment
  common_tags                      = local.common_tags

  depends_on = [module.vpc]
}

# IAM Module (created after EKS to use OIDC outputs)
module "iam" {
  source = "./modules/iam"

  oidc_provider_arn        = module.eks.oidc_provider_arn
  cluster_oidc_issuer_url  = module.eks.cluster_oidc_issuer_url
  common_tags              = local.common_tags

  depends_on = [module.eks]
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"

  image_tag_mutability = "MUTABLE"
  scan_on_push        = true
  common_tags         = local.common_tags
}

# Helm Module - Temporarily commented out due to authentication issues
# Deploy Helm charts manually after cluster is accessible
# module "helm" {
#   source = "./modules/helm"
#
#   cluster_name                           = local.cluster_name
#   aws_region                            = var.aws_region
#   vpc_id                                = module.vpc.vpc_id
#   oidc_provider_arn                     = module.eks.oidc_provider_arn
#   cluster_oidc_issuer_url               = module.eks.cluster_oidc_issuer_url
#   aws_load_balancer_controller_role_arn = module.iam.aws_load_balancer_controller_role_arn
#   common_tags                           = local.common_tags
#
#   depends_on = [module.eks, module.iam]
# }