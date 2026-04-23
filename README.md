# ECS + Terraform + GitHub Actions Example

This repository is a small reference implementation for running `hello-ecs`
in `dev` and `test` while keeping infrastructure ownership separate from
image rollout ownership.

The current layout is intentionally DRY without becoming generic platform
code:

- `infra/modules/ecs_environment` owns the shared per-environment layer
- `infra/modules/hello_ecs` owns the `hello-ecs` application layer
- each environment root explicitly composes those two modules

## What Terraform owns

Terraform creates and manages:

- the VPC, public subnets, and internet gateway for each environment
- the ECS cluster for each environment
- the shared GitHub Actions deploy role for each environment
- the `hello-ecs` ECR repository, ALB, target group, listener, and log group
- the `hello-ecs` ECS service, task definition family, and task IAM roles
- the baseline task-definition JSON shape used by GitHub Actions

## What GitHub Actions owns

GitHub Actions handles routine releases:

- build the application image
- run minimal CI checks
- push the image to the environment-specific ECR repository
- render the checked-in task definition JSON with the new image URI
- register and deploy the new task definition revision to ECS

That is why image rollout is not done through Terraform here. Pushing a new
application version should not require editing Terraform variables and
running `terraform apply`.

## Module split

### `infra/modules/ecs_environment`

This module owns the per-environment shared layer:

- `infra/modules/network`
- `terraform-aws-modules/ecs/aws//modules/cluster` pinned to `v7.5.0`
- `infra/modules/github_oidc`

It outputs the shared values that app modules consume:

- cluster name and ARN
- VPC ID and subnet IDs
- shared GitHub Actions deploy role name and ARN
- shared tags

### `infra/modules/hello_ecs`

This module owns the `hello-ecs` application that runs on the shared cluster:

- `terraform-aws-modules/ecs/aws//modules/service` pinned to `v7.5.0`
- the app ECR repository
- the app ALB, target group, and listener
- the app log group
- the app-specific deploy policy attached to the shared deploy role
- the baseline task-definition template and rendered JSON output

Future apps should be added as sibling app modules and instantiated
explicitly in each environment root. Do not turn the repo into a generic
“apps map” framework yet.

## Environment parameterization

The two environment roots are intentionally thin. Their primary job is to
set environment values and instantiate modules.

| Setting | `dev` | `test` |
| --- | --- | --- |
| Environment name | `dev` | `test` |
| Desired count | `1` | `2` |
| Task CPU | `256` | `512` |
| Task memory | `512` | `1024` |
| VPC CIDR | `10.20.0.0/16` | `10.30.0.0/16` |
| Public subnets | `10.20.1.0/24`, `10.20.2.0/24` | `10.30.1.0/24`, `10.30.2.0/24` |
| Cluster name | `dev-cluster` | `test-cluster` |
| Service name | `dev-hello-ecs` | `test-hello-ecs` |
| ECR repository | `dev/hello-ecs` | `test/hello-ecs` |

The app-specific settings are grouped under `hello_ecs` in each
`terraform.tfvars.example`.

## Repo layout

```text
.
├── .github/workflows/
├── app/
├── infra/
│   ├── environments/
│   └── modules/
│       ├── ecs_environment/
│       ├── github_oidc/
│       ├── hello_ecs/
│       └── network/
├── scripts/
├── Makefile
├── PLAN (DRY).md
└── README.md
```

`infra/README.md` explains the infra layout in more detail.

## Prerequisites

- Terraform `>= 1.5.7`
- AWS credentials with permission to create the demo resources
- Docker for local image builds
- a GitHub repository with Actions enabled

The environment roots and wrapper modules pin the AWS provider to the `6.x`
line so local `terraform validate` aligns with the ECS module version in use.
The upstream v7 cluster module also pulls in `hashicorp/time`.

## Bootstrap AWS + GitHub OIDC

The deploy trust is branch-based. By default each environment trusts:

- `repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main`

Update `github_repository` and, if needed, `github_main_branch` in each
environment’s `terraform.tfvars`.

The GitHub OIDC provider is account-global, so create it exactly once:

1. In `infra/environments/dev/terraform.tfvars`, set
   `create_github_oidc_provider = true`
