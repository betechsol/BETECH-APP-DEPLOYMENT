# ECR Repositories for BETECH Application

resource "aws_ecr_repository" "betech_frontend" {
  name                 = "betech-frontend"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = merge(var.common_tags, {
    Name        = "betech-frontend"
    Application = "frontend"
  })
}

resource "aws_ecr_repository" "betech_backend" {
  name                 = "betech-backend"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = merge(var.common_tags, {
    Name        = "betech-backend"
    Application = "backend"
  })
}

resource "aws_ecr_repository" "betech_postgres" {
  name                 = "betech-postgres"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = merge(var.common_tags, {
    Name        = "betech-postgres"
    Application = "database"
  })
}