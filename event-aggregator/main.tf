provider "aws" {
    region = "us-east-1"
}

# DynamoDb
resource "aws_dynamodb_table" "event_data_table" {
    name = "event-aggregator-event-data"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "EventID"

    attribute {
      name = "EventID"
      type = "S"
    }

    tags = {
        Name = "event-aggregator-event-data"
        Application = "EventAggregator"
    }
}

resource "aws_dynamodb_table" "summaries_table" {
    name = "event-aggregator-summaries"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "SummaryID"

    attribute {
      name = "SummaryID"
      type = "S"
    }

    tags = {
        Name = "event-aggregator-summaries"
        Application = "EventAggregator"
    }
}

# Data Producer Lambda
resource "aws_iam_role" "lambda_exec_role" {
    name = "event_aggregator_lambda_role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "lambda.amazonaws.com"
            }
        }]
    })
}

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
    name = "lambda-dynamodb-policy"
    role = aws_iam_role.lambda_exec_role.id

    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Action = [ "dynamodb:PutItem"]
                Effect = "Allow"
                Resource = aws_dynamodb_table.event_data_table.arn
            }
        ]
    })
}

resource "aws_lambda_function" "data_producer_lambda" {
    function_name = "event_aggregator_data_producer"
    handler = "event_data_producer.lambda_handler"
    runtime = "python3.8"
    role = aws_iam_role.lambda_exec_role.arn
    filename = "event_data_producer.zip"
}

# API Gateway
