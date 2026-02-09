terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# This configures the AWS Region
provider "aws" {
  region = var.aws_region
}