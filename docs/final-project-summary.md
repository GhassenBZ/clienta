# Project progress against the cahier des charges

This repository branch now deploys Vikunja with real, database-backed demo accounts and project/task data. This summary records repository evidence only; AWS deployment and live demonstration results are not verified here.

| Deliverable | Status | Summary |
|---|---|---|
| L1 — Subject and requirements | Not verified | Vikunja is the selected workload and is implemented for hosting. The approved L1 subject record and measurable objectives are not documented in this repository. |
| L2 — Architecture and budget | Incomplete | The deployment topology and cost drivers are documented. The required AWS Calculator estimate and configured budget alarm are not evidenced. |
| L3 — Network and compute | Mostly implemented | Multi-AZ VPC/subnets, security groups, separate frontend/backend launch templates and Auto Scaling groups, S3 gateway endpoint, Terraform modules, and a destroy script exist. State is local rather than shared and session-surviving. |
| L4 — High availability | Configured; not demonstrated | The ALB routes frontend and API traffic separately; both ASGs have a minimum/desired capacity of two, CPU target tracking, health checks, and rolling instance refreshes. No AWS apply, load/failure test, or replacement demonstration has been completed. |
| L5 — Data and backup | Partially implemented | Private MySQL RDS, app-SG-only ingress, and private S3 storage for the bundle and runtime configuration exist. Automated backup configuration and restore/full-rebuild demonstrations are not evidenced. |
| L6 — Monitoring, security, and cost | Not complete | Credentials are not in source or EC2 user data; sensitive runtime configuration is stored in private S3 and Terraform state. CloudWatch logs/dashboard/operational alarms are absent (ASG target tracking creates AWS-managed scaling alarms). Cost measurement, quantified optimization, and SSH hardening are not documented. |
| L7 — Operations and defense | Not complete | A destroy script exists, but load/failure testing, an incident report, a final runbook, and live destroy/rebuild evidence are not documented. |

Use [architecture.md](./architecture.md) for the detailed implementation inventory and [cost-estimate.md](./cost-estimate.md) for current cost drivers and remaining L2 cost work.
