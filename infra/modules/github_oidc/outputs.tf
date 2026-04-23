output "role_arn" {
  description = "IAM role ARN for GitHub Actions."
  value       = aws_iam_role.github_actions.arn
}

output "role_name" {
  description = "IAM role name for GitHub Actions."
  value       = aws_iam_role.github_actions.name
}

output "oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN."
  value       = local.oidc_provider_arn
}
