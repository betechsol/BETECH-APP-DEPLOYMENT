terraform {
  required_version = ">=0.12.0"
  backend "s3" {
    key            = "infra/terraformstatefile"
    bucket         = "betech-terraform-state-bucket"
    region         = "us-west-2"
    dynamodb_table = "betech-terraform-state-lock-table"
  }
  # Optional: Configure the provider to use a specific profile

  #   required_providers {
  #     aws = {
  #       source  = "hashicorp/aws"
  #       version = "~> 3.0"
  #     }
  #   }
}