# Clienta

Clienta is a three-tier customer management app with a browser frontend, an Express API, and a MySQL database.

Project implementation status against the seven deliverables in the cahier des charges is summarized in [docs/final-project-summary.md](./docs/final-project-summary.md).

## Run locally

Start the app from `app/backend` with `npm start`. It reads database settings from `app/backend/.env`, creates the customer table when the database is available, and serves both the frontend and API on port 8080. Open `http://localhost:8080` to use the app. Copy the root `.env.example` to `app/backend/.env`, set your local database credentials, and create the configured MySQL database before starting.

## Deployment

The frontend uses the same-origin `/api/customers` path. Currently Express serves the frontend files and API from the same EC2 instance; S3 stores the deployment bundle and does not host the live frontend. The ALB is provisioned but has no listener or target group yet. Never put database credentials in frontend files.

## Terraform and AWS credentials

Terraform uses the AWS provider's default credential chain. Put the temporary AWS Academy credentials in the local AWS CLI credentials file at `%USERPROFILE%\.aws\credentials`; do not put them in this repository.

After starting the lab, update the `default` profile in that file. From the repository root, package the app before planning:

```powershell
aws sts get-caller-identity
.\scripts\package-app.ps1
terraform -chdir=infra init
terraform -chdir=infra fmt -recursive
terraform -chdir=infra validate
terraform -chdir=infra plan -out=tfplan
terraform -chdir=infra apply tfplan
```

The packaging step needs `npm` and internet access on the developer workstation. It builds production dependencies, downloads a checksum-verified Linux Node.js runtime, excludes `.env` files, and writes `build\clienta-app.tar.gz`. Terraform provisions a private S3 artifact bucket through a CloudFormation stack and uploads the archive. The bucket policy grants the existing `LabInstanceProfile` role access to download the bundle through the S3 gateway endpoint. This worked with the current Learner Lab permissions, but CloudFormation does not bypass IAM restrictions and the template does not configure Object Lock. No NAT gateway or custom IAM role is created for artifact access.

Terraform also creates a private MySQL RDS instance. The ALB is not yet connected to the app because its listener and target group have not been implemented. Automated EBS snapshots and CloudWatch alarms are not configured in the current branch.

Destroy the lab resources before the session ends:

```powershell
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

The fixed project values are defined directly in the Terraform configuration: the `clienta` prefix, `us-east-1` region, network ranges, and Free Tier instance size. Terraform state, plans, credentials, and provider downloads remain local and are excluded from Git.

## Repository structure

- `app/` - application source code and database schema.
- `infra/` - Terraform configuration and AWS modules.
- `scripts/` - validation and destruction helpers.
- `docs/` - project documentation and templates.
