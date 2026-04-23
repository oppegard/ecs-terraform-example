# PLAN (DRY).md

## Summary

Refactor the duplicated `dev` and `test` Terraform roots into an explicit composition model with two new modules:

- `infra/modules/ecs_environment` for per-environment shared infrastructure
- `infra/modules/hello_ecs` for the `hello-ecs` application that runs on an environment’s ECS cluster

Keep the environment roots explicit: each root should instantiate one shared environment module and one `hello_ecs` app module. The structure should make it straightforward to add future apps as additional explicit app modules per environment.

As each implementation phase is completed, create a git commit for that phase before moving to the next one.

## Implementation Changes

### Shared environment module

Create `infra/modules/ecs_environment`.

It should own:

- VPC and public subnets, by calling the existing `infra/modules/network`
- ECS cluster only, using `terraform-aws-modules/ecs/aws//modules/cluster` pinned to `v5.12.1`
- GitHub OIDC provider/role trust, by calling the existing `infra/modules/github_oidc`
- the per-environment GitHub deploy role
- environment-level naming and tags

It should not own:

- ECR repositories
- ALBs, listeners, target groups
- CloudWatch log groups for app containers
- ECS services or task definitions
- app-specific deploy permissions

### `hello-ecs` app module

Create `infra/modules/hello_ecs`.

It should own:

- one ECR repository for `hello-ecs` in each environment
- one ALB, listener, and target group for `hello-ecs` in each environment
- one CloudWatch log group for `hello-ecs`
- one ECS service and task definition for `hello-ecs`, using `terraform-aws-modules/ecs/aws//modules/service` pinned to `v5.12.1`
- the app task execution role and task role
- app-scoped IAM policy attachment on the environment GitHub deploy role so CI can push this app’s image and deploy this app’s service
- the baseline task-definition template and rendered JSON output for GitHub Actions

This module should stay app-specific. Future apps should be added as sibling app modules, not by turning `hello_ecs` into a generic platform abstraction now.

### Environment roots

Refactor `infra/environments/dev` and `infra/environments/test` so they contain only:

- provider config
- environment-local values
- one `module "environment"` call to `infra/modules/ecs_environment`
- one `module "hello_ecs"` call to `infra/modules/hello_ecs`
- thin pass-through outputs

Group app settings as a single `hello_ecs` object per environment instead of separate top-level variables for CPU, memory, desired count, port, image, and health check path.

Use explicit app module instantiation in each root. Do not add a higher-level “apps map” orchestration layer.

### Naming and file layout

Use naming based only on `environment` and `app_name`.

For `hello-ecs`, standardize on:

- cluster: `${environment}-cluster`
- service: `${environment}-hello-ecs`
- task family: `${environment}-hello-ecs`
- ECR repository: `${environment}/hello-ecs`
- log group: `/ecs/${environment}-hello-ecs`

Move checked-in task-definition artifacts to:

- `infra/environments/dev/task-definitions/hello-ecs.json`
- `infra/environments/test/task-definitions/hello-ecs.json`

Keep the Terraform template in the app module:

- `infra/modules/hello_ecs/task-definition.json.tftpl`

Update `scripts/export-task-def.sh` to accept:

- `./scripts/export-task-def.sh <environment> <app_name>`

Initially support only `hello-ecs`.

### Workflows and docs

Update `deploy.yml` so it is future-app compatible:

- add `app_name` input, defaulting to `hello-ecs`
- keep `push` to `main` deploying `dev` + `hello-ecs`
- keep manual dispatch for `dev` or `test`
- derive task-definition path and deploy target values from `target_environment` and `app_name`
- stop relying on app-specific GitHub environment variables like `ECR_REPOSITORY` and `ECS_SERVICE` when they can be derived deterministically

Keep `ci.yml` lean:

- continue compiling and smoke-testing the sample app from `app/`
- continue building the container from `app/`
- continue local-only Terraform init/validate for both environments

Update `README.md` and `infra/README.md` to explain:

- the shared-env/app module split
- how `hello-ecs` uses the shared cluster
- how to add a future app module
- how task-definition export works with `<environment> <app_name>`
- that every implementation phase should be committed as it is completed

## Explicit Phases

### Phase 1: establish the new module boundaries

- create `infra/modules/ecs_environment`
- create `infra/modules/hello_ecs`
- move duplicated locals/inputs/outputs design into those modules without changing behavior yet
- define the module input/output contracts clearly enough that env roots become thin wrappers

Commit after completion:
- `refactor: phase 1 introduce dry modules`

### Phase 2: move shared environment infrastructure

