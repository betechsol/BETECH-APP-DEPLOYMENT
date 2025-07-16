# Outputs for ECR Module

output "frontend_repository_url" {
  description = "URL of the frontend ECR repository"
  value       = aws_ecr_repository.betech_frontend.repository_url
}

output "backend_repository_url" {
  description = "URL of the backend ECR repository"
  value       = aws_ecr_repository.betech_backend.repository_url
}

output "postgres_repository_url" {
  description = "URL of the postgres ECR repository"
  value       = aws_ecr_repository.betech_postgres.repository_url
}

output "frontend_repository_arn" {
  description = "ARN of the frontend ECR repository"
  value       = aws_ecr_repository.betech_frontend.arn
}

output "backend_repository_arn" {
  description = "ARN of the backend ECR repository"
  value       = aws_ecr_repository.betech_backend.arn
}

output "postgres_repository_arn" {
  description = "ARN of the postgres ECR repository"
  value       = aws_ecr_repository.betech_postgres.arn
}

output "repository_urls" {
  description = "Map of repository names to URLs"
  value = {
    frontend = aws_ecr_repository.betech_frontend.repository_url
    backend  = aws_ecr_repository.betech_backend.repository_url
    postgres = aws_ecr_repository.betech_postgres.repository_url
  }
}
