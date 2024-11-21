import boto3
import os
import time
from datetime import datetime, timedelta

dynamodb = boto3.resource("dynamodb")
table_name = os.getenv("DYNAMODB_TABLE_NAME")
table = dynamodb.Table(table_name)

def process_records():
    print(f"Scanning for entities to process")

    now = datetime.utcnow()
    cutoff = now - timedelta(minutes=1)
    cutoff_timestamp = cutoff.isoformat()

    # Scan for items older than 1 minute
    response = table.scan(
        FilterExpression="LastEventTime < :cutoff",
        ExpressionAttributeValues={":cutoff": cutoff_timestamp}
    )
    for item in response.get("Items", []):
        entity_id = item["EntityId"]
        # Process the entity here
        print(f"Processing entity {entity_id}")

        # Delete the item after processing
        table.delete_item(Key={"EntityId": entity_id})

if __name__ == "__main__":
    print(f"Starting entity change processor")
    while True:
        process_records()
        time.sleep(10)  # Poll every 10 seconds