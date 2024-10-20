import json
import boto3
import uuid
from datetime import datetime, timezone

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('event-aggregator-event-data')

def lambda_handler(event, context):
    event_id = str(uuid.uuid4())

    timestamp = str(datetime.now(timezone.utc))

    data = json.loads(event['body'])

    table.put_item(
        Item={
            'EventID': event_id,
            'Timestamp': timestamp,
            'Data': json.dumps(data)
        }
    )

    return {
        'statusCode': 200,
        'body': json.dumps(f'Event {event_id} created successfully!')
    }
