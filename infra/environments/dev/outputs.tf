locals {
  baseline_task_definition = templatefile("${path.module}/task-definition.json.tftpl", {
    task_family        = local.task_family
    task_cpu           = tostring(var.task_cpu)
    task_memory        = tostring(var.task_memory)
    execution_role_arn = module.ecs.services[local.service_name].task_exec_iam_role_arn
    task_role_arn      = module.ecs.services[local.service_name].tasks_iam_role_arn
    container_name     = local.container_name
    container_image    = var.bootstrap_image
    container_port     = var.container_port
    environment_name   = local.environment_name
    project_name       = var.project_name
    log_group_name     = aws_cloudwatch_log_group.app.name
    aws_region         = var.aws_region
    log_stream_prefix  = local.container_name
  })
}

output "alb_dns_name" {
  description = "ALB DNS name for the dev service."
  value       = aws_lb.app.dns_name
}

output "alb_url" {
  description = "Convenience HTTP URL for the dev service."
  value       = "http://${aws_lb.app.dns_name}"
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.cluster_name
}

output "service_name" {
  description = "ECS service name."
  value       = module.ecs.services[local.service_name].name
}

output "task_definition_family" {
  description = "Task definition family."
  value       = module.ecs.services[local.service_name].task_definition_family
}

output "task_definition_json" {
  description = "Baseline task definition JSON used by GitHub Actions."
  value       = local.baseline_task_definition
}

output "task_definition_file_path" {
  description = "Repo-local path where the baseline task definition should be exported."
  value       = "${path.module}/task-definition.json"
}

output "ecr_repository_name" {
  description = "ECR repository name."
  value       = aws_ecr_repository.app.name
}

output "ecr_repository_url" {
  description = "ECR repository URL."
  value       = aws_ecr_repository.app.repository_url
}
