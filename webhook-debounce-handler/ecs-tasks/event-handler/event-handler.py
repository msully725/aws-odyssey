import boto3
import os
import time

# Fetch the SQS queue URL from the environment
queue_url = os.getenv("SQS_QUEUE_URL")
if not queue_url:
    raise ValueError("Environment variable SQS_QUEUE_URL is not set")

# Initialize SQS client
sqs = boto3.client("sqs", region_name="us-east-1")

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

                    # Process the message (custom logic goes here)
                    # Example: Print the message body
                    handle_message(message["Body"])

                    # Delete the message from the queue after processing
                    sqs.delete_message(
                        QueueUrl=queue_url,
                        ReceiptHandle=message["ReceiptHandle"]
                    )
                    print(f"Message deleted: {message['MessageId']}")
            else:
                print("No messages received. Waiting for more...")

        except Exception as e:
            print(f"Error processing messages: {e}")
            time.sleep(5)  # Pause briefly before retrying

def handle_message(message_body):
    """
    Placeholder for custom message processing logic.
    Replace this function with your business logic.
    """
    print(f"Handling message: {message_body}")

if __name__ == "__main__":
    process_messages()