# ECS + Terraform + GitHub Actions Example

This repository is a small reference implementation for running one ECS
service in `dev` and `test` while keeping infrastructure ownership separate
from image rollout ownership.

## What Terraform owns

Terraform creates and manages:

- the VPC, public subnets, and internet gateway used by each environment
- the ECS cluster and ECS service
- the baseline ECS task definition family and IAM roles
- the ALB, target group, listener, and security groups
- the CloudWatch log group
- one ECR repository per environment
- one GitHub Actions deploy role per environment

## What GitHub Actions owns

GitHub Actions handles routine releases:

- build the application image
- run minimal CI checks
- push the image to the environment-specific ECR repository
- render a new ECS task definition JSON with the new image URI
- register and deploy the new task definition revision to the ECS service

This is why image rollout is not done through Terraform here. Pushing a new
application version should not require editing `.tfvars` and running
`terraform apply`.

## Why the upstream ECS module is used directly

Each environment root calls `terraform-aws-modules/ecs/aws` directly at
version `5.12.1`. There is no local ECS wrapper module. That keeps the
example readable and makes it obvious where ECS is configured.

Small local helper modules are used only where they remove noise:

- `infra/modules/network` for the minimal demo VPC
- `infra/modules/github_oidc` for GitHub Actions OIDC trust + role creation

## Environment parameterization

The two environment roots are intentionally similar, but their defaults are
different enough to show the pattern.

| Setting | `dev` | `test` |
| --- | --- | --- |
| Environment name | `dev` | `test` |
| Desired count | `1` | `2` |
| Task CPU | `256` | `512` |
| Task memory | `512` | `1024` |
| VPC CIDR | `10.20.0.0/16` | `10.30.0.0/16` |
| Public subnets | `10.20.1.0/24`, `10.20.2.0/24` | `10.30.1.0/24`, `10.30.2.0/24` |
| ECR repository | `ecs-terraform-example/dev` | `ecs-terraform-example/test` |

Shared structure lives in:

- `infra/modules/network`
- `infra/modules/github_oidc`

Environment-specific ECS usage lives in:

- `infra/environments/dev/main.tf`
- `infra/environments/test/main.tf`

## Repo layout

```text
.
├── .github/workflows/
├── app/
├── infra/
│   ├── modules/
│   └── environments/
├── scripts/
├── Makefile
└── README.md
```

`infra/README.md` explains the infra layout in a bit more detail.

## Prerequisites

- Terraform `>= 1.5.7`
- AWS credentials with permission to create the demo resources
- Docker for local image builds
- A GitHub repository where Actions is enabled

The Terraform config pins the AWS provider to the `5.x` line. This is
intentional so local `terraform validate` works cleanly with
`terraform-aws-modules/ecs/aws` `v5.12.1`.

## Bootstrap AWS + GitHub OIDC

The deploy trust in this repo is branch-based. By default each environment
trusts the GitHub OIDC subject:

- `repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main`

Update `github_repository` and, if needed, `github_main_branch` in each
environment's `terraform.tfvars`.

The GitHub OIDC provider is account-global, so create it exactly once:

1. In `infra/environments/dev/terraform.tfvars`, set:
   `create_github_oidc_provider = true`
2. Apply `dev`
3. Copy the resulting `github_oidc_provider_arn` output
4. In `infra/environments/test/terraform.tfvars`, set:
   `create_github_oidc_provider = false`
   and `github_oidc_provider_arn = "<that arn>"`

## First deployment with Terraform

Start with `dev`:

1. Copy `infra/environments/dev/terraform.tfvars.example` to
   `infra/environments/dev/terraform.tfvars`
2. Fill in `aws_region`, `github_repository`, and any naming overrides
3. Run:

   ```bash
   terraform -chdir=infra/environments/dev init
   terraform -chdir=infra/environments/dev apply
   ```

4. Export the repo-local task definition file:

   ```bash
   ./scripts/export-task-def.sh dev
   ```

5. Commit the refreshed `infra/environments/dev/task-definition.json`

Repeat the same pattern for `test` using
`infra/environments/test/terraform.tfvars.example`.

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
- `ECR_REPOSITORY`
- `ECS_CLUSTER`
- `ECS_SERVICE`

Suggested values come directly from Terraform outputs and the environment
configuration.

## Later app-only deploys

After the first Terraform apply, routine app releases do not need Terraform.

- Push to `main` to deploy to `dev`
- Use `workflow_dispatch` to deploy to `dev` or `test`

The deploy workflow:

1. assumes the environment-specific AWS role via OIDC
2. builds and pushes a new image to the right ECR repository
3. renders the checked-in task definition JSON with the new image URI
4. registers the new task definition revision
5. updates the ECS service and waits for stability

The deployed image uses the commit SHA tag. The workflow also pushes an
environment convenience tag like `dev-latest` or `test-latest`, but the
deployment itself uses the SHA-tagged image.

## Task definition ownership and drift

This repo intentionally uses:

- Terraform to create the baseline task definition family and service shape
- GitHub Actions to register later task definition revisions for releases

To keep Terraform from constantly reverting image-only deploys, the ECS
service configuration sets `ignore_task_definition_changes = true`.

Tradeoff:

- normal CI/CD releases can move quickly without `terraform apply`
- Terraform may temporarily tolerate task-definition revision drift between
  infra applies

When the task definition structure changes, do this:

1. Update `task-definition.json.tftpl` in the environment
2. Apply the Terraform change
3. Run `./scripts/export-task-def.sh <dev|test>`
4. Commit the refreshed `task-definition.json`

That keeps the checked-in task definition file aligned with the actual infra
shape that GitHub Actions deploys.

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

## Known limitations

- The demo VPC uses only public subnets to keep the example small.
- There is one service per environment and one primary container only.
- There is no autoscaling, service discovery, WAF, blue/green deploy, or
  multi-account setup.
- The checked-in `task-definition.json` files are starter artifacts until you
  refresh them from Terraform outputs after bootstrap.
- The sample app is intentionally tiny and uses Python's standard library.
