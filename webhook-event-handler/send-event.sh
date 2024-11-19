#!/bin/bash

# Check if a message parameter is provided
if [ -z "$1" ]; then
  echo "Usage: $0 '<message_payload>'"
  echo "Example: $0 '{\"id\":1, \"payload\":\"updated\"}'"
  exit 1
fi

# Set the message payload from the first argument
MESSAGE_PAYLOAD=$1

# API Gateway URL
API_URL="https://9qhepjnfgc.execute-api.us-east-1.amazonaws.com/dev/webhook"

# Make the API request
curl -X POST $API_URL \
-d "$MESSAGE_PAYLOAD" \
-H "Content-Type: application/json"