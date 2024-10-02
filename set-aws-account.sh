#!/bin/bash

# Set the AWS profile
export AWS_PROFILE=sdc-aws-odyssey

# Verify the active account
account_info=$(aws sts get-caller-identity)

echo "You are now using the following account:"
echo $account_info