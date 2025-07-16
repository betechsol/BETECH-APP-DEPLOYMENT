# Variables for IAM Module

variable "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
