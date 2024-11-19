resource "aws_iam_role" "api_gateway_cloudwatch_role" {
    name = "api-gateway-cloudwatch-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Principal = {
                    Service = "apigateway.amazonaws.com"
                },
                Action = "sts:AssumeRole"
            }
        ]

    })
}

resource "aws_iam_role_policy_attachment" "api_gateway_logging_policy" {
    role = aws_iam_role.api_gateway_cloudwatch_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "api_gateway_account" {
    cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn
}