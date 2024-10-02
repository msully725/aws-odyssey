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

# Create Public Subnet
resource "aws_subnet" "public_subnet" {
    vpc_id = aws_vpc.main_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true

    tags = {
        Name = "terraform-public-subnet"
    }
}
output "public_subnet_id" {
    value = aws_subnet.public_subnet.id
}

# Create Private Subnet
resource "aws_subnet" "private_subnet" {
    vpc_id = aws_vpc.main_vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = false

    tags = {
        Name = "terraform-private-subnet"
    }
}
output "private_subnet_id" {
    value = aws_subnet.private_subnet.id
}

# Create Internet Gateway
resource "aws_internet_gateway" "main_igw" {
    vpc_id = aws_vpc.main_vpc.id

    tags = { 
        Name = "terraform-main-igw"
    }
}
output "internet_gateway_id" {
    value = aws_internet_gateway.main_igw.id
}