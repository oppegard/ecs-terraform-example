locals {
  service_name         = "${var.environment}-${var.app_name}"
  task_definition_path = "${path.root}/task-definitions/${var.app_name}.json"
  app_tags = merge(
    var.tags,
    {
      App = var.app_name
    },
  )
}
