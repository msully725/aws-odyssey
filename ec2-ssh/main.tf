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

# Fetch the latest Amazon Linux 2 AMI for the current region
data "aws_ami" "amazon_linux_2" {
    most_recent = true
    owners = ["amazon"]

    filter {
        name = "name"
        values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }
}

# Create a security group that allows SSH access
resource "aws_security_group" "allow_ssh" {
    vpc_id = aws_vpc.main_vpc.id

    ingress {
        description = "SSH from my IP"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["${var.my_ip}/32"] 
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "allow-ssh-sg"
    }
}

resource "aws_route_table" "public_route_table" {
    vpc_id = aws_vpc.main_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main_igw.id
    }

    tags = {
        Name = "public-route-table"
    }
}

resource "aws_route_table_association" "public_subnet_association" {
    subnet_id = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.public_route_table.id
}

# Create an EC2 instance in the Public Subnet
resource "aws_instance" "public_ec2" {
    ami = data.aws_ami.amazon_linux_2.id
    instance_type = "t2.micro"
    subnet_id = aws_subnet.public_subnet.id
    associate_public_ip_address = true
    key_name = "aws-odyssey-key-pair"
    vpc_security_group_ids = [aws_security_group.allow_ssh.id]

    tags = {
        Name = "terraform-public-ec2"
    }
}
output "public_ec2_ip" {
    value = aws_instance.public_ec2.public_ip
}