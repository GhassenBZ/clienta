#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../infra"

echo "Validating Terraform configuration"
terraform fmt -check -diff
terraform init -backend=false
terraform validate

echo "Validation complete."