- move shared per-environment logic out of `dev` and `test` into `ecs_environment`
- keep the existing `network` and `github_oidc` modules as helpers underneath `ecs_environment`
- move ECS cluster creation into `ecs_environment`
- keep app service resources out of this module

Commit after completion:
- `refactor: phase 2 extract ecs environment`

### Phase 3: move `hello-ecs` app infrastructure

- move ECR, ALB, target group, listener, log group, ECS service, task-definition logic, and app deploy permissions into `hello_ecs`
- switch service creation to `terraform-aws-modules/ecs/aws//modules/service` pinned to `v5.12.1`
- keep `ignore_task_definition_changes = true`
- centralize the app task-definition template in the module

Commit after completion:
- `refactor: phase 3 extract hello ecs app`

### Phase 4: simplify `dev` and `test`

- reduce each environment root to provider config, env-specific values, module calls, and pass-through outputs
- replace duplicated per-env scalar app variables with a grouped `hello_ecs` object
- preserve the current `dev` vs `test` behavioral differences through input values only

Commit after completion:
- `refactor: phase 4 simplify env roots`

### Phase 5: task-definition artifact flow

- move checked-in task-definition files to `task-definitions/hello-ecs.json`
- update outputs so the app module emits the baseline task-definition JSON and file path
- update `scripts/export-task-def.sh` to require environment and app name
- keep the checked-in JSON flow explicit for GitHub Actions

Commit after completion:
- `refactor: phase 5 update task def flow`

### Phase 6: workflow refactor

- update `deploy.yml` to work with explicit app names, defaulting to `hello-ecs`
- derive deploy target values from environment and app name where possible
- keep CI behavior the same other than path updates caused by the refactor

Commit after completion:
- `refactor: phase 6 update workflows`

### Phase 7: documentation and cleanup

- update repo docs to explain the new structure and future-app model
- document how to add another app module to each environment
- document the new task-definition export command
- document that implementation should be committed phase-by-phase

Commit after completion:
- `docs: phase 7 document dry layout`

## Interfaces

### `infra/modules/ecs_environment`

Inputs:

- `aws_region`
- `environment`
- `vpc_cidr`
- `public_subnet_cidrs`
- `github_repository`
- `github_main_branch`
- `create_github_oidc_provider`
- `github_oidc_provider_arn`
- `extra_tags`

Outputs:

- `cluster_name`
- `cluster_arn`
- `vpc_id`
- `public_subnet_ids`
- `github_actions_role_name`
- `github_actions_role_arn`
- `github_oidc_provider_arn`
- `tags`

### `infra/modules/hello_ecs`

Inputs:

- `aws_region`
- `environment`
- `app_name`
- `bootstrap_image`
- `desired_count`
- `task_cpu`
- `task_memory`
- `container_port`
- `health_check_path`
- `cluster_name`
- `cluster_arn`
- `vpc_id`
- `subnet_ids`
- `github_actions_role_name`
- `tags`

Outputs:

- `service_name`
- `task_definition_family`
- `task_definition_json`
- `task_definition_file_path`
- `ecr_repository_name`
- `ecr_repository_url`
- `alb_dns_name`
- `alb_url`

## Test Plan

- `terraform fmt -check -recursive` passes after the refactor.
- `terraform -chdir=infra/environments/dev init -backend=false && terraform validate` passes.
- `terraform -chdir=infra/environments/test init -backend=false && terraform validate` passes.
- `bash -n scripts/export-task-def.sh` passes.
- Exported task-definition files for both environments are valid JSON and land under `task-definitions/hello-ecs.json`.
- Workflow YAML still parses cleanly.
- Existing app smoke test still passes from `app/`.
- Manual inspection confirms the env roots are small and differ mainly in values, not resource definitions.
- Adding a second app should require:
  - creating a new app module
  - instantiating that module once in each environment root
  - optionally adding the new app choice to `deploy.yml`
  - no changes to `ecs_environment`

## Assumptions and Defaults

- The sample app source stays in `app/` for now; only the deployed logical app name is `hello-ecs`.
- Each app owns its own ALB, target group, ECR repository, log group, and ECS service within an environment.
- The GitHub OIDC provider remains account-global and is still created once, then reused.
- The environment GitHub deploy role is shared per environment; app modules attach app-scoped deploy permissions to that role.
- The existing `network` and `github_oidc` modules remain as implementation helpers underneath `ecs_environment`.
- `ignore_task_definition_changes = true` remains part of the app service design so GitHub Actions continues to own image roll-forward without Terraform immediately reverting it.
