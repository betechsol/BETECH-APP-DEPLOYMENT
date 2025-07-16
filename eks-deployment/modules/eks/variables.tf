# Variables for EKS Module

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.27"
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "node_group_instance_types" {
  description = "EC2 instance types for node groups"
  type        = list(string)
  default     = ["t3.medium", "t3.large"]
}

variable "node_group_desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_group_max_capacity" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 10
}

variable "node_group_min_capacity" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_group_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 50
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}


