# PLAN (upgrade v7).md

## Goal

Upgrade this repo from `terraform-aws-modules/terraform-aws-ecs` `v6.12.0`
to `v7.5.0` without a big-bang cutover of all environments at once.

Yes, this can still be phased by environment.

The current wrappers already use the v6-style ECS module interfaces. Based on
the upstream `v7.5.0` module files, the cluster and service wrapper contracts
used in this repo remain close enough that we can reuse the previous rollout
pattern:

- add temporary parallel v7 wrappers
- move `dev`
- move `test`
- collapse the temporary wrappers back into the canonical module names

As each implementation phase is completed, create a separate git commit
before moving to the next phase.

Required implementation commit title prefix:

- `upgrade v7: phase ...`

## Upstream Notes

Primary sources checked for this plan:

1. `terraform-aws-modules/terraform-aws-ecs` changelog at `v7.5.0`
2. `modules/cluster` `variables.tf`, `outputs.tf`, and `versions.tf`
3. `modules/service` `variables.tf`, `outputs.tf`, and `versions.tf`

Relevant conclusions:

- `v7.0.0` is the breaking release in this line.
- The cluster submodule still uses the v6 naming model:
  - `region`
  - `name`
  - `configuration`
  - `service_connect_defaults`
  - `setting`
- The service submodule still uses the v6 naming model:
  - `region`
  - `vpc_id`
  - `track_latest`
  - ECS API-style container definition keys such as `portMappings` and
    `logConfiguration`
  - split `security_group_ingress_rules` and
    `security_group_egress_rules`
- The cluster submodule at `v7.5.0` now requires the `time` provider in
  addition to `aws`.
- The upstream module still requires Terraform `>= 1.5.7`.
- The upstream module now requires AWS provider `>= 6.34`, which is still
  compatible with this repo staying on the AWS provider `6.x` line.
- The service and cluster outputs used by this repo remain compatible with
  the current wrappers.

## Migration Strategy

Do not cut both environments over in one commit.

Instead:

1. add temporary parallel wrappers for `v7.5.0`
2. move `dev` first and validate it locally
3. move `test` second and validate it locally
4. once both roots are on v7, make the canonical wrapper names point to the
   v7 implementation and delete the temporary wrappers

This keeps the change reviewable and leaves a clean point-in-time history for
the first environment migration before the second one happens.

## Phase 1: prepare parallel v7 wrappers

Create temporary parallel modules:

- `infra/modules/ecs_environment_v7`
- `infra/modules/hello_ecs_v7`

Implementation goals:

- keep the existing canonical modules unchanged for the moment
- point the new wrappers at:
  - `terraform-aws-modules/ecs/aws//modules/cluster` `v7.5.0`
  - `terraform-aws-modules/ecs/aws//modules/service` `v7.5.0`
- keep the repo’s wrapper input/output contracts the same as the current v6
  wrappers
- add any required notes or minimal adjustments for `v7.5.0`, including the
  new `time` provider requirement from the upstream cluster module
- preserve current behavior:
  - `ignore_task_definition_changes = true`
  - `track_latest = false`
  - existing task-definition rendering contract
  - existing IAM/deploy flow

Verification:

- `terraform fmt -recursive`
- `terraform -chdir=infra/environments/dev init -backend=false`
- `terraform -chdir=infra/environments/dev validate`
- `terraform -chdir=infra/environments/test init -backend=false`
- `terraform -chdir=infra/environments/test validate`

Commit after completion:

- `chore: upgrade v7: phase 1 prep`

## Phase 2: move dev to v7

Switch only `infra/environments/dev` to the parallel v7 wrappers.

Implementation goals:

- update `infra/environments/dev/main.tf` to use the temporary v7 module
  sources
- update `infra/environments/dev/.terraform.lock.hcl` as needed after local
  init so the new provider/module dependencies are recorded
- keep `test` on the existing canonical v6 wrappers during this phase

Verification:

- `terraform -chdir=infra/environments/dev init -backend=false -upgrade`
- `terraform -chdir=infra/environments/dev validate`
- `terraform -chdir=infra/environments/test validate`

Commit after completion:

- `chore: upgrade v7: phase 2 dev`

## Phase 3: move test to v7

Switch only `infra/environments/test` to the parallel v7 wrappers.

Implementation goals:

- update `infra/environments/test/main.tf` to use the temporary v7 module
  sources
- update `infra/environments/test/.terraform.lock.hcl` as needed after local
  init
- keep `dev` on the already-migrated v7 path

Verification:

- `terraform -chdir=infra/environments/test init -backend=false -upgrade`
- `terraform -chdir=infra/environments/test validate`
- `terraform -chdir=infra/environments/dev validate`

Commit after completion:

- `chore: upgrade v7: phase 3 test`

## Phase 4: collapse v7 into canonical wrappers

Once both environments are on the temporary v7 wrappers, make the canonical
module names the v7 implementation again.

Implementation goals:

- copy the validated v7 implementation into:
  - `infra/modules/ecs_environment`
  - `infra/modules/hello_ecs`
- switch both environment roots back to the canonical wrapper names
- delete:
  - `infra/modules/ecs_environment_v7`
  - `infra/modules/hello_ecs_v7`

Verification:

- `terraform fmt -recursive`
- `terraform -chdir=infra/environments/dev init -backend=false`
- `terraform -chdir=infra/environments/dev validate`
- `terraform -chdir=infra/environments/test init -backend=false`
- `terraform -chdir=infra/environments/test validate`

Commit after completion:

- `chore: upgrade v7: phase 4 cleanup`

## Phase 5: docs and repo cleanup

Update the repo documentation to describe the new upstream version and any
behavioral notes that matter to future maintenance.

Implementation goals:

- update `README.md`
- update `infra/README.md`
- remove stale references to `v6.12.0`
- note any v7-specific wrapper considerations worth preserving in comments or
  docs

Verification:

- `make validate`
- `make app-smoke`
- `bash -n scripts/export-task-def.sh`
- workflow YAML parse check
- `jq empty` on checked-in task-definition JSON artifacts

Commit after completion:

- `docs: upgrade v7: phase 5 docs`

## Acceptance Criteria

The upgrade is complete when all of the following are true:

- both environments reference canonical wrappers again
- canonical wrappers use `terraform-aws-modules/terraform-aws-ecs`
  `v7.5.0`
- local-only Terraform init/validate passes in both env roots
- no remaining stale docs claim the repo uses `v6.12.0`
- no `terraform plan` or `terraform apply` has been run against a real AWS
  account during the upgrade

## Constraints

- Do not run `terraform plan` or `terraform apply` against a real AWS account.
- Local-only commands such as `terraform fmt`, `terraform init -backend=false`,
  and `terraform validate` are allowed.
- Keep commit history presentable and phase-oriented.
