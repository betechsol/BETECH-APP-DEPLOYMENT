# Outputs for Helm Module

output "aws_load_balancer_controller_status" {
  description = "Status of AWS Load Balancer Controller Helm release"
  value       = helm_release.aws_load_balancer_controller.status
}

output "metrics_server_status" {
  description = "Status of Metrics Server Helm release"
  value       = helm_release.metrics_server.status
}

output "cluster_autoscaler_status" {
  description = "Status of Cluster Autoscaler Helm release"
  value       = helm_release.cluster_autoscaler.status
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of IAM role for Cluster Autoscaler"
  value       = aws_iam_role.cluster_autoscaler_role.arn
}

output "helm_releases" {
  description = "Map of Helm release names and their status"
  value = {
    aws_load_balancer_controller = helm_release.aws_load_balancer_controller.status
    metrics_server              = helm_release.metrics_server.status
    cluster_autoscaler          = helm_release.cluster_autoscaler.status
  }
}
