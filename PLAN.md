# PLAN.md

## Goal

Create a **minimal concrete repo layout** that cleanly separates:

- **Terraform** for long-lived AWS infrastructure
- **GitHub Actions** for application build and release
- **ECS** for running the service
- **ECR** for storing images

The implementation must use **terraform-aws-modules/terraform-aws-ecs/aws v5.12.1**. I want you to think about whether to directly import the module in environment code, or whether to create a small local wrapper module that is used per environment. What I care most about when you're making a decision: simplicity and long-term maintainability.

The repo must include **two environments**, `dev` and `test`, to demonstrate a sane way to parameterize ECS across environments without turning the example into a full platform framework.

## Non-goals

Do **not** build a full platform.

Do **not** use Terraform as the routine mechanism for shipping a new image.

Do **not** add blue/green, service discovery, autoscaling complexity, Cloud Map, WAF, multiple services, or multi-account patterns in v1.

Do **not** over-engineer reusable modules just to prove abstraction. This repo is primarily a reference implementation.

## Core design decision

Use this split:

- Terraform creates and manages:
  - ECS cluster
  - ECS service
  - task definition baseline
  - ECR repository
  - IAM roles and policies needed by ECS and GitHub Actions
  - networking attachments and ALB wiring, assuming VPC/subnets may be passed in or created minimally
- GitHub Actions handles:
  - build
  - test (minimal placeholder)
  - push image to ECR
  - render a new ECS task definition with the new image URI
  - deploy the new task definition to ECS service

This means **Terraform owns infrastructure shape**, while **CI/CD owns release velocity**.

## External references to follow

These are the implementation anchors. Use them directly instead of improvising.

1. **terraform-aws-modules ECS module, v5.12.1**  
   https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/v5.12.1

2. **GitHub Actions, deploy to Amazon ECS**  
   https://docs.github.com/actions/guides/deploying-to-amazon-elastic-container-service

3. **aws-actions/amazon-ecs-render-task-definition**  
   https://github.com/aws-actions/amazon-ecs-render-task-definition

4. **aws-actions/amazon-ecs-deploy-task-definition**  
   https://github.com/aws-actions/amazon-ecs-deploy-task-definition

## Target repo shape

Create the repo with this structure:

```text
.
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── deploy.yml
├── app/
│   ├── Dockerfile
│   └── (tiny sample app, language chosen for simplicity)
├── infra/
│   ├── modules/
│   │   ├── network/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── versions.tf
│   │   └── github_oidc/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── versions.tf
│   ├── environments/
│   │   ├── dev/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   ├── versions.tf
│   │   │   ├── terraform.tfvars.example
│   │   │   └── task-definition.json.tftpl
│   │   └── test/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       ├── versions.tf
│   │       ├── terraform.tfvars.example
│   │       └── task-definition.json.tftpl
│   └── README.md
├── scripts/
│   └── export-task-def.sh
├── .gitignore
├── Makefile
├── README.md
└── PLAN.md
```

## Architecture requirements

### 1. Use the upstream ECS module directly

Each environment must call the upstream module directly:

```hcl
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.12.1"
}
```

Do **not** add a local ECS wrapper by default.

The environment code may still use **small helper modules** for concerns outside ECS itself, for example:

- minimal networking
- GitHub OIDC IAM role setup

But the ECS service/cluster implementation should remain visibly based on the upstream ECS module so the repo teaches that module directly.

### 2. Two environments, `dev` and `test`

Implement both:

- `infra/environments/dev`
- `infra/environments/test`

They should be structurally similar and show how to parameterize environment-specific values such as:

- environment name
- service name suffix/prefix
- desired count
- CPU and memory
- domain/hostnames if used
- tags
- repository naming
- ALB naming
- health check path if needed

The point is to demonstrate a clean, understandable pattern for **environment parameterization**.

Do not create a generic orchestration layer that hides all of this. It should remain easy to read.

### 3. Parameterization stance

Show a practical middle ground:

- share small reusable pieces only where they reduce noise
- keep the environment roots explicit
- avoid turning `dev` and `test` into giant piles of copied code if a small shared helper reduces obvious duplication

A good target is:

- small shared modules for network and GitHub OIDC, if helpful
- direct ECS module usage in each environment root
- per-environment variables and tfvars examples that make the differences obvious

### 4. Networking stance

For minimalism, prefer one of these two approaches, in this order:

1. **If simpler overall:** create a minimal VPC inside this repo using a small shared module.
2. **If the implementation becomes noisy:** assume an existing VPC and subnets are provided as variables.

Pick the option that yields the cleaner teaching repo. The point is the ECS + release pattern, not VPC sophistication.

