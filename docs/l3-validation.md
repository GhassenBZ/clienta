# Vikunja validation and teardown

## Package and validate

From the repository root, build the bundle before running Terraform validation because the configuration hashes that archive:

```powershell
.\scripts\package-app.ps1
terraform -chdir=infra fmt -recursive
terraform -chdir=infra init -backend=false
terraform -chdir=infra validate
```

The PowerShell package script requires `tar.exe`, Node.js 24 or newer, pnpm 12.16.1, and workstation internet access. It verifies pinned SHA-256 digests for the official Vikunja v2.8.0 Linux x86_64 server release and source archive, builds the frontend, and creates `build\vikunja-frontend.tar.gz` and `build\vikunja-backend.tar.gz`.

## Apply

After updating the temporary AWS Academy credentials and verifying the identity:

```powershell
aws sts get-caller-identity
terraform -chdir=infra init
terraform -chdir=infra plan -out=tfplan
terraform -chdir=infra apply tfplan
terraform -chdir=infra output
```

Terraform prompts for the sensitive RDS password. Use at least 16 characters, and keep Terraform state and plan files private.

Review the plan for the VPC, six subnets, public route table and internet gateway, ALB listener, frontend/backend target groups and API path rule, health checks, tier and RDS security groups, private S3 bucket and bundle/runtime objects, S3 gateway endpoint, two multi-AZ ASGs, and private MySQL RDS. Confirm each ASG has a minimum/desired capacity of two and a maximum of four, and review the associated cost. Confirm the RDS security group allows TCP/3306 only from the backend security group. Confirm the bucket blocks public access and both tiers use the existing `LabInstanceProfile` to read the required objects.

Frontend instances download and serve the static bundle through Nginx. Backend instances download the API bundle and runtime configuration, start Vikunja on port 8080, and run the seeder that creates actual demo accounts and shared project data in RDS. Public registration is disabled. The ALB routes API and CalDAV paths to the backend, while the default route serves the frontend. The backend health check calls `/api/v1/info`; no NAT route is used. Attachments remain on each backend instance's local disk and are not shared across the backend ASG.

## Destroy

Before the lab session ends:

```powershell
terraform -chdir=infra plan -destroy -out=destroy.tfplan
terraform -chdir=infra apply destroy.tfplan
```

The RDS module currently skips a final snapshot and has no explicit automated backup retention. A full destroy removes the database and any changes to the demo data. Take and verify a separate RDS snapshot first if you need to preserve user changes.

Keep the local state until destruction succeeds. Generated state, plans, credentials, and `.terraform/` are ignored by Git.
