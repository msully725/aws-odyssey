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