If a VPC is created in-repo, it should be reusable by both `dev` and `test` through the same module pattern, while still producing separate environment-specific resources.

### 5. ECS service stance

Use **Fargate**.

Use **one service per environment**.

Use **one primary container**.

Use **rolling deployment**, not blue/green.

Attach the service to an ALB target group.

Enable CloudWatch logging.

Do not add sidecars unless absolutely required.

### 6. ECR stance

Terraform creates one ECR repository per environment unless there is a compelling simplicity reason to share one repository with environment-specific tags.

Default preference:

- separate ECR repository for `dev`
- separate ECR repository for `test`

This makes environment boundaries clearer in a teaching repo.

GitHub Actions pushes images to the repository for the chosen environment.

Tag images with at least:

- commit SHA
- optionally an environment-qualified tag for convenience

Deployment should use an immutable tag or digest.

### 7. Task definition ownership

This is important.

The repo must be structured so that:

- Terraform creates the initial baseline ECS service and task definition family
- GitHub Actions later renders a new task definition JSON using the newly built image
- GitHub Actions deploys that task definition to ECS

Avoid a design where every routine image release requires editing Terraform variables and running `terraform apply`.

### 8. GitHub Actions auth stance

Use **GitHub OIDC to AWS IAM role assumption**, not long-lived AWS access keys.

Terraform must create the IAM role and trust policy needed by GitHub Actions.

The repo README must clearly document which GitHub repository and branch conditions are assumed in the OIDC trust relationship.

The plan should support either:

- one deploy role per environment, or
- one role with tightly scoped permissions and environment-aware conditions

Default preference: **one role per environment**, because it is easier to explain and reason about.

## Workflow requirements

### `ci.yml`

Purpose:

- run on pull requests and pushes
- do minimal lint/build/test
- build the container to prove it works
- avoid push/deploy on PRs

Keep this lean.

### `deploy.yml`

Purpose:

- run on push to `main` and via manual dispatch
- support deploying to either `dev` or `test`
- authenticate to AWS via OIDC
- log in to ECR
- build and push image
- render ECS task definition with the new image URI
- deploy updated task definition to ECS service
- wait for service stability

Use the official GitHub/AWS actions rather than ad hoc shell where possible.

Expected ingredients:

- `aws-actions/configure-aws-credentials`
- `aws-actions/amazon-ecr-login`
- `aws-actions/amazon-ecs-render-task-definition`
- `aws-actions/amazon-ecs-deploy-task-definition`

The workflow should make the target environment explicit.

## Required implementation details

### A. Baseline task definition file

Create a task definition template in each environment, then export a repo-local JSON file suitable for GitHub Actions to mutate.

Preferred pattern:

- Terraform renders `task-definition.json.tftpl` into a concrete baseline task definition artifact or equivalent output per environment
- a helper script can export or refresh a checked-in environment-specific `task-definition.json` file after infra creation

The final repo should make it obvious how GitHub Actions gets the task definition JSON it needs for `dev` and for `test`.

Do not leave this ambiguous.

### B. Avoid Terraform drift traps

Be careful not to create a bad ownership split.

The plan should preserve this rule:

- Terraform manages infra and baseline desired service definition
- GitHub Actions manages image roll-forward by registering new task definition revisions

Codex should explicitly avoid designing a system where Terraform constantly reverts CI/CD-driven task definition revisions unless that behavior is intentionally controlled.

If needed, document one of these approaches:

- lifecycle ignore strategy on selected task-definition-related service attributes, or
- a process expectation that infra changes are infrequent and task-definition runtime drift is acceptable between applies

But do not fake certainty. Explain the chosen tradeoff in README.

### C. Readability over abstraction

Favor explicit files over too much module indirection.

This is a teaching repo, not a platform framework.

### D. Environment clarity

A reader should be able to answer these questions in under a minute:

- what changes between `dev` and `test`?
- what is shared?
- where is the ECS module invoked?
- where is the GitHub deploy role defined?
- how does a deploy target a specific environment?

Design the layout to make those answers obvious.

## Deliverables

Codex should create these concrete deliverables:

1. A minimal app that can answer HTTP health checks
2. Dockerfile for the app
3. Direct usage of `terraform-aws-modules/terraform-aws-ecs/aws` v5.12.1 in both environment roots
4. A runnable `dev` environment
5. A runnable `test` environment
6. ECR repository and ECS service created by Terraform for each environment
7. ALB with listener and target group for each environment
8. CloudWatch logs wired for each service
9. GitHub OIDC IAM role for deployment, preferably per environment
10. `ci.yml`
11. `deploy.yml`
12. README with step-by-step usage
13. helper script(s) if needed for task definition export/sync

