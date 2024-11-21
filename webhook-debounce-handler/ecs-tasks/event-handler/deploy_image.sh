#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables (update these as needed)
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
ECR_REPO_NAME="webhook-event-handler-repo"
IMAGE_TAG="latest"

# Full ECR repository URI
ECR_REPO_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG}"

echo "### Step 1: Authenticate Docker to ECR ###"
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "### Step 2: Build the Docker image ###"
docker build -t "${ECR_REPO_NAME}" .

echo "### Step 3: Tag the Docker image ###"
docker tag "${ECR_REPO_NAME}:latest" "${ECR_REPO_URI}"

echo "### Step 4: Push the Docker image to ECR ###"
docker push "${ECR_REPO_URI}"

echo "### Deployment Complete ###"
echo "Image pushed to ECR: ${ECR_REPO_URI}"