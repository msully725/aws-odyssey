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
resource "aws_api_gateway_rest_api" "event_api_gateway" {
    name = "event-aggregator-api"
    description = "API for the Event Aggregator"
}

resource "aws_api_gateway_resource" "trigger_event_resource" {
    rest_api_id = aws_api_gateway_rest_api.event_api_gateway.id
    parent_id = aws_api_gateway_rest_api.event_api_gateway.root_resource_id
    path_part = "trigger-event"
}

resource "aws_api_gateway_method" "post_trigger_event_method" {
    rest_api_id = aws_api_gateway_rest_api.event_api_gateway.id
    resource_id = aws_api_gateway_resource.trigger_event_resource.id
    http_method = "POST"
    authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
    rest_api_id = aws_api_gateway_rest_api.event_api_gateway.id
    resource_id = aws_api_gateway_resource.trigger_event_resource.id
    http_method = aws_api_gateway_method.post_trigger_event_method.http_method
    integration_http_method = "POST"
    type = "AWS_PROXY"
    uri = aws_lambda_function.data_producer_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "api_deployment" {
    depends_on = [ aws_api_gateway_integration.lambda_integration ]
    rest_api_id = aws_api_gateway_rest_api.event_api_gateway.id
    stage_name = "dev"
}

resource "aws_lambda_permission" "api_gateway_invoke" {
    statement_id = "AllowAPIGatewayInvoke"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.data_producer_lambda.function_name
    principal = "apigateway.amazonaws.com"
}