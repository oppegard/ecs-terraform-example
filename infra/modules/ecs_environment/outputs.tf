output "cluster_name" {
  description = "ECS cluster name for the environment."
  value       = local.cluster_name
}

output "cluster_arn" {
  description = "ECS cluster ARN for the environment."
  value       = null
}

output "vpc_id" {
  description = "VPC ID for the environment."
  value       = null
}

output "public_subnet_ids" {
  description = "Public subnet IDs for the environment."
  value       = []
}

output "github_actions_role_name" {
  description = "GitHub Actions deploy role name for the environment."
  value       = "${var.environment}-github"
}

output "github_actions_role_arn" {
  description = "GitHub Actions deploy role ARN for the environment."
  value       = null
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN for the environment."
  value       = var.github_oidc_provider_arn
}

output "tags" {
  description = "Environment-level tags."
  value       = local.common_tags
}
