# Clienta

Clienta is a three-tier customer management app with a browser frontend, an Express API, and a MySQL database.

## Run locally

Start the app from `app/backend` with `npm start`. It reads database settings from `app/backend/.env`, creates the customer table when the database is available, and serves both the frontend and API on port 8080. Open `http://localhost:8080` to use the app. Copy the root `.env.example` to `app/backend/.env`, set your local database credentials, and create the configured MySQL database before starting.

## Deployment

The frontend uses the same-origin `/api/customers` path. Keep the frontend and API on the same origin. Never put database credentials in frontend files.

## Terraform and AWS credentials

Terraform uses the AWS provider's default credential chain. Put the temporary AWS Academy credentials in the local AWS CLI credentials file at `%USERPROFILE%\.aws\credentials`; do not put them in this repository.

After starting the lab, update the `default` profile in that file. From the repository root, package the app before planning:

```powershell
aws sts get-caller-identity
.\scripts\package-app.ps1
Set-Location .\infra
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

The packaging step needs `npm` and internet access on the developer workstation. It builds production dependencies, downloads a checksum-verified Linux Node.js runtime, excludes `.env` files, and writes `build\clienta-app.tar.gz`. Terraform uploads that archive to a private S3 bucket. The app instance reads it through the S3 gateway endpoint using the existing `LabInstanceProfile`; no NAT gateway or custom IAM role is created for the artifact access.

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
