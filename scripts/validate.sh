#!/usr/bin/env bash
set -euo pipefail

pause_on_exit() {
  local status=$?
  trap - EXIT
  if [[ -t 0 ]]; then
    printf '\nFinished with exit code %s. Press Enter to close this window...' "$status"
    IFS= read -r _ || true
  fi
  exit "$status"
}
trap pause_on_exit EXIT

cd "$(dirname "$0")/../infra"

echo "Validating Terraform configuration"
terraform fmt -check -diff
terraform init -backend=false
terraform validate

echo "Validation complete."
