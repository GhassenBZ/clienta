# Vikunja on AWS

This branch deploys the official Vikunja v2.8.0 server with a private MySQL database and a small, pre-seeded workspace. The seed creates real database-backed accounts, shared projects, Kanban tasks, labels, assignments, comments, and dated tasks for the Gantt view.

## Demo accounts

All four accounts use the same disposable lab password:

| Username | Display name |
| --- | --- |
| `lisa.chen` | Lisa Chen |
| `marco.rossi` | Marco Rossi |
| `amina.khan` | Amina Khan |
| `noah.martin` | Noah Martin |

**Password for each account:** `VikunjaDemo2026`

The email addresses use the reserved `.test` domain. Public registration is disabled. These shared credentials are intentionally public demo credentials; do not reuse them outside this isolated lab. The seed runs on first boot and is idempotent when the instance is replaced while the database remains.

The three shared projects are **Office Move**, **Product Launch**, and **Team Retreat**. Each gets Vikunja's standard List, Gantt, Table, and Kanban views. The Kanban boards use To-Do, Doing, and Done buckets, with dated tasks, labels, assignments, and comments.

## Package and deploy

The package script requires Windows PowerShell, `tar.exe`, Node.js 24 or newer, pnpm 12.16.1, and workstation internet access. It verifies checksums for the official Vikunja v2.8.0 server release and source archive, builds the frontend, and creates separate frontend and backend bundles in `build\`.

Configure the AWS Academy credentials in the AWS CLI profile, then run these commands from the repository root:

```powershell
aws sts get-caller-identity
.\scripts\package-app.ps1
terraform -chdir=infra init
terraform -chdir=infra fmt -recursive
terraform -chdir=infra validate
terraform -chdir=infra plan -out=tfplan
terraform -chdir=infra apply tfplan
```

Terraform prompts for the RDS master password. Choose at least 16 characters and keep the value out of the repository. The password is marked sensitive, but Terraform state and plan files still contain sensitive infrastructure data; keep them private and never commit or share them.

After deployment, open `http://<alb_dns_name>` using the value from:

```powershell
terraform -chdir=infra output -raw alb_dns_name
```

## Current deployment

- Public HTTP Application Load Balancer in two public subnets.
- Separate frontend and backend EC2 Auto Scaling groups, each spanning two Availability Zones, with a minimum and desired capacity of two and a maximum of four.
- The frontend ASG runs Nginx in public subnets; instances accept HTTP only from the ALB. The backend ASG runs Vikunja's API in private application subnets.
- The ALB serves the frontend by default and routes `/api/*`, `/dav*`, and `/.well-known/caldav*` to the backend target group.
- CPU target-tracking policies scale each ASG toward 60% average utilization. Launch-template changes use rolling instance refreshes.
- Private MySQL 8.0 RDS in the data subnets.
- A private, encrypted S3 bucket stores separate frontend/backend bundles and the runtime configuration. The existing `LabInstanceProfile` can download only those objects through the S3 gateway endpoint; no custom IAM role or NAT gateway is created.
- The database password and a derived JWT secret are stored in the private S3 runtime configuration, not in the repository or EC2 user data. The EC2 instance downloads that configuration at boot.
- The backend ALB health check uses Vikunja's unauthenticated `/api/v1/info` endpoint; the frontend health check uses `/health`.

Vikunja stores accounts and project/task data in RDS. Uploaded attachments still use local storage on backend instances, so they are not shared across the backend ASG and may be unavailable when requests reach a different instance.

## Data and destroy warning

The bootstrap seed repopulates the four demo accounts and three sample projects when it encounters a fresh database. It does not back up or restore changes made during a session. The current RDS module skips a final snapshot, so a full Terraform destroy removes the database and its data. Take and verify a separate RDS snapshot before destroying the lab if you need to preserve user changes.

```powershell
terraform -chdir=infra plan -destroy -out=destroy.tfplan
terraform -chdir=infra apply destroy.tfplan
```

## Repository notes

- `vikunja\` - demo seed script and database-backed sample data.
- `infra\` - Terraform configuration and AWS modules.
- `scripts\` - release packaging and deployment helpers.
- `app\` - the former Clienta source; it is not included in or deployed by this Vikunja package.

Terraform uses fixed project names, `us-east-1`, the existing `LabInstanceProfile`, and the repository's configured network ranges. No AWS credentials, Terraform state, plan files, or downloaded release binaries belong in Git.
