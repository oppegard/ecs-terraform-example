output "alb_dns_name" {
  description = "ALB DNS name for the test service."
  value       = module.hello_ecs.alb_dns_name
}

output "alb_url" {
  description = "Convenience HTTP URL for the test service."
  value       = module.hello_ecs.alb_url
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = module.environment.cluster_name
}

output "service_name" {
  description = "ECS service name."
  value       = module.hello_ecs.service_name
}

output "task_definition_family" {
  description = "Task definition family."
  value       = module.hello_ecs.task_definition_family
}

output "task_definition_json" {
  description = "Baseline task definition JSON used by GitHub Actions."
  value       = module.hello_ecs.task_definition_json
}

output "task_definition_file_path" {
  description = "Repo-local path where the baseline task definition should be exported."
  value       = module.hello_ecs.task_definition_file_path
}

output "ecr_repository_name" {
  description = "ECR repository name."
  value       = module.hello_ecs.ecr_repository_name
}

output "ecr_repository_url" {
  description = "ECR repository URL."
  value       = module.hello_ecs.ecr_repository_url
}

output "github_actions_role_arn" {
  description = "GitHub Actions deploy role ARN for the test environment."
  value       = module.environment.github_actions_role_arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN used by this environment."
  value       = module.environment.github_oidc_provider_arn
}
