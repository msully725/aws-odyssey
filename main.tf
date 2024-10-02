provider "aws" {
    region = "us-east-1"
}

terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
      }
    }

    required_version = ">= 1.0.0"
}

output "aws_account_id" {
    value = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}