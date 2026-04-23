variable "aws_region" {
  description = "AWS region for the environment."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the environment VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs for the environment."
  type        = list(string)
}

variable "github_repository" {
  description = "GitHub repository in owner/name format for OIDC trust."
  type        = string
}

variable "github_main_branch" {
  description = "Git branch allowed to assume the deploy role."
  type        = string
}

variable "create_github_oidc_provider" {
  description = "Whether this environment should create the shared GitHub OIDC provider."
  type        = bool
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN when not creating it in this environment."
  type        = string
}

variable "extra_tags" {
  description = "Additional tags applied to environment resources."
  type        = map(string)
  default     = {}
}
