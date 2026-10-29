# L3 validation and teardown

## Local validation

From the repository root:

```powershell
terraform -chdir=infra fmt -recursive
terraform -chdir=infra init -backend=false
terraform -chdir=infra validate
```

The configuration must validate before any AWS resources are created.

## Build and apply

After updating the temporary AWS Academy credentials and verifying the identity, build the image from the repository root:

```bash
./scripts/build-ami.sh
```

The helper validates and initializes Terraform, then runs two reviewed plans and confirmed applies: first it creates the temporary public builder, waits for the cloud-init success marker, creates the AMI, and launches the private application instance; then it removes the builder while preserving the AMI. The builder ID is saved to the ignored `infra/ami-builder.auto.tfvars` file. Keep this file for later Terraform operations.

Review the first plan for the VPC, six subnets, public route table and internet gateway, ALB, application and RDS security groups, a temporary public builder, the AMI, and a private application EC2 instance. The builder downloads the public `main` branch and installs production dependencies. The EC2 root volume is encrypted gp3.

If cleanup is declined or fails, run `terraform plan -out=ami-cleanup.tfplan` and `terraform apply ami-cleanup.tfplan` from `infra` after checking the plan. To build a replacement image, rerun `./scripts/build-ami.sh`.

The AMI includes the app and Node dependencies but no database credentials. A future launch template must write `/etc/clienta/clienta.env` and start the systemd service after writing it. The ALB has no listener or target group, so it is not expected to serve traffic. RDS and Auto Scaling are not implemented.

## Destroy

Before the lab session ends:

```powershell
terraform -chdir=infra plan -destroy -out=destroy.tfplan
terraform -chdir=infra apply destroy.tfplan
```

If the destroy plan is reviewed and approved, the shorter equivalent is:

```powershell
terraform -chdir=infra destroy
```

Keep the local state until destruction succeeds. Generated state, plans, credentials, and `.terraform/` are ignored by Git.
