provider "aws" {
  region = var.aws_region
}

module "environment" {
  source = "../../modules/ecs_environment_v7"

  aws_region                  = var.aws_region
  environment                 = var.environment
  vpc_cidr                    = var.vpc_cidr
  public_subnet_cidrs         = var.public_subnet_cidrs
  github_repository           = var.github_repository
  github_main_branch          = var.github_main_branch
  create_github_oidc_provider = var.create_github_oidc_provider
  github_oidc_provider_arn    = var.github_oidc_provider_arn
  extra_tags                  = var.extra_tags
}

module "hello_ecs" {
  source = "../../modules/hello_ecs_v7"

  aws_region               = var.aws_region
  environment              = var.environment
  app_name                 = "hello-ecs"
  bootstrap_image          = var.hello_ecs.bootstrap_image
  desired_count            = var.hello_ecs.desired_count
  task_cpu                 = var.hello_ecs.task_cpu
  task_memory              = var.hello_ecs.task_memory
  container_port           = var.hello_ecs.container_port
  health_check_path        = var.hello_ecs.health_check_path
  cluster_name             = module.environment.cluster_name
  cluster_arn              = module.environment.cluster_arn
  vpc_id                   = module.environment.vpc_id
  subnet_ids               = module.environment.public_subnet_ids
  github_actions_role_name = module.environment.github_actions_role_name
  tags                     = module.environment.tags
}
