# Define the region variable
variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"  # Change this to your preferred region
}

provider "aws" {
    region = var.region
}

# API Gateway
resource "aws_api_gateway_rest_api" "webhook_event_handler_api" {
    name = "webhook-event-handler-api"
}

resource "aws_api_gateway_resource" "webhook" {
    rest_api_id = aws_api_gateway_rest_api.webhook_event_handler_api.id
    parent_id = aws_api_gateway_rest_api.webhook_event_handler_api.root_resource_id
    path_part = "webhook"
}

resource "aws_api_gateway_method" "post_webhook" {
    rest_api_id = aws_api_gateway_rest_api.webhook_event_handler_api.id
    resource_id = aws_api_gateway_resource.webhook.id
    http_method = "POST"
    authorization = "NONE"
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
    name = "/aws/apigateway/webhook-event-handler"
}

resource "aws_api_gateway_deployment" "webhook_api_deployment" {
    rest_api_id = aws_api_gateway_rest_api.webhook_event_handler_api.id
}

resource "aws_api_gateway_stage" "webhook_stage" {
    deployment_id = aws_api_gateway_deployment.webhook_api_deployment.id
    rest_api_id = aws_api_gateway_rest_api.webhook_event_handler_api.id
    stage_name = "dev"

    access_log_settings {
        destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
        format          = "requestId: $context.requestId, status: $context.status, error: $context.error.message"
    }
}

resource "aws_api_gateway_method_settings" "webhook_method_settings" {
    rest_api_id = aws_api_gateway_rest_api.webhook_event_handler_api.id
    stage_name = aws_api_gateway_stage.webhook_stage.stage_name

    method_path = "*/*"

    settings {
        metrics_enabled = true
        logging_level = "INFO"
        data_trace_enabled = true
    }
}

# MOCK Integration for POST Method
resource "aws_api_gateway_integration" "mock_integration" {
  rest_api_id             = aws_api_gateway_rest_api.webhook_event_handler_api.id
  resource_id             = aws_api_gateway_resource.webhook.id
  http_method             = aws_api_gateway_method.post_webhook.http_method
  type                    = "MOCK"
  integration_http_method = "POST"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# SQS
resource "aws_sqs_queue" "webhook_event_queue" {
    name = "webhook-event-queue"

    visibility_timeout_seconds = 300 # 5 minutes
    message_retention_seconds = 86400 # 1 day
}

# API Gateway to SQS Integration
resource "aws_iam_policy" "api_gateway_sqs_policy" {
    name = "api-gateway-sqs-policy"
    description = "API Gateway policy to enqueue in SQS"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sqs:SendMessage"
                Effect = "Allow"
                Resource = aws_sqs_queue.webhook_event_queue.arn
            }
        ]
    })
}

resource "aws_iam_role" "api_gateway_role" {
    name = "api-gateway-sqs-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "apigateway.amazonaws.com"
                }
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "api_gateway_sqs_policy_attachment" {
    role = aws_iam_role.api_gateway_role.name
    policy_arn = aws_iam_policy.api_gateway_sqs_policy.arn
}
