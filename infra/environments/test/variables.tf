variable "aws_region" {
  description = "AWS region for the test environment."
  type        = string
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

variable "hello_ecs" {
  description = "Configuration for the hello-ecs app in test."
  type = object({
    bootstrap_image   = string
    desired_count     = number
    task_cpu          = number
    task_memory       = number
    container_port    = number
    health_check_path = string
  })
  default = {
    bootstrap_image   = "public.ecr.aws/docker/library/python:3.12-slim"
    desired_count     = 2
    task_cpu          = 512
    task_memory       = 1024
    container_port    = 8080
    health_check_path = "/health"
  }
}

variable "extra_tags" {
  description = "Additional tags applied to environment resources."
  type        = map(string)
  default     = {}
}
