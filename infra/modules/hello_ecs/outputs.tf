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
  value = templatefile("${path.module}/task-definition.json.tftpl", {
    task_family        = local.service_name
    task_cpu           = tostring(var.task_cpu)
    task_memory        = tostring(var.task_memory)
    execution_role_arn = module.service.task_exec_iam_role_arn
    task_role_arn      = module.service.tasks_iam_role_arn
    container_name     = local.container_name
    container_image    = var.bootstrap_image
    container_port     = var.container_port
    environment_name   = var.environment
    app_name           = var.app_name
    log_group_name     = aws_cloudwatch_log_group.app.name
    aws_region         = var.aws_region
    log_stream_prefix  = local.container_name
  })
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
  value       = aws_ecr_repository.app.repository_url
}

output "alb_dns_name" {
  description = "ALB DNS name for the app."
  value       = aws_lb.app.dns_name
}

output "alb_url" {
  description = "Convenience HTTP URL for the app."
  value       = "http://${aws_lb.app.dns_name}"
}
