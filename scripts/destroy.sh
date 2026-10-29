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

echo "Destroying Terraform-managed Clienta infrastructure"

terraform -chdir="$(dirname "$0")/../infra" destroy -auto-approve
