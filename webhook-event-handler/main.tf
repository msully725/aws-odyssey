provider "aws" {
    region = "us-east-1"
}

# API Gateway
resource "aws_apigatewayv2_api" "webhook_event_handler_api" {
    name = "webhook-event-handler-api"
    protocol_type = "HTTP"
}

resource "aws_apigatewayv2_route" "webhook-route" {
    api_id = aws_apigatewayv2_api.webhook_event_handler_api.id
    route_key = "POST /webhook"
}

resource "aws_apigatewayv2_stage" "default_stage" {
    api_id = aws_apigatewayv2_api.webhook_event_handler_api.id
    name = "dev"
    auto_deploy = true
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
