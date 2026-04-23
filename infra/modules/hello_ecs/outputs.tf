output "service_name" {
  description = "ECS service name for the app."
  value       = local.service_name
}

output "task_definition_family" {
  description = "Task definition family for the app."
  value       = local.service_name
}

output "task_definition_json" {
  description = "Baseline task definition JSON used by GitHub Actions."
  value       = null
}

output "task_definition_file_path" {
  description = "Repo-local path where the baseline task definition should be exported."
  value       = local.task_definition_path
}

output "ecr_repository_name" {
  description = "ECR repository name for the app."
  value       = "${var.environment}/${var.app_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL for the app."
  value       = null
}

output "alb_dns_name" {
  description = "ALB DNS name for the app."
  value       = null
}

output "alb_url" {
  description = "Convenience HTTP URL for the app."
  value       = null
}
