import boto3
import os
import time
import json
from datetime import datetime

# Fetch the SQS queue URL and DynamoDB table name from the environment
queue_url = os.getenv("SQS_QUEUE_URL")
if not queue_url:
    raise ValueError("Environment variable SQS_QUEUE_URL is not set")

dynamodb_table_name = os.getenv("DYNAMODB_TABLE_NAME")
if not dynamodb_table_name:
    raise ValueError("Environment variable DYNAMODB_TABLE_NAME is not set")

# Initialize AWS clients
sqs = boto3.client("sqs", region_name="us-east-1")
dynamodb = boto3.client("dynamodb", region_name="us-east-1")
cloudwatch = boto3.client("cloudwatch", region_name="us-east-1")

def process_messages():
    """
    Poll SQS and process messages indefinitely.
    """
    print(f"Starting message processor for queue: {queue_url}")
    while True:
        try:
            # Receive messages from the SQS queue
            response = sqs.receive_message(
                QueueUrl=queue_url,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=20  # Long polling
            )

            if "Messages" in response:
                for message in response["Messages"]:
                    print(f"Processing message: {message['Body']}")

                    handle_message(message["Body"])
                    publish_metric("WebhookEventsCount", 1)
                    cleanup_message(message["ReceiptHandle"])

                    print(f"Message processed: {message['MessageId']}")
            else:
                print("No messages received. Waiting for more...")

        except Exception as e:
            print(f"Error processing messages: {e}")
            time.sleep(5)  # Pause briefly before retrying

def handle_message(message_body):
    """
    Process the message and store/update it in DynamoDB.
    """
    try:
        message = json.loads(message_body)
        entity_id = message.get("Id")
        if not entity_id:
            raise ValueError("Message does not contain 'Id'")

        current_time = datetime.utcnow().isoformat()

        dynamodb.put_item(
            TableName=dynamodb_table_name,
            Item={
                "EntityId": {"S": entity_id},
                "LastEventTime": {"S": current_time}
            }
        )
        print(f"Stored EntityId: {entity_id} with timestamp: {current_time}")

    except Exception as e:
        print(f"Error handling message: {e}")

def cleanup_message(receiptHandle):
    sqs.delete_message(
        QueueUrl=queue_url,
        ReceiptHandle=receiptHandle
    )

def publish_metric(metric_name, value):
    """
    Publish custom metrics to CloudWatch.
    """
    try:
        cloudwatch.put_metric_data(
            Namespace="EntityProcessor",
            MetricData=[
                {
                    "MetricName": metric_name,
                    "Value": value,
                    "Unit": "Count"
                }
            ]
        )
    except Exception as e:
        print(f"Failed to publish metric {metric_name}: {e}")

if __name__ == "__main__":
    process_messages()