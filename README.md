# Clienta

Clienta is a three-tier customer management app with a browser frontend, an Express API, and a MySQL database.

## Run locally

Start the app from `app/backend` with `npm start`. It reads database settings from `app/backend/.env`, creates the customer table when the database is available, and serves both the frontend and API on port 8080. Open `http://localhost:8080` to use the app. Copy the root `.env.example` to `app/backend/.env`, set your local database credentials, and create the configured MySQL database before starting.

## Deployment

The frontend uses the same-origin `/api/customers` path. Keep the frontend and API on the same origin. Never put database credentials in frontend files.

## Terraform and AWS credentials

Terraform uses the AWS provider's default credential chain. Put the temporary AWS Academy credentials in the local AWS CLI credentials file at `%USERPROFILE%\.aws\credentials`; do not put them in this repository.

After starting the lab, update the `default` profile in that file. From the repository root:

```powershell
aws sts get-caller-identity
terraform -chdir=infra init
terraform -chdir=infra fmt -recursive
terraform -chdir=infra validate
```

To build the application AMI and remove the temporary public builder, run the helper from Git Bash:

```bash
./scripts/build-ami.sh
```

The script validates and initializes Terraform, then runs the build and cleanup plans/applies in sequence. Terraform asks you to confirm each apply. The first apply creates a temporary EC2 builder in a public subnet. It installs Node.js, downloads the public `main` branch of this repository, installs production dependencies, and prepares a systemd service. Terraform waits for the builder's cloud-init success marker before creating the AMI; the private application EC2 instance is launched from that image.

The script saves the builder ID in the ignored `infra/ami-builder.auto.tfvars` file before planning cleanup. Keep that file for later Terraform operations so the AMI remains managed after the builder is removed. If you decline or the cleanup step fails, rerun the cleanup plan and apply from `infra` with `terraform plan -out=ami-cleanup.tfplan` and `terraform apply ami-cleanup.tfplan`. To build a replacement image later, run `./scripts/build-ami.sh` again.

The image contains the application files and production Node.js dependencies, but no database credentials. Its systemd service starts only when `/etc/clienta/clienta.env` exists; a future launch template must write that file and start the service with the RDS connection settings. RDS, a launch template/Auto Scaling group, and ALB listener/target configuration are not implemented yet, so the app is not currently reachable through the ALB.

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
