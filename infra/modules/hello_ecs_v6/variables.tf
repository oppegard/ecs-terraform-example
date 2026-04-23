variable "aws_region" {
  description = "AWS region for the application deployment."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "app_name" {
  description = "Logical application name."
  type        = string
}

variable "bootstrap_image" {
  description = "Image used by Terraform for the initial service task definition."
  type        = string
}

variable "desired_count" {
  description = "Desired ECS task count."
  type        = number
}

variable "task_cpu" {
  description = "Task CPU units."
  type        = number
}

variable "task_memory" {
  description = "Task memory in MiB."
  type        = number
}

variable "container_port" {
  description = "Application container port."
  type        = number
}

variable "health_check_path" {
  description = "ALB health check path."
  type        = string
}

variable "cluster_name" {
  description = "Target ECS cluster name."
  type        = string
}

variable "cluster_arn" {
  description = "Target ECS cluster ARN."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the application."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the application service."
  type        = list(string)
}

variable "github_actions_role_name" {
  description = "Shared GitHub Actions deploy role name for the environment."
  type        = string
}

variable "tags" {
  description = "Environment-level tags to extend."
  type        = map(string)
  default     = {}
}
