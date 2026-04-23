# Infra Layout

The infra tree is intentionally small and split into two layers:

- shared environment infrastructure
- explicit per-app infrastructure

## Shared modules

- `modules/network`: minimal per-environment VPC with public subnets
- `modules/github_oidc`: GitHub Actions OIDC trust and deploy role creation
- `modules/ecs_environment`: composes `network`, the upstream ECS cluster
  submodule, and `github_oidc`

`ecs_environment` is the shared layer for an environment. It owns:

- VPC and public subnets
- ECS cluster
- shared GitHub Actions deploy role

It does not own app services or app-facing ingress.

## App modules

- `modules/hello_ecs`: the `hello-ecs` application module

`hello_ecs` owns:

- app ECR repository
- app ALB, target group, and listener
- app log group
- ECS service and task definition
- app-scoped deploy permissions on the shared environment deploy role
- baseline task-definition rendering for GitHub Actions

Future apps should follow this same pattern as sibling modules instead of
being folded into `ecs_environment`.

## Environment roots

- `environments/dev`
- `environments/test`

Each environment root now does four things:

1. sets provider configuration
2. defines environment-specific values
3. instantiates `ecs_environment`
4. instantiates `hello_ecs`

The roots should stay thin. If a future change is shared across apps in one
environment, it belongs in `ecs_environment`. If it belongs to one app, it
belongs in that app module.

## Task definition files

Each environment contains checked-in per-app task definition artifacts under:

- `infra/environments/dev/task-definitions/hello-ecs.json`
- `infra/environments/test/task-definitions/hello-ecs.json`

The baseline template now lives in:

- `infra/modules/hello_ecs/task-definition.json.tftpl`

Refresh the checked-in artifact after infra changes with:

```bash
./scripts/export-task-def.sh dev hello-ecs
./scripts/export-task-def.sh test hello-ecs
```

## OIDC provider bootstrap

The GitHub OIDC provider is shared per AWS account, but the deploy role is
separate per environment.

Recommended pattern:

- create the provider once from `dev`
- reuse the resulting provider ARN in `test`

That keeps the environment roots independent while avoiding duplicate
account-global provider resources.
