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

# Create VPC
resource "aws_vpc" "main_vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = {
        Name = "terraform-eks-fargate-vpc"
    }
}

output "vpc_id" {
    value = aws_vpc.main_vpc.id
}

output "aws_account_id" {
    value = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}