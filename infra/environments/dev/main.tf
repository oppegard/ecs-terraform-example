provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  environment_name = var.environment
  name_prefix      = "${var.project_name}-${local.environment_name}"
  cluster_name     = "${local.name_prefix}-cluster"
  service_name     = "${local.name_prefix}-service"
  container_name   = "app"
  task_family      = "${local.name_prefix}-task"
  ecr_name         = "${var.project_name}/${local.environment_name}"
  log_group_name   = "/ecs/${local.name_prefix}"
  default_tags = merge(
    {
      Project     = var.project_name
      Environment = local.environment_name
      ManagedBy   = "terraform"
    },
    var.extra_tags,
  )
}

module "network" {
  source = "../../modules/network"

  name                = local.name_prefix
  vpc_cidr            = var.vpc_cidr
  availability_zones  = slice(data.aws_availability_zones.available.names, 0, length(var.public_subnet_cidrs))
  public_subnet_cidrs = var.public_subnet_cidrs
  tags                = local.default_tags
}

resource "aws_ecr_repository" "app" {
  name                 = local.ecr_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.default_tags
}

resource "aws_cloudwatch_log_group" "app" {
  name              = local.log_group_name
  retention_in_days = 14

  tags = local.default_tags
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb"
  description = "ALB ingress for ${local.environment_name}"
  vpc_id      = module.network.vpc_id

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
    local.default_tags,
    {
      Name = "${local.name_prefix}-alb"
    },
  )
}

resource "aws_lb" "app" {
  name               = substr(replace(local.name_prefix, "/[^a-zA-Z0-9-]/", "-"), 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.network.public_subnet_ids

  tags = local.default_tags
}

resource "aws_lb_target_group" "app" {
  name        = substr(replace("${local.environment_name}-tg", "/[^a-zA-Z0-9-]/", "-"), 0, 32)
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.network.vpc_id

  health_check {
    enabled             = true
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    matcher             = "200"
  }

  tags = local.default_tags
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

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.12.1"

  cluster_name = local.cluster_name

  services = {
    "${local.service_name}" = {
      name                           = local.service_name
      family                         = local.task_family
      cpu                            = var.task_cpu
      memory                         = var.task_memory
      desired_count                  = var.desired_count
      launch_type                    = "FARGATE"
      assign_public_ip               = true
      subnet_ids                     = module.network.public_subnet_ids
      ignore_task_definition_changes = true

      create_task_exec_iam_role          = true
      task_exec_iam_role_name            = "${local.name_prefix}-exec"
      task_exec_iam_role_use_name_prefix = false
      create_tasks_iam_role              = true
      tasks_iam_role_name                = "${local.name_prefix}-task"
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
              value = local.environment_name
            },
            {
              name  = "APP_NAME"
              value = var.project_name
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

      security_group_name            = "${local.name_prefix}-service"
      security_group_use_name_prefix = false
      security_group_description     = "ECS service access for ${local.environment_name}"
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

      tags = local.default_tags
    }
  }

  tags = local.default_tags
}
