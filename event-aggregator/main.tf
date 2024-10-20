provider "aws" {
    region = "us-east-1"
}

# DynamoDb
resource "aws_dynamodb_table" "event_data_table" {
    name = "event-aggregator-event-data"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "EventID"
    stream_enabled = true
    stream_view_type = "NEW_IMAGE"

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
    name = "event-aggregator-lambda-role"

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
            # Access for trigger event lambda
            {
                Action = [ "dynamodb:PutItem"]
                Effect = "Allow"
                Resource = aws_dynamodb_table.event_data_table.arn
            },
            # Access for aggregator lambda to event data stream
            {
                Action = [
                    "dynamodb:GetRecords",
                    "dynamodb:GetShardIterator",
                    "dynamodb:DescribeStream",
                    "dynamodb:ListStreams"
                ],
                Effect = "Allow"
                Resource = aws_dynamodb_table.event_data_table.stream_arn
            },
            # Access for aggregator lambda to summaries table
            {
                Action = [ 
                    "dynamodb:PutItem",
                    "dynamodb:UpdateItem"
                ]
                Effect = "Allow"
                Resource = aws_dynamodb_table.summaries_table.arn
            }
        ]
    })
}

resource "aws_lambda_function" "data_producer_lambda" {
    function_name = "event-aggregator-data-producer"
    handler = "event_data_producer.lambda_handler"
    runtime = "python3.8"
    role = aws_iam_role.lambda_exec_role.arn
    filename = "event_data_producer.zip"
    source_code_hash = filebase64sha256("${path.module}/event_data_producer.zip")
}

# API Gateway
resource "aws_iam_role" "api_gateway_cloudwatch_role" {
    name = "api-gateway-cloudwatch-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "apigateway.amazonaws.com"
            }
        }]
    })
}

resource "aws_iam_role_policy_attachment" "api_gateway_logging_policy" {
    role = aws_iam_role.api_gateway_cloudwatch_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch_policy" {
    name = "api-gateway-cloudwatch-policy"
    role = aws_iam_role.api_gateway_cloudwatch_role.id

    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [{
            Effect = "Allow"
            Action = [
                "logs:CreateLogGroups",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
            ],
            Resource = "*"
        }]
    
    })
}

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

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
    name = "/aws/apigateway/event-aggregator-logs"
}

resource "aws_api_gateway_stage" "api_stage" {
    depends_on = [ aws_iam_role_policy_attachment.api_gateway_logging_policy ]
    stage_name = "dev"
    rest_api_id = aws_api_gateway_rest_api.event_api_gateway.id
    deployment_id = aws_api_gateway_deployment.api_deployment.id

    access_log_settings {
        destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
        format          = jsonencode({
            requestId       : "$context.requestId",
            ip              : "$context.identity.sourceIp",
            caller          : "$context.identity.caller",
            user            : "$context.identity.user",
            requestTime     : "$context.requestTime",
            httpMethod      : "$context.httpMethod",
            resourcePath    : "$context.resourcePath",
            status          : "$context.status",
            protocol        : "$context.protocol",
            responseLength  : "$context.responseLength"
        })
    }
}

resource "aws_api_gateway_method_settings" "api_method_settings" {
  rest_api_id = aws_api_gateway_rest_api.event_api_gateway.id
  stage_name  = aws_api_gateway_stage.api_stage.stage_name

  method_path  = "*/*"  # Apply to all resources and methods
  settings {
    logging_level     = "INFO"
    metrics_enabled   = true
    data_trace_enabled = true
  }
}

resource "aws_api_gateway_deployment" "api_deployment" {
    depends_on = [ aws_api_gateway_integration.lambda_integration ]
    rest_api_id = aws_api_gateway_rest_api.event_api_gateway.id
}

resource "aws_lambda_permission" "api_gateway_invoke" {
    statement_id = "AllowAPIGatewayInvoke"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.data_producer_lambda.function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_api_gateway_rest_api.event_api_gateway.execution_arn}/*/*"
}

# Event Aggregator Lambda
resource "aws_lambda_function" "event_aggregator_lambda" {
    function_name = "event-aggregator-lambda"
    handler = "event_aggregator.lambda_handler"
    runtime = "python3.8"
    role = aws_iam_role.lambda_exec_role.arn
    filename = "event_aggregator.zip"
    source_code_hash = filebase64sha256("${path.module}/event_aggregator.zip")

    environment {
      variables = {
        SUMMARIES_TABLE = aws_dynamodb_table.summaries_table.name
      }
    }
}

# resource "aws_lambda_event_source_mapping" "event_data_stream" {
#     event_source_arn = aws_dynamodb_table.event_data_table.stream_arn
#     function_name = aws_lambda_function.event_aggregator_lambda.function_name
#     starting_position = "LATEST"
# }