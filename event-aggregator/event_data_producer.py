import json
import boto3
import uuid
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('event_aggregator_event_data')

def lambda_handler(event, context):
    event_id = str(uuid.uuid4())

    timestamp = str(datetime.now(datetime.timezone.utc))

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
