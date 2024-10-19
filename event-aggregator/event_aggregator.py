import json
import boto3

dynamodb = boto3.resource('dynamodb')

summaries_table = dynamodb.Table('event-aggregator-summaries')

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))

    for record in event['Records']:
        if record['eventName'] != 'INSERT':
            continue

        new_event = record['dynamodb']['NewImage']
        event_id = new_event['EventID']['S']
        event_message = new_event['Data']['S']

        response = summaries_table.update_item(
            Key={'SummaryID': event_message},
            UpdateExpression="ADD Count :inc",
            ExpressionAttributeValues={':inc':1},
            ReturnValues="UPDATED_NEW"
        )

        print(f"Updated summary for {event_message}: {response['Attributes']}")

    return {
        'statusCode': 200,
        'body': json.dumps('Event aggregation completed successfully!')
    }
        