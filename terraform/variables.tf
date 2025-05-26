# variables.tf
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project - used for resource naming"
  type        = string
  default     = "devops-project"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "devops-project-repo"
}

variable "container_port" {
  description = "Port that the container exposes"
  type        = number
  default     = 80
}

variable "host_port" {
  description = "Port that the ALB listens on"
  type        = number
  default     = 8081
}

variable "fargate_cpu" {
  description = "CPU units for Fargate task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256
}

variable "fargate_memory" {
  description = "Memory for Fargate task (512, 1024, 2048, etc.)"
  type        = number
  default     = 512
}

variable "app_count" {
  description = "Number of Docker containers to run"
  type        = number
  default     = 1
}

variable "health_check_path" {
  description = "Health check path for the application"
  type        = string
  default     = "/"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}