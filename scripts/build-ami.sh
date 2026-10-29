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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infra"

cd "$INFRA_DIR"

echo "Checking and initializing the Terraform configuration"
terraform fmt -check -recursive
terraform init
terraform validate

echo
echo "Planning the temporary image builder and application AMI"
terraform plan -var="build_ami=true" -out=ami-build.tfplan

echo
echo "Applying the image build plan"
terraform apply ami-build.tfplan

builder_id="$(terraform output -raw image_builder_instance_id)"
if [[ ! "$builder_id" =~ ^i-[[:xdigit:]]+$ ]]; then
  echo "Could not read a valid image builder instance ID from Terraform output." >&2
  echo "The builder may still be running; inspect Terraform output before continuing." >&2
  exit 1
fi

builder_vars_file="ami-builder.auto.tfvars"
temporary_vars_file="${builder_vars_file}.tmp"
printf 'build_ami = false\nami_builder_instance_id = "%s"\n' "$builder_id" > "$temporary_vars_file"
mv "$temporary_vars_file" "$builder_vars_file"

echo
echo "Saved the builder ID in $INFRA_DIR/$builder_vars_file"
echo "Planning cleanup of the temporary builder while retaining the AMI"
terraform plan -out=ami-cleanup.tfplan

echo
echo "Applying the cleanup plan"
terraform apply ami-cleanup.tfplan

echo
echo "AMI build complete. The temporary builder was removed and the AMI remains managed by Terraform."
terraform output app_ami_id
