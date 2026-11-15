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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── 1. Validate Terraform ─────────────────────────────────────────────────────
echo "==> Validating Terraform configuration..."
cd "$ROOT_DIR/infra"
terraform fmt -check -diff
terraform init -upgrade
terraform validate
echo "Validation complete."

# ── 3. Plan ───────────────────────────────────────────────────────────────────
echo ""
echo "==> Running Terraform plan..."
terraform plan -out=tfplan

# ── 4. Apply ──────────────────────────────────────────────────────────────────
echo ""
echo "==> Applying Terraform plan..."
terraform apply tfplan
rm -f tfplan

echo ""
echo "==> Done! Open the URL above (alb_dns_name) in your browser."
