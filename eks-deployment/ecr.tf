resource "aws_ecr_repository" "betech_frontend" {
  name = "betech-frontend"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "betech_backend" {
  name = "betech-backend"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "betech_postgres" {
  name = "betech-postgres"

  image_scanning_configuration {
    scan_on_push = true
  }
}