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

Review the plan for the VPC, public, private frontend, private backend, and private data subnets, route tables and internet gateway, public and internal ALBs, frontend/backend target groups, health checks, tier and RDS security groups, private S3 buckets and bundle/runtime objects, S3 gateway endpoint, two multi-AZ ASGs, and private MySQL RDS. Confirm each ASG has a minimum/desired capacity of two and a maximum of four, and review the associated cost. Confirm the RDS security group allows TCP/3306 only from the backend security group. Confirm the buckets block public access and the instance tiers use the existing `LabInstanceProfile` only for their required objects.

Frontend instances in private frontend subnets download and serve the static bundle through Nginx. Backend instances in private backend subnets download the API bundle and runtime configuration, start Vikunja on port 8080, and run the seeder that creates actual demo accounts and shared project data in RDS. Public registration is enabled. The public ALB serves frontend traffic, while frontend Nginx proxies API and CalDAV paths to the private internal ALB. The backend health check calls `/api/v1/info`; no NAT route is used. User uploads are stored in a separate private S3 bucket.

## Destroy

Before the lab session ends:

```powershell
terraform -chdir=infra plan -destroy -out=destroy.tfplan
terraform -chdir=infra apply destroy.tfplan
```

The RDS module currently skips a final snapshot and has no explicit automated backup retention. A full destroy removes the database and any changes to the demo data. Take and verify a separate RDS snapshot first if you need to preserve user changes.

Keep the local state until destruction succeeds. Generated state, plans, credentials, and `.terraform/` are ignored by Git.
