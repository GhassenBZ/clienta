# Vikunja AWS architecture

## Application

This branch packages the official Vikunja v2.8.0 browser frontend and API as separate deployment bundles. A bundled Python standard-library server serves the static frontend from a multi-AZ frontend Auto Scaling group in private application subnets; the Vikunja API runs in a separate multi-AZ backend Auto Scaling group. Account, project, and task records persist in MySQL on RDS. The backend first-boot seeder creates four real demo accounts, three shared projects, and 44 dated tasks with Kanban buckets, labels, assignments, and comments.

## Network and data path

The VPC uses `10.0.0.0/16` in `us-east-1` with two Availability Zones:

- public subnets: `10.0.1.0/24`, `10.0.2.0/24`;
- private application subnets: `10.0.11.0/24`, `10.0.12.0/24`;
- private data subnets: `10.0.21.0/24`, `10.0.22.0/24`.

The public Application Load Balancer accepts HTTP on port 80. It forwards ordinary browser paths to the frontend target group on port 80, and routes `/api/*`, `/dav*`, and `/.well-known/caldav*` to the private backend target group on port 8080. The frontend build leaves `window.API_URL` empty so browser API calls remain same-origin and are routed by the ALB. Frontend and backend health checks use `/health` and `/api/v1/info`, respectively. The RDS security group allows MySQL only from the backend security group. The S3 gateway endpoint lets the instances download their respective bundles and private runtime configuration without a NAT gateway.

## Current implementation

Terraform creates:

- the VPC, six subnets, internet gateway, and route tables;
- an internet-facing ALB, listener, frontend/backend target groups, API path rule, health checks, and tier security groups;
- separate frontend and backend launch templates and Auto Scaling groups, each with a desired/minimum capacity of two and maximum capacity of four across both AZs;
- CPU target-tracking policies for both groups and rolling instance refreshes when launch templates change;
- encrypted gp3 root volumes and the AWS Academy `LabInstanceProfile` for all instances;
- a private MySQL 8.0 RDS instance;
- an encrypted, private S3 bucket provisioned by a Terraform-managed CloudFormation stack.

The S3 bucket contains separately packaged frontend and backend bundles plus a JSON runtime configuration. The bucket policy and S3 endpoint restrict EC2 `GetObject` access to those three objects. The runtime configuration contains the RDS password and a stable Vikunja signing secret; backend instances download it at boot, so neither value is embedded in the repository or user data. Terraform state and the S3 object remain sensitive and must be kept private.

Frontend instances run the bundled Python static server under systemd with SPA fallback and a `/health` endpoint. Backend instances run the Vikunja server and a systemd oneshot seeder that uses the CLI and API to create demo accounts with public, disposable credentials and shared projects. Public registration is disabled. The seeder checks existing records to avoid duplicating data when instances are replaced but RDS remains.

## Limits and remaining work

- The frontend and backend groups each run at least two instances across the configured AZs. These settings are implemented in Terraform but have not been applied or demonstrated in AWS.
- Vikunja task attachments use local backend-instance storage; they are not shared across the backend ASG and do not survive instance replacement.
- The RDS module does not configure automated backup retention and skips a final snapshot. A full Terraform destroy removes the database; a fresh database is repopulated only with the sample seed.
- Terraform state is local rather than shared and session-surviving.
- CloudWatch log groups, dashboard, and operational alarms are not configured; target-tracking policies create AWS-managed scaling alarms. SSH is still allowed from the full VPC CIDR and should be narrowed.
- The previous `clienta-architecture-*.drawio` files are historical Clienta diagrams and do not describe the current Vikunja deployment.

## Progress against the cahier des charges

The brief defines seven sequential deliverables; L3 is an intermediate milestone, not the finished project. Repository evidence does not establish that a live AWS deployment, classroom demonstration, or approval has passed.

| Deliverable | Required outcome | Current evidence and status |
|---|---|---|
| L1 — Subject and requirements | Approved application choice, stakeholders, measurable objectives, high-level diagram | Vikunja is now the selected workload and is implemented for hosting. An L1 approval record and agreed measurable objectives are not documented here; status not verified. |
| L2 — Architecture and budget | Detailed target architecture, service decisions, AWS Calculator estimate, configured budget alarm | The deployment topology and cost drivers are documented, but a calculator-based estimate and configured budget alarm are not evidenced; incomplete. |
| L3 — Network and compute | Multi-AZ VPC/subnets, routing, security groups, first EC2, egress decision, IaC modules, state plan, destroy script | VPC, subnets, route tables, security groups, separate frontend/backend launch templates and ASGs, S3 gateway endpoint, modular Terraform, and a destroy script are present. The no-NAT egress choice is documented. Terraform state remains local; mostly implemented. |
| L4 — High availability | ALB health checks, multi-AZ Auto Scaling group with at least two instances, end-to-end availability, replacement demonstration | Separate frontend/backend ASGs have minimum/desired capacity two, target-tracking scaling policies, and rolling instance refresh configuration. No AWS apply, load/failure test, or replacement demonstration has been completed; implementation configured, operational evidence outstanding. |
| L5 — Data and backup | Private RDS, app-only database access, automated backups and demonstrated restore, real S3 use, full rebuild demonstration | Private RDS and app-SG-only database ingress are configured. S3 stores deployment artifacts and private runtime configuration. Backup retention and restore/full-rebuild demonstrations are not evidenced; partially implemented. |
| L6 — Monitoring, security, and cost | Centralized CloudWatch logs, dashboard, two working alarms, hardened security, secret management, measured cost and quantified optimization | Database credentials are no longer in source or EC2 user data, but the private runtime object and Terraform state contain sensitive values. Explicit monitoring resources, measured cost, and quantified optimization are absent; only AWS-managed scaling alarms are created. SSH scope remains broad. Not complete. |
| L7 — Operations and defense | Load/failure testing, incident report, finalized runbook, live destroy/rebuild and presentation | A destroy script exists, but load/failure tests, an incident report, an operations runbook, and live destroy/rebuild evidence are not documented. Not complete. |
