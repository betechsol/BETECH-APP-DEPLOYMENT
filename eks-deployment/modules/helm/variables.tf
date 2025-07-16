# Variables for Helm Module

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster is located"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  type        = string
}

variable "aws_load_balancer_controller_role_arn" {
  description = "ARN of IAM role for AWS Load Balancer Controller"
  type        = string
}

variable "alb_controller_version" {
  description = "Version of AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.13.3"
}

variable "metrics_server_version" {
  description = "Version of Metrics Server Helm chart"
  type        = string
  default     = "3.12.2"
}

variable "cluster_autoscaler_version" {
  description = "Version of Cluster Autoscaler Helm chart"
  type        = string
  default     = "9.48.0"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
