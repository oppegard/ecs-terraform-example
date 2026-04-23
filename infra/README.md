# Infra Layout

The infra tree is intentionally small.

## Shared modules

- `modules/network`: minimal per-environment VPC with public subnets
- `modules/github_oidc`: GitHub Actions OIDC trust and deploy role

These modules are narrow on purpose. They reduce repetition without hiding
the ECS example behind a platform abstraction.

## Environment roots

- `environments/dev`
- `environments/test`

Each environment root does three main things:

1. creates its own network, ALB, ECR repository, and log group
2. calls `terraform-aws-modules/ecs/aws` `v5.12.1` directly
3. renders a baseline task definition JSON string from
   `task-definition.json.tftpl`

The ECS module invocation is intentionally in the environment root so a
reader can see the real module usage immediately.

## Task definition files

Each environment contains:

- `task-definition.json.tftpl`: Terraform template for the baseline shape
- `task-definition.json`: checked-in artifact used by GitHub Actions

Refresh `task-definition.json` after infra changes with:

```bash
./scripts/export-task-def.sh dev
./scripts/export-task-def.sh test
```

## OIDC provider bootstrap

The GitHub OIDC provider is shared per AWS account, but deploy roles are
separate per environment.

Recommended pattern:

- create the provider once from `dev`
- reuse the resulting provider ARN in `test`

That keeps the environment roots independent while avoiding duplicate
account-global provider resources.
