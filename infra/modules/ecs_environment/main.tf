locals {
  cluster_name = "${var.environment}-cluster"
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.extra_tags,
  )

  github_role_name = "${var.environment}-github"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "network" {
  source = "../network"

  name                = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = slice(data.aws_availability_zones.available.names, 0, length(var.public_subnet_cidrs))
  public_subnet_cidrs = var.public_subnet_cidrs
  tags                = local.common_tags
}

module "cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "6.12.0"

  region = var.aws_region
  name   = local.cluster_name
  tags   = local.common_tags
}

module "github_actions_deploy" {
  source = "../github_oidc"

  role_name            = local.github_role_name
  github_repository    = var.github_repository
  allowed_subjects     = ["repo:${var.github_repository}:ref:refs/heads/${var.github_main_branch}"]
  create_oidc_provider = var.create_github_oidc_provider
  oidc_provider_arn    = var.github_oidc_provider_arn
  create_inline_policy = false
  tags                 = local.common_tags
}
