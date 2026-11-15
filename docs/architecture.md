# Clienta AWS architecture

## L1 scope

Clienta is a customer-management application with:

- a browser frontend;
- an Express REST API;
- a MySQL persistence layer.

The target is a reproducible three-tier AWS deployment using services allowed by the project brief and suitable for an AWS Academy lab account.

## L2 target architecture

See the [full target-state diagram](./clienta-architecture-target.drawio).

The target design separates the tiers:

1. **Presentation tier:** public HTTP entry point through an Application Load Balancer.
2. **Application tier:** EC2 instances in private application subnets.
3. **Data tier:** MySQL on RDS in private data subnets.

The VPC uses `10.0.0.0/16` in `us-east-1` with two Availability Zones:

- public subnets: `10.0.1.0/24`, `10.0.2.0/24`;
- private application subnets: `10.0.11.0/24`, `10.0.12.0/24`;
- private data subnets: `10.0.21.0/24`, `10.0.22.0/24`.

Security groups are tier-oriented. Internet traffic reaches the ALB on HTTP, and the application security group accepts application traffic from the ALB security group. SSH is restricted to the VPC CIDR in this lab baseline and should be narrowed further before any non-lab use.

## Current implementation

The current Terraform configuration creates:

- the VPC and DNS support;
- two public, two private application, and two private data subnets;
- an internet gateway and public route table;
- an internet-facing ALB and its security group, but no ALB listener or target group yet;
- an application security group and an RDS security group attached to a private MySQL RDS instance, allowing MySQL only from the application security group;
- a private S3 bucket provisioned by a Terraform-managed CloudFormation stack, containing the packaged app, production dependencies, and Linux Node.js runtime;
- an S3 gateway endpoint on the private application route table, allowing the app instance to fetch the bundle without NAT;
- one EC2 application instance in the first private application subnet, with an encrypted gp3 root EBS volume and the AWS Academy instance profile. The Express process serves both the frontend files and API from this instance.

Run `scripts/package-app.ps1` before Terraform planning. It installs production dependencies locally, adds a checksum-verified Linux Node.js runtime, and creates the deployment archive while excluding `.env` files. Terraform uploads the archive; the bucket policy grants the existing `LabInstanceProfile` role `GetObject` access to that artifact, and the private S3 gateway endpoint has no hourly charge. In the current Learner Lab, provisioning the bucket through the CloudFormation stack succeeded. CloudFormation does not bypass IAM restrictions; the operations still depend on the caller's effective permissions. The template does not enable S3 Object Lock. The instance requires no NAT route or internet access for bootstrapping. Destroy removes the EC2 instance, endpoint, bucket, and artifact.

S3 is currently used for deployment artifacts, not for serving the browser frontend. The frontend and backend are not deployed to separate instances. The ALB cannot serve application traffic until its listener and target group are added. Automated EBS snapshots through Data Lifecycle Manager are not configured in this branch; the encrypted root volume alone does not create snapshots. CloudWatch log groups and alarms are also not configured yet.

## Progress against the cahier des charges

The brief defines seven sequential deliverables; L3 is an intermediate milestone, not the finished project. The table below assesses repository evidence only. Live demonstrations, AWS resources, and approvals must be verified separately.

| Deliverable | Required outcome | Current evidence and status |
|---|---|---|
| L1 — Subject and requirements | Approved application choice, stakeholders, measurable objectives, high-level diagram | The Clienta app exists in the repository. An L1 approval record and agreed measurable objectives are not documented here; status not verified. |
| L2 — Architecture and budget | Detailed target architecture, service decisions, AWS Calculator estimate, configured budget alarm | Architecture and cost notes exist, but a calculator-based estimate and configured budget alarm are not evidenced; incomplete. |
| L3 — Network and compute | Multi-AZ VPC/subnets, routing, security groups, first EC2, egress decision, IaC modules, state plan, destroy script | VPC, subnets, route tables, security groups, one private EC2 instance, S3 gateway endpoint, modular Terraform, and a destroy script are present. The no-NAT egress choice is documented. Terraform state is local, so the brief's shared, session-surviving state requirement is not met. Mostly implemented. |
| L4 — High availability | ALB health checks, multi-AZ Auto Scaling group with at least two instances, end-to-end availability, replacement demonstration | The ALB resource exists, but there is no listener, target group, health check, Launch Template, or Auto Scaling group. No replacement demonstration is evidenced. Not complete. |
| L5 — Data and backup | Private RDS, app-only database access, automated backups and demonstrated restore, real S3 use, full rebuild demonstration | Private RDS and app-SG-only database ingress are configured. S3 is used for deployment artifacts, satisfying a real S3 use in the design. Backup retention is not explicitly configured in Terraform, and restore/full-rebuild demonstrations are not evidenced. Partially implemented. |
| L6 — Monitoring, security, and cost | Centralized CloudWatch logs, dashboard, two working alarms, hardened security, secret management, measured cost and quantified optimization | CloudWatch resources are absent. SSH currently allows the whole VPC CIDR. A database password has a committed Terraform default and is rendered into EC2 user data; this does not meet the brief's secret-handling requirement. No measured cost report or quantified optimization is evidenced. Not complete; address the secret handling before deployment or presentation. |
| L7 — Operations and defense | Load/failure testing, incident report, finalized runbook, live destroy/rebuild and presentation | A destroy script exists, but load/failure tests, an incident report, an operations runbook, and live destroy/rebuild evidence are not documented. Not complete. |

These are implementation-status findings, not claims that a live AWS deployment or classroom demonstration has passed.
