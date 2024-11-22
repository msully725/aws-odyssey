import boto3
import os
import time
from datetime import datetime, timedelta

dynamodb = boto3.resource("dynamodb")
table_name = os.getenv("DYNAMODB_TABLE_NAME")
table = dynamodb.Table(table_name)

cloudwatch = boto3.client("cloudwatch", region_name="us-east-1")

def process_records():
    print(f"Scanning for entities to process")

    now = datetime.utcnow()
    debounce_cutoff = now - timedelta(seconds=15)
    continuous_cutoff = now - timedelta(minutes=1)

    # Scan for items that meet the debounce or continuous processing thresholds
    response = table.scan(
        FilterExpression="LastEventTime < :debounce OR LastProcessedTime < :continuous",
        ExpressionAttributeValues={
            ":debounce": debounce_cutoff.isoformat(),
            ":continuous": continuous_cutoff.isoformat()
        }
    )

    for item in response.get("Items", []):
        entity_id = item["EntityId"]
        # Process the entity here
        print(f"Processing entity {entity_id}")

        # Update the last processed time instead of deleting the record
        table.update_item(
            Key={"EntityId": entity_id},
            UpdateExpression="SET LastProcessedTime = :now",
            ExpressionAttributeValues={":now": now.isoformat()}
        )

        publish_metric("ProcessedCount", 1)

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
    print(f"Starting entity change processor")
    while True:
        process_records()
        time.sleep(10)  # Poll every 10 seconds