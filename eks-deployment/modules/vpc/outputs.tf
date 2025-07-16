# Outputs for VPC Module

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = module.vpc.igw_id
}

output "cluster_security_group_id" {
  description = "Security group ID for EKS cluster"
  value       = aws_security_group.cluster_sg.id
}

output "azs" {
  description = "List of availability zones"
  value       = data.aws_availability_zones.available.names
}
