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