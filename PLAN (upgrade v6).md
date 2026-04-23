# PLAN (upgrade v6).md

## Summary

Upgrade this repo from `terraform-aws-modules/terraform-aws-ecs` `v5.12.1`
to `v6.12.0` without a big-bang cutover of all environments at once.

The safest path is:

1. prepare the repo for mixed `v5` / `v6` operation
2. migrate `dev` first
3. migrate `test` second
4. clean up docs and final validation

Each implementation phase should be committed immediately after completion
using a title that starts with:

- `upgrade v6: phase ...`

## Why this can avoid a big bang

Yes, this can be done without upgrading both environments at once.

The repo already isolates environment composition in:

- `infra/environments/dev`
- `infra/environments/test`

and wraps ECS usage in:

- `infra/modules/ecs_environment`
- `infra/modules/hello_ecs`

That makes it practical to:

- keep `test` on the current `v5` wrappers temporarily
- introduce parallel `v6` wrappers
- point `dev` at the `v6` wrappers first
- migrate `test` only after `dev` validates cleanly

This phased path is preferable because `v6.0.0` includes the breaking jump
to AWS provider `6.x`, and the ECS cluster/service submodule interfaces also
change in several places.

## Upstream upgrade facts to follow

Primary sources:

1. `terraform-aws-modules/terraform-aws-ecs` changelog at `v6.12.0`
2. `modules/cluster` variables/outputs at `v6.12.0`
3. `modules/service` variables/outputs at `v6.12.0`

Repo-impacting changes to account for:

- AWS provider requirement moves from `5.x` to `6.x`
- cluster submodule interface changes:
  - `cluster_name` -> `name`
  - `cluster_configuration` -> `configuration`
  - `cluster_service_connect_defaults` -> `service_connect_defaults`
  - `cluster_settings` -> `setting`
- service submodule interface changes:
  - `security_group_rules` -> split `security_group_ingress_rules` and `security_group_egress_rules`
  - `ordered_placement_strategy` type changes from map-style to object/map definitions compatible with `v6`
  - `task_exec_ssm_param_arns` / `task_exec_secret_arns` defaults differ and should be set explicitly if needed
- provider lockfiles must be regenerated per environment root

## Phase 1: prepare the repo for phased v6 rollout

Goal:

- make the repo capable of running `test` on current `v5` wrappers while
  `dev` moves to `v6`

Changes:

- create parallel wrapper modules:
  - `infra/modules/ecs_environment_v6`
  - `infra/modules/hello_ecs_v6`
- keep existing `ecs_environment` and `hello_ecs` wrappers unchanged for the
  moment so `test` remains stable
- widen or split provider constraints only where needed so shared helper
  modules like `network` and `github_oidc` can be consumed by both paths
- keep the external env-root interface as close as possible to the current
  `hello_ecs` object shape to minimize env-root churn
- document inside the new wrapper modules which upstream `v6.12.0` inputs
  replace the current `v5` inputs

Acceptance:

- current `dev` and `test` still validate unchanged
- new `*_v6` wrapper modules exist and validate when referenced

Commit:

- `upgrade v6: phase 1 prep v6 wrappers`

## Phase 2: migrate shared v6 wrappers and switch dev

Goal:

- move `dev` onto the `v6.12.0` ECS wrappers while leaving `test` on `v5`

Changes:

- implement `infra/modules/ecs_environment_v6` on top of
  `terraform-aws-modules/ecs/aws//modules/cluster` `v6.12.0`
- implement `infra/modules/hello_ecs_v6` on top of
  `terraform-aws-modules/ecs/aws//modules/service` `v6.12.0`
- map the old wrapper behavior to the new upstream interface explicitly:
  - cluster `name`
  - cluster `configuration`
  - cluster `setting`
  - service `security_group_ingress_rules`
  - service `security_group_egress_rules`
  - explicit `vpc_id` passed to the service module
- upgrade only `infra/environments/dev/versions.tf` to AWS provider `~> 6.0`
- point only `infra/environments/dev/main.tf` at `ecs_environment_v6` and
  `hello_ecs_v6`
- regenerate only the `dev` lockfile
- keep `dev` outputs, task-definition export path, naming, workflow
  expectations, and checked-in artifact locations unchanged

Acceptance:

- `terraform -chdir=infra/environments/dev init -backend=false -upgrade`
  succeeds
- `terraform -chdir=infra/environments/dev validate` succeeds
- `test` still validates on the old wrapper/provider path

Commit:

- `upgrade v6: phase 2 migrate dev`

## Phase 3: switch test to v6

Goal:

- complete the environment migration after the `dev` path is proven

Changes:

- upgrade `infra/environments/test/versions.tf` to AWS provider `~> 6.0`
- point `infra/environments/test/main.tf` at `ecs_environment_v6` and
  `hello_ecs_v6`
- regenerate only the `test` lockfile
- keep outputs, artifact paths, and workflow-derived naming unchanged

Acceptance:

- `terraform -chdir=infra/environments/test init -backend=false -upgrade`
  succeeds
- `terraform -chdir=infra/environments/test validate` succeeds
- `dev` still validates on the new path

Commit:

- `upgrade v6: phase 3 migrate test`

## Phase 4: collapse back to canonical module names

Goal:

- remove the temporary parallel-wrapper state once both environments are on
  `v6`

Changes:

- replace the old canonical wrappers with the `v6` implementations:
  - `ecs_environment_v6` -> `ecs_environment`
  - `hello_ecs_v6` -> `hello_ecs`
- update both environments back to the canonical module paths
- remove obsolete `v5` wrapper implementations
- keep helper modules `network` and `github_oidc` as shared non-versioned
  helpers

Acceptance:

- both environments still validate
- no remaining references to the old `v5.12.1` ECS module
- no remaining references to temporary `*_v6` module names

Commit:

- `upgrade v6: phase 4 collapse wrappers`

## Phase 5: docs, workflows, and final cleanup

Goal:

- make the repo documentation reflect the new steady state

Changes:

- update `README.md` and `infra/README.md` to reference ECS module
  `v6.12.0`
- update any text that still mentions AWS provider `5.x`
- update any plan/docs references that still mention the old ECS version
- keep workflow behavior unchanged unless a provider/module upgrade requires
  small wording or setup updates

Acceptance:

- `make validate` succeeds
- `make app-smoke` succeeds
- workflow YAML still parses
- the repo is clean and docs match the implemented state

Commit:

- `upgrade v6: phase 5 docs and cleanup`

## Test plan

- `terraform fmt -check -recursive`
- `terraform -chdir=infra/environments/dev init -backend=false -upgrade`
- `terraform -chdir=infra/environments/dev validate`
- `terraform -chdir=infra/environments/test init -backend=false -upgrade`
- `terraform -chdir=infra/environments/test validate`
- `bash -n scripts/export-task-def.sh`
- `python3 -m json.tool infra/environments/dev/task-definitions/hello-ecs.json`
- `python3 -m json.tool infra/environments/test/task-definitions/hello-ecs.json`
- `make app-smoke`
- workflow YAML parse check

## Assumptions and defaults

- The repo will upgrade only to `terraform-aws-modules/terraform-aws-ecs`
  `v6.12.0`, not `v7.x`.
- The non-big-bang path is preferred over shortest diff size.
- Resource names, checked-in task-definition paths, and workflow-derived
  deploy naming should remain stable across the upgrade.
- No `terraform plan` or `terraform apply` against AWS is required while
  implementing this repo upgrade.
