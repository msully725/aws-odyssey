#!/bin/bash

ROLE_NAME="api-gateway-cloudwatch-role"

echo "Retrieiving AWS Account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
if [ -z "$ACCOUNT_ID" ]; then
    echo "Error: unable to retrieve AWS Account ID"
    exit 1
fi

echo "AWS Account ID: $ACCOUNT_ID"
ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"
echo "Role ARN: $ROLE_ARN"

echo "Retrieving current CloudWatch Logs role ARN for API Gateway..."
CURRENT_ROLE_ARN=$(aws apigateway get-account --query 'cloudwatchRoleArn' --output text)
if [ "$CURRENT_ROLE_ARN" = "None" ]; then
  echo "No CloudWatch Logs role ARN set."
else
  echo "Current CloudWatch Logs role ARN: $CURRENT_ROLE_ARN"
fi

aws apigateway update-account --patch-operations op=replace,path=/cloudwatchRoleArn,value=$ROLE_ARN

UPDATED_ROLE_ARN=$(aws apigateway get-account --query 'cloudwatchRoleArn' --output text)
if [ "$UPDATED_ROLE_ARN" = "$ROLE_ARN" ]; then
  echo "CloudWatch Logs role ARN successfully updated to: $UPDATED_ROLE_ARN"
else
  echo "Failed to update CloudWatch Logs role ARN."
  exit 1
fi

echo "API Gateway logging role update complete!"