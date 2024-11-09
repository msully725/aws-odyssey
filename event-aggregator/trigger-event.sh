#!/bin/bash

API_NAME="event-aggregator-api"
STAGE_NAME="dev"
AWS_REGION=$(aws configure get region)
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='$API_NAME'].id" --output text)

if [ -z "$API_ID" ]; then
    echo "Error: API Gateway with name $API_NAME not found!"
    exit 1
fi

API_ENDPOINT="https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/$STAGE_NAME/trigger-event"
RANDOM_VALUE=$(( ( RANDOM % 10 ) + 1 ))
EVENT_DATA="{\"message\":\"Test event data\", \"value\": $RANDOM_VALUE}"

echo "Triggering event to $API_ENDPOINT ..."
curl -X POST $API_ENDPOINT \
    -H "Content-Type: application/json" \
    -d "$EVENT_DATA"

echo ""
echo "Event triggered successfully"