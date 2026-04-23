variable "aws_region" {
  description = "AWS region for the test environment."
  type        = string
}

variable "project_name" {
  description = "Base name used across resources."
  type        = string
  default     = "ecs-terraform-example"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "test"
}

variable "vpc_cidr" {
  description = "CIDR block for the environment VPC."
  type        = string
  default     = "10.30.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs for the environment."
  type        = list(string)
  default     = ["10.30.1.0/24", "10.30.2.0/24"]
}

variable "desired_count" {
  description = "Desired ECS task count."
  type        = number
  default     = 2
}

variable "task_cpu" {
  description = "Task CPU units."
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Task memory in MiB."
  type        = number
  default     = 1024
}

variable "container_port" {
  description = "Application container port."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "ALB health check path."
  type        = string
  default     = "/health"
}

variable "bootstrap_image" {
  description = "Image used by Terraform for the initial service task definition."
  type        = string
  default     = "public.ecr.aws/docker/library/python:3.12-slim"
}

variable "github_repository" {
  description = "GitHub repository in owner/name format for OIDC trust."
  type        = string
  default     = "YOUR_ORG/YOUR_REPO"
}

variable "github_main_branch" {
  description = "Git branch allowed to assume the deploy role."
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "Whether this environment should create the shared GitHub OIDC provider."
  type        = bool
  default     = false
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN when not creating it in this environment."
  type        = string
  default     = ""
}

variable "extra_tags" {
  description = "Additional tags applied to environment resources."
  type        = map(string)
  default     = {}
}