2. Apply `dev`
3. Copy the resulting `github_oidc_provider_arn` output
4. In `infra/environments/test/terraform.tfvars`, set
   `create_github_oidc_provider = false`
   and `github_oidc_provider_arn = "<that arn>"`

## First deployment with Terraform

Start with `dev`:

1. Copy `infra/environments/dev/terraform.tfvars.example` to
   `infra/environments/dev/terraform.tfvars`
2. Fill in `aws_region`, `github_repository`, and any environment-specific
   values
3. Run:

   ```bash
   terraform -chdir=infra/environments/dev init
   terraform -chdir=infra/environments/dev apply
   ```

4. Export the checked-in task definition artifact:

   ```bash
   ./scripts/export-task-def.sh dev hello-ecs
   ```

5. Commit the refreshed
   `infra/environments/dev/task-definitions/hello-ecs.json`

Repeat the same pattern for `test`.

Useful outputs after apply include:

- `alb_url`
- `ecr_repository_url`
- `cluster_name`
- `service_name`
- `github_actions_role_arn`

## GitHub Actions setup

Create two GitHub environments:

- `dev`
- `test`

For each environment, set these GitHub Actions variables:

- `AWS_ROLE_ARN`
- `AWS_REGION`

The workflow derives the rest from the environment and app name:

- cluster: `${environment}-cluster`
- service: `${environment}-${app_name}`
- ECR repository: `${environment}/${app_name}`
- task definition path:
  `infra/environments/${environment}/task-definitions/${app_name}.json`

## Later app-only deploys

After the first Terraform apply, routine app releases do not need Terraform.

- pushing to `main` deploys `dev` + `hello-ecs`
- `workflow_dispatch` can target `dev` or `test`
- `workflow_dispatch` also takes `app_name`, currently defaulted to
  `hello-ecs`

The deploy workflow:

1. assumes the environment-specific AWS role via OIDC
2. builds and pushes a new image to the right ECR repository
3. renders the checked-in task definition JSON with the new image URI
4. registers the new task definition revision
5. updates the ECS service and waits for stability

The deployed image uses the commit SHA tag. The workflow also pushes an
environment convenience tag like `dev-hello-ecs-latest`, but deployment
itself uses the SHA-tagged image.

## Task definition ownership and drift

This repo intentionally uses:

- Terraform to create the baseline task definition family and service shape
- GitHub Actions to register later task definition revisions for releases

To keep Terraform from constantly reverting image-only deploys, the app
service configuration keeps `ignore_task_definition_changes = true` and
`track_latest = false`.

Tradeoff:

- normal CI/CD releases can move quickly without `terraform apply`
- Terraform may temporarily tolerate task-definition revision drift between
  infra applies

When the task definition structure changes:

1. Update `infra/modules/hello_ecs/task-definition.json.tftpl`
2. Apply the Terraform change
3. Run `./scripts/export-task-def.sh <environment> hello-ecs`
4. Commit the refreshed
   `infra/environments/<environment>/task-definitions/hello-ecs.json`

That keeps the checked-in task definition aligned with the actual shape that
GitHub Actions deploys.

## Adding another app later

To add a second app, follow the same pattern as `hello-ecs`:

1. create a new app module under `infra/modules/`
2. instantiate it explicitly in both environment roots
3. add the app name to the deploy workflow if you want manual selection
4. add a checked-in task definition artifact for that app in each environment

`infra/modules/ecs_environment` should not need to change for a normal new
app addition.

## Local commands

```bash
make fmt
make validate
make app-smoke
make docker-build
make export-task-def-dev
make export-task-def-test
```

`make validate` only runs local Terraform initialization and validation. It
does not run `plan` or `apply`.

## Phase commits

This DRY refactor is intended to be implemented as explicit phases, with a
git commit created after each completed phase. See [PLAN (DRY).md](PLAN%20(DRY).md).

## Known limitations

- The demo VPC uses only public subnets to keep the example small.
- There is one app module today: `hello-ecs`.
- There is one primary container per app.
- There is no autoscaling, service discovery, WAF, blue/green deploy, or
  multi-account setup.
- The checked-in task-definition artifacts are starter files until you
  refresh them from Terraform outputs after bootstrap.
- The sample app is intentionally tiny and uses Python’s standard library.
