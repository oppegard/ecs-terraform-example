#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <dev|test> <app-name>" >&2
  exit 1
fi

environment="$1"
app_name="$2"
env_dir="infra/environments/${environment}"

if [[ ! -d "${env_dir}" ]]; then
  echo "unknown environment: ${environment}" >&2
  exit 1
fi

if [[ "${app_name}" != "hello-ecs" ]]; then
  echo "unknown app: ${app_name}" >&2
  exit 1
fi

output_file="$(terraform -chdir="${env_dir}" output -raw task_definition_file_path)"

mkdir -p "$(dirname "${output_file}")"

terraform -chdir="${env_dir}" output -raw task_definition_json > "${output_file}"

echo "wrote ${output_file}"
