# Vikunja deployment changes

This note describes the current code in this branch. It does not mean the Terraform has been applied to AWS.

## Application and deployment packages

- The deployment now uses Vikunja v2.8.0 instead of packaging the old Clienta application.
- `scripts/package-app.ps1` verifies the pinned Vikunja server and source archives, builds the browser frontend, and creates two artifacts: `build/vikunja-frontend.tar.gz` and `build/vikunja-backend.tar.gz`.
- The frontend bundle contains static browser assets and the bundled Python static server. The backend bundle contains the Vikunja server binary, its license, and the demo seeder/data.
- The package script requires Windows PowerShell, `tar.exe`, Node.js 24 or newer, pnpm 12.16.1, and internet access.

## AWS architecture

- The public Application Load Balancer serves the frontend by default. It routes `/api/*`, `/dav*`, and `/.well-known/caldav*` to the backend.
- The frontend runs under Nginx in its own Auto Scaling group in the public subnets. Inbound HTTP to frontend instances is restricted to the ALB.
- The Vikunja API runs in a separate Auto Scaling group in private application subnets. RDS accepts database traffic only from this backend tier.
- Both groups span the configured Availability Zones, start with a minimum and desired capacity of two, and can scale to four instances. CPU target tracking is set to 60%; launch-template updates use rolling instance refresh.
- The ALB checks `/health` on the frontend and `/api/v1/info` on the backend.
- A private, encrypted S3 bucket holds the two deployment bundles and the generated runtime configuration. The instance profile downloads these objects through an S3 gateway endpoint. S3 here is for deployment files and configuration, not Vikunja uploads.
- The backend runtime configuration disables public registration and connects to private MySQL. The database password is a required Terraform input; sensitive values are not included in this note.

## Demo data and documentation

- Backend startup runs the seeder to create real demo accounts, shared projects, and sample tasks in MySQL. The current seed contains four accounts, three projects, and 44 dated tasks, including Kanban buckets, labels, assignments, and comments.
- README, architecture, requirements, cost, deployment-validation, and helper scripts were updated to describe the two-tier setup and its limitations.

## Uploaded files and profile pictures

The current Vikunja file-storage setting is still `local`, rooted at `/var/lib/vikunja/files` on each backend instance. No EFS or S3 file-storage change has been made.

By “attachments” I mean files Vikunja stores through its file-storage subsystem. This includes task file uploads and the profile picture when the avatar provider is set to **Upload**. Those files are on one backend instance's disk, while account metadata is in shared RDS. With multiple backends, a later request can reach a different instance that does not have that file. This is why an uploaded picture could have worked on the old single-instance setup but may not be consistently available behind the new ASG. Gravatar, initials, and other non-upload avatar providers are not affected by this local-file limitation.

The S3 bucket already in the deployment is not configured for those uploads. In the pinned Vikunja version, its built-in S3 file driver requires access-key and secret-key settings rather than using the EC2 instance role directly, so I left storage unchanged instead of introducing credentials or a custom workaround. This can be revisited before deployment.

## Validation and what remains unverified

- The separate frontend and backend bundles were built locally.
- Terraform formatting and `terraform validate` pass; all four seeder unit tests pass.
- No AWS plan or apply, live deployment, multi-instance file test, or availability test has been performed. AWS permissions previously blocked an Availability Zone lookup.

## How a request and its data flow

1. A browser request reaches the public ALB.
2. The ALB sends ordinary page/static-asset requests to the frontend target group. Nginx serves the prebuilt static frontend.
3. Frontend API requests use the same origin. The ALB listener rule sends `/api/*`, `/dav*`, and `/.well-known/caldav*` to the backend target group on port 8080.
4. A backend Vikunja process handles the request and reads/writes account, project, task, and other application records in the private MySQL RDS instance.
5. Uploaded file bytes use Vikunja's file-storage backend. It is currently configured as local storage under `/var/lib/vikunja/files` on each backend EC2 instance, not in RDS and not in the artifact S3 bucket.

The backend launch template's user data downloads and verifies the backend bundle and runtime config, extracts the app, and starts `vikunja.service` plus `vikunja-seed.service`. The seed service runs on every new backend instance. Seeder retries are designed to be idempotent sequentially; simultaneous first-boot seed runs have not been stress-tested.

