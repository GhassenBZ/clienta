#!/usr/bin/env bash
set -euo pipefail

echo "Destroying Terraform-managed Clienta infrastructure"
echo "This should only be run after verifying that the current session is the last operational one."

if command -v terraform >/dev/null 2>&1; then
  terraform -chdir="$(dirname "$0")/../infra" destroy -auto-approve
else
  echo "Terraform is not installed or not on PATH."
  exit 1
fi
