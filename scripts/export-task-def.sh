#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <dev|test>" >&2
  exit 1
fi

environment="$1"
env_dir="infra/environments/${environment}"
output_file="${env_dir}/task-definition.json"

if [[ ! -d "${env_dir}" ]]; then
  echo "unknown environment: ${environment}" >&2
  exit 1
fi

terraform -chdir="${env_dir}" output -raw task_definition_json > "${output_file}"

echo "wrote ${output_file}"
