# Backend setup
terraform {
  backend "s3" {
    key = "vpc.tfstate"
  }
}

# Provider and access setup
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~>2.0"
    }
  }
}

provider "aws" {
  region = var.region
}
