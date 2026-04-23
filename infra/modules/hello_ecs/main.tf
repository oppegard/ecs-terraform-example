locals {
  service_name         = "${var.environment}-${var.app_name}"
  container_name       = "app"
  log_group_name       = "/ecs/${local.service_name}"
  task_definition_path = "${path.root}/task-definitions/${var.app_name}.json"
  app_tags = merge(
    var.tags,
    {
      App = var.app_name
    },
  )
}

resource "aws_ecr_repository" "app" {
  name                 = "${var.environment}/${var.app_name}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.app_tags
}

resource "aws_cloudwatch_log_group" "app" {
  name              = local.log_group_name
  retention_in_days = 14

  tags = local.app_tags
}

resource "aws_security_group" "alb" {
  name        = "${local.service_name}-alb"
  description = "ALB ingress for ${local.service_name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.app_tags,
    {
      Name = "${local.service_name}-alb"
    },
  )
}

resource "aws_lb" "app" {
  name               = local.service_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  tags = local.app_tags
}

resource "aws_lb_target_group" "app" {
  name        = "${local.service_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    matcher             = "200"
  }

  tags = local.app_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

module "service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "5.12.1"

  cluster_arn                    = var.cluster_arn
  name                           = local.service_name
  family                         = local.service_name
  cpu                            = var.task_cpu
  memory                         = var.task_memory
  desired_count                  = var.desired_count
  launch_type                    = "FARGATE"
  assign_public_ip               = true
  subnet_ids                     = var.subnet_ids
  ignore_task_definition_changes = true

  create_task_exec_iam_role          = true
  task_exec_iam_role_name            = "${local.service_name}-exec"
  task_exec_iam_role_use_name_prefix = false
  create_tasks_iam_role              = true
  tasks_iam_role_name                = "${local.service_name}-task"
  tasks_iam_role_use_name_prefix     = false

  container_definitions = {
    "${local.container_name}" = {
      name      = local.container_name
      image     = var.bootstrap_image
      essential = true

      port_mappings = [
        {
          name          = local.container_name
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "APP_ENV"
          value = var.environment
        },
        {
          name  = "APP_NAME"
          value = var.app_name
        },
        {
          name  = "PORT"
          value = tostring(var.container_port)
        }
      ]

      log_configuration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = local.container_name
        }
      }
    }
  }

  load_balancer = {
    service = {
      target_group_arn = aws_lb_target_group.app.arn
      container_name   = local.container_name
      container_port   = var.container_port
    }
  }

  security_group_name            = "${local.service_name}-service"
  security_group_use_name_prefix = false
  security_group_description     = "ECS service access for ${local.service_name}"
  security_group_rules = {
    alb_ingress = {
      type                     = "ingress"
      from_port                = var.container_port
      to_port                  = var.container_port
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.alb.id
    }
    all_egress = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = local.app_tags
}

data "aws_iam_policy_document" "github_actions" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPushImage"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.app.arn]
  }

  statement {
    sid = "RegisterTaskDefinition"
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
    ]
    resources = ["*"]
  }

  statement {
    sid = "DeployService"
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService",
    ]
    resources = [module.service.id]
  }

  statement {
    sid     = "PassTaskRoles"
    actions = ["iam:PassRole"]
    resources = [
      module.service.task_exec_iam_role_arn,
      module.service.tasks_iam_role_arn,
    ]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${local.service_name}-deploy"
  role   = var.github_actions_role_name
  policy = data.aws_iam_policy_document.github_actions.json
}
