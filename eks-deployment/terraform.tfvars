# Terraform Variables for BETECH EKS Deployment

aws_region  = "us-west-2"
environment = "production"

# EKS Configuration
cluster_version = "1.27"

# Node Group Configuration
node_group_instance_types   = ["t3.medium", "t3.large"]
node_group_desired_capacity = 2
node_group_max_capacity     = 10
node_group_min_capacity     = 1

# VPC Configuration
vpc_cidr        = "10.0.0.0/16"
private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# NAT Gateway Configuration
enable_nat_gateway = true
single_nat_gateway = false

# DNS Configuration
enable_dns_hostnames = true
enable_dns_support   = true