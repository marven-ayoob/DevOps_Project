# Variables Terraform 7
variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "my-app"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "docker_image_path" {
  description = "Path to your local Docker image (directory containing Dockerfile)"
  type        = string
  default     = "."
}

# Generate unique version number (UNIX timestamp)
locals {
  image_version = formatdate("YYYYMMDDhhmmss", timestamp())
}

# Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ECR Repository
resource "aws_ecr_repository" "app_repo" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECR Repository Policy
resource "aws_ecr_repository_policy" "app_repo_policy" {
  repository = aws_ecr_repository.app_repo.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPull"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
      }
    ]
  })
}

# Build and push versioned Docker image
resource "null_resource" "docker_build_push" {
  triggers = {
    dockerfile_hash = filemd5("${var.docker_image_path}/Dockerfile")
    version_trigger = local.image_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Login to ECR
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.app_repo.repository_url}
      
      # Build the image with version tag
      docker build -t ${var.app_name}:${local.image_version} ${var.docker_image_path}
      
      # Tag the image (versioned and latest)
      docker tag ${var.app_name}:${local.image_version} ${aws_ecr_repository.app_repo.repository_url}:${local.image_version}
      docker tag ${var.app_name}:${local.image_version} ${aws_ecr_repository.app_repo.repository_url}:latest
      
      # Push both tags
      docker push ${aws_ecr_repository.app_repo.repository_url}:${local.image_version}
      docker push ${aws_ecr_repository.app_repo.repository_url}:latest
    EOT
  }

  depends_on = [aws_ecr_repository.app_repo]
}

# Default VPC and Subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group
resource "aws_security_group" "ecs_sg" {
  name_prefix = "${var.app_name}-ecs-"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-ecs-sg"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = var.app_name
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.app_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = var.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = var.app_name
      image = "${aws_ecr_repository.app_repo.repository_url}:${local.image_version}"
      
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  depends_on = [null_resource.docker_build_push]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 7
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = var.app_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  force_new_deployment = true

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  deployment_controller {
    type = "ECS"
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  depends_on = [aws_ecs_task_definition.app]
}

# Outputs
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app_repo.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "docker_image_version" {
  description = "Version tag used for Docker image"
  value       = local.image_version
}