## What the scripts do

- `scripts/package-app.ps1` is the workstation packaging step. It removes previous Vikunja package outputs, downloads the pinned server/source archives, checks their SHA-256 values, installs the locked frontend dependencies, builds the static frontend, stages the frontend and backend contents separately, and creates the two tarballs. It cleans temporary source/staging directories after success. It requires Windows PowerShell, `tar.exe`, Node.js 24+, pnpm 12.16.1, and internet access.
- `scripts/create.sh` is a Bash deployment wrapper. It first requires both tarballs, then runs Terraform format-check, `init -upgrade`, validate, plan, and apply. It deletes `infra/tfplan` only after a successful apply. It does not package the app for you. AWS CLI credentials and a value for the required database password input are needed. Do not run it unless an AWS plan/apply is intended.
- `scripts/destroy.sh` runs `terraform destroy -auto-approve` against `infra/`. This removes the managed stack without a confirmation prompt. The database module does not retain a final snapshot, so destroying the stack loses database/demo/user data. Do not run it casually.
- Direct equivalents and the deployment URL lookup are in `README.md`. Terraform remote state is not configured; state and plan files are local and sensitive.

## S3 handoff for a future implementation

The existing S3 deployment path is read-only from the instances' perspective:

- `infra/main.tf` creates a private, encrypted artifact bucket, grants the existing `LabInstanceProfile` role `s3:GetObject` for the two bundles and runtime-config object, and uploads those objects.
- `infra/modules/network/main.tf` creates an S3 gateway endpoint for the public and private-app route tables. Its endpoint policy currently allows only `s3:GetObject` on those three exact artifact keys.
- `infra/modules/compute/main.tf` downloads those objects during instance bootstrap. Do not confuse that startup download path with Vikunja's user-upload storage.

In the pinned upstream v2.8.0 source, `pkg/files/filehandling.go` rejects missing S3 access-key/secret-key settings and constructs a static-credentials provider. Its file driver performs `GetObject`, `PutObject`, `HeadObject`, and `DeleteObject`; it does not use the EC2 role credential chain as currently written. Relevant upstream files: [S3 initialization](https://github.com/go-vikunja/vikunja/blob/v2.8.0/pkg/files/filehandling.go) and [S3 file operations](https://github.com/go-vikunja/vikunja/blob/v2.8.0/pkg/files/storage_s3.go).

Suggested implementation path for the next AI:

1. Keep the existing artifact bucket/prefix read-only and separate from user uploads. Prefer a dedicated private uploads bucket (or at least a tightly scoped prefix) with public access blocked and encryption enabled.
2. Change/rebuild the Vikunja backend so S3 configuration can use the AWS SDK default credential chain/EC2 instance role when explicit keys are absent. Do not put long-lived AWS keys in the repo, AMI, bundle, user data, or runtime config.
3. Configure Vikunja's file backend as `s3` with the bucket, `us-east-1` region, an S3 endpoint, and an uploads base path. Check the exact config names/defaults against pinned v2.8.0 source before editing Terraform.
4. Grant only the backend role the object permissions required on that upload bucket/prefix (`GetObject`, `PutObject`, `DeleteObject`; `HeadObject` is authorized by `GetObject`). Update the S3 gateway endpoint policy to allow those actions on only the upload objects, while preserving the existing artifact restrictions. Confirm no AWS Academy explicit deny blocks those operations.
5. Update `infra/main.tf` runtime config and Terraform bucket/policy resources. Update `scripts/package-app.ps1` to produce the modified API binary from the pinned source instead of only copying the official prebuilt release binary; keep the frontend bundle build separate.
6. Validate formatting, Terraform, backend/frontend packaging, and seeder tests. Test file storage initialization (Vikunja writes/removes a validation object), then upload and retrieve an avatar or task file while requests hit different backend instances. Do not apply to AWS without an approved plan and valid lab permissions.

The S3 gateway endpoint already exists and has no hourly endpoint charge. User-file S3 usage would add storage and request charges. EFS is an alternative that avoids changing Vikunja's storage driver but has a higher per-GB storage rate and may incur cross-AZ transfer charges.
