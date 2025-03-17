#!/bin/bash

FUNCTION_NAME=$(aws cloudformation describe-stacks \
  --stack-name SftpBackupStack \
  --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionArn`].OutputValue' \
  --output text)

if [ -z "$FUNCTION_NAME" ]; then
    echo "Error: Could not find Lambda function ARN in stack outputs"
    exit 1
fi

# Invoke the Lambda function
aws lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --payload '{"test": "event"}' \
  --cli-binary-format raw-in-base64-out \
  /dev/stdout 