## Suggested implementation order

Codex should execute in this order.

### Phase 1, app and container

- create a tiny HTTP app with `/` and `/health`
- create Dockerfile
- ensure container listens on a configurable port, default 8080

### Phase 2, shared non-ECS helpers

- create small helper modules only where they clearly reduce noise
- likely candidates: `network`, `github_oidc`
- keep them narrow and easy to read

### Phase 3, dev environment

- create `infra/environments/dev`
- invoke `terraform-aws-modules/terraform-aws-ecs/aws` directly at version `5.12.1`
- create or accept networking inputs
- create ALB + listener + target group wiring as needed
- create ECR repository
- create CloudWatch log group
- create environment-specific outputs and task definition template

### Phase 4, test environment

- create `infra/environments/test`
- mirror the same overall pattern as `dev`
- keep differences explicit and minimal
- demonstrate environment parameterization cleanly

### Phase 5, GitHub deploy identity

- create IAM role resources for GitHub OIDC
- scope trust policy to the intended repo and branch or environment workflow conditions
- grant only what is needed for ECR push and ECS deploy
- prefer separate deploy roles for `dev` and `test`

### Phase 6, task definition artifact flow

- create baseline task definition templates/files per environment
- ensure GitHub Actions can render a new image into the correct environment file
- document how to refresh checked-in JSON when task definition shape changes

### Phase 7, GitHub Actions workflows

- `ci.yml` for basic validation
- `deploy.yml` for build, push, render, deploy
- make target environment selection explicit
- use immutable image references in deployment

### Phase 8, documentation

- explain architecture split
- explain `dev` vs `test`
- explain first-time bootstrap
- explain deploy flow
- explain rollback at a high level
- explain known tradeoffs and ownership boundaries

## Acceptance criteria

The work is complete when all of the following are true.

### Infrastructure

- `terraform init`, `plan`, and `apply` succeed for `infra/environments/dev`
- `terraform init`, `plan`, and `apply` succeed for `infra/environments/test`
- ECS cluster, service, ALB, target group, log group, and ECR repo are created per environment
- each ECS service is reachable via its ALB
- `/health` returns success in both environments

### Release flow

- pushing to `main` can trigger `deploy.yml`
- workflow can target `dev` or `test`
- workflow builds the image and pushes it to the correct ECR repository
- workflow renders a new task definition with the new image for the chosen environment
- workflow updates the ECS service successfully
- service reaches stable state
- a second commit with an app change results in a new ECS deployment without needing `terraform apply`

### Repo clarity

- the ownership split between Terraform and CI/CD is obvious from the README
- the module version `5.12.1` is pinned explicitly
- the environment parameterization pattern is obvious from comparing `dev` and `test`
- the repo is small enough that a human can understand it in one sitting

## Guardrails for Codex

- Do not upgrade the ECS module beyond `5.12.1`
- Do not introduce a local ECS wrapper module unless there is a hard blocker
- Do not use Terraform for routine image-only deployments
- Do not introduce unnecessary AWS services
- Do not use long-lived AWS credentials in GitHub secrets if OIDC can be used
- Do not over-generalize for many services or many environments in v1
- Do not bury critical deploy logic in obscure scripts when official GitHub actions suffice
- Do not make `dev` and `test` identical copies with pointless duplication if a small shared helper reduces noise
- Do not hide the ECS module behind so much abstraction that the reader cannot learn how it is being used

## Nice-to-haves, only if cheap

Only add these if they do not materially increase complexity:

- `terraform fmt` / `validate` in CI
- `tflint` or a placeholder target in Makefile
- manual `workflow_dispatch` for deploy
- output of ALB URL after apply
- simple rollback note in README, for example redeploying an earlier task definition revision
- per-environment GitHub environments if they help clarify deployment targeting

## README expectations

The final README should include:

1. What Terraform owns
2. What GitHub Actions owns
3. Why image rollout is not done through Terraform
4. How `dev` and `test` are parameterized
5. Why the upstream ECS module is used directly
6. How to bootstrap AWS + GitHub OIDC
7. How to run Terraform for the first deployment in each environment
8. How later app-only deploys work
9. How to update task definition structure when infra changes
10. Known limitations of the example

## Decision defaults

When there is ambiguity, choose the option that is:

- more minimal
- easier to read
- closer to official GitHub/AWS ECS deploy actions
- more explicit about `dev` vs `test`
- less likely to confuse Terraform ownership with release ownership

## Definition of done

The final repo should feel like this:

> A small reference implementation showing a sane ECS pattern where Terraform creates the service platform in both `dev` and `test`, while GitHub Actions ships new container versions by updating the ECS task definition image.
