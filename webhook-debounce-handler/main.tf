# Define the region variable
variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"  # Change this to your preferred region
}

provider "aws" {
    region = var.region
}

data "aws_caller_identity" "current" {}

# API Gateway
resource "aws_api_gateway_rest_api" "webhook_event_handler_api" {
    name = "webhook-event-handler-api"
    endpoint_configuration {
        types = ["REGIONAL"]
    }
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
     depends_on = [
        aws_api_gateway_method.post_webhook,
        aws_api_gateway_integration.sqs_integration
    ]

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

resource "aws_api_gateway_method_response" "webhook_method_response" {
    depends_on = [ aws_api_gateway_method.post_webhook ]

    rest_api_id = aws_api_gateway_rest_api.webhook_event_handler_api.id
    resource_id = aws_api_gateway_resource.webhook.id
    http_method = aws_api_gateway_method.post_webhook.http_method
    status_code = 200

    response_models = {
      "application/json" = "Empty"
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

# resource "aws_iam_role_policy_attachment" "sqs_full_access" {
#   role       = aws_iam_role.api_gateway_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
# }

# API Gateway to SQS Integration
resource "aws_api_gateway_integration" "sqs_integration" {
    rest_api_id = aws_api_gateway_rest_api.webhook_event_handler_api.id
    resource_id = aws_api_gateway_resource.webhook.id
    http_method = aws_api_gateway_method.post_webhook.http_method
    type = "AWS"

    integration_http_method = "POST"

    request_parameters = {
        "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'" 
    }
    
    uri = "arn:aws:apigateway:${var.region}:sqs:path/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.webhook_event_queue.name}"

    credentials = aws_iam_role.api_gateway_role.arn

    request_templates = {
      "application/json" = "Action=SendMessage&MessageBody=$input.body"
    }
}

resource "aws_api_gateway_integration_response" "sqs_200_response" {
  depends_on = [ aws_api_gateway_integration.sqs_integration ]

  rest_api_id  = aws_api_gateway_rest_api.webhook_event_handler_api.id
  resource_id  = aws_api_gateway_resource.webhook.id
  http_method  = aws_api_gateway_method.post_webhook.http_method
  status_code  = "200"

  response_templates = {
    "application/json" = "{\"message\": \"Message successfully enqueued\"}"
  }
}

# VPC (for ECS)
resource "aws_vpc" "webhook_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "webhook-vpc"
  }
}

# Tasks Public Subnet
resource "aws_internet_gateway" "webhook_igw" {
  vpc_id = aws_vpc.webhook_vpc.id
}

resource "aws_route_table" "webhook_public_route_table" {
  vpc_id = aws_vpc.webhook_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.webhook_igw.id
  }
}

resource "aws_subnet" "webhook_public_subnet" {
    vpc_id                  = aws_vpc.webhook_vpc.id
    cidr_block              = "10.0.1.0/24"
    map_public_ip_on_launch = true

    tags = {
        Name = "webhook-public-subnet"
    }
}

resource "aws_route_table_association" "public_subnet_association" {
    subnet_id      = aws_subnet.webhook_public_subnet.id
    route_table_id = aws_route_table.webhook_public_route_table.id
}

resource "aws_security_group" "ecs_task_sg" {
  name   = "ecs-task-sg"
  vpc_id = aws_vpc.webhook_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS 
resource "aws_ecs_cluster" "webhook_event_handler_cluster" {
  name = "webhook-event-handler-cluster"
}

resource "aws_ecr_repository" "webhook_event_handler_repo" {
  name = "webhook-event-handler-repo"
}
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "ecs_task_log_group" {
  name = "/ecs/webhook-event-handler-task"
  retention_in_days = 7  # Optional, set to your desired retention period
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  name   = "ecs-task-policy"
  role   = aws_iam_role.ecs_task_role.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sqs:ReceiveMessage",
        Effect = "Allow",
        Resource = aws_sqs_queue.webhook_event_queue.arn
      },
      {
        Action = "sqs:DeleteMessage",
        Effect = "Allow",
        Resource = aws_sqs_queue.webhook_event_queue.arn
      },
      {
        Action = "sqs:GetQueueAttributes",
        Effect = "Allow",
        Resource = aws_sqs_queue.webhook_event_queue.arn
      }
    ]
  })
}

resource "aws_ecs_task_definition" "webhook_event_handler_task_definition" {
  family = "webhook-event-handler-task"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  memory = "512"
  cpu = "256"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name        = "event-handler",
      image       = "${aws_ecr_repository.webhook_event_handler_repo.repository_url}:latest",
      essential   = true,
      environment = [
        {
          name  = "SQS_QUEUE_URL",
          value = aws_sqs_queue.webhook_event_queue.url
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region = var.region
          awslogs-group = aws_cloudwatch_log_group.ecs_task_log_group.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  runtime_platform {
    cpu_architecture = "ARM64"
  }
}

resource "aws_ecs_service" "webhook_event_handler_service" {
  name = "webhook-event-handler-service"
  cluster = aws_ecs_cluster.webhook_event_handler_cluster.id
  task_definition = aws_ecs_task_definition.webhook_event_handler_task_definition.arn
  launch_type = "FARGATE"

  desired_count = 1

  network_configuration {
    subnets = aws_subnet.webhook_public_subnet[*].id
    security_groups = [aws_security_group.ecs_task_sg.id]
    assign_public_ip = true
  }
}

resource "aws_dynamodb_table" "entity_event_table" {
  name = "EntityEventTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "EntityId"

  attribute {
    name = "EntityId"
    type = "S"
  }

  tags = {
    Name = "EntityEventTable"
  }
}

resource "aws_iam_role_policy" "ecs_task_dynamodb_policy" {
  name = "ecs-task-dynamodb-policy"
  role = aws_iam_role.ecs_task_role.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynambodb:GetItem"
        ],
        Effect = "Allow",
        Resource = aws_dynamodb_table.entity_event_table.arn
      }
    ]
  })
}

# Outputs
output "api_gateway_deployed_url" {
  description = "The URL of the deployed API Gateway"
  value       = "https://${aws_api_gateway_rest_api.webhook_event_handler_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.webhook_stage.stage_name}/webhook"
}