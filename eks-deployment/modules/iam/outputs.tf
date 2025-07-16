# Outputs for IAM Module

output "ebs_csi_driver_role_arn" {
  description = "ARN of IAM role for EBS CSI driver"
  value       = aws_iam_role.ebs_csi_driver_role.arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of IAM role for AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller_role.arn
}

output "ecr_access_role_arn" {
  description = "ARN of IAM role for ECR access"
  value       = aws_iam_role.ecr_access_role.arn
}

output "ebs_csi_driver_role_name" {
  description = "Name of IAM role for EBS CSI driver"
  value       = aws_iam_role.ebs_csi_driver_role.name
}

output "aws_load_balancer_controller_role_name" {
  description = "Name of IAM role for AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller_role.name
}

output "ecr_access_role_name" {
  description = "Name of IAM role for ECR access"
  value       = aws_iam_role.ecr_access_role.name
}
