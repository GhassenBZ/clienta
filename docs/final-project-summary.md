# Project progress against the cahier des charges

L3 is the network and first-compute milestone, not the end of the project. This summary is based on the current repository; AWS deployment and live demonstration results are not verified here.

| Deliverable | Status | Summary |
|---|---|---|
| L1 — Subject and requirements | Not verified | The Clienta application is present, but the approved L1 subject record and measurable objectives are not documented in this repository. |
| L2 — Architecture and budget | Incomplete | Architecture and cost-driver notes exist. The required AWS Calculator estimate and configured budget alarm are not evidenced. |
| L3 — Network and compute | Mostly implemented | Multi-AZ VPC/subnets, security groups, one private EC2 instance, S3 gateway endpoint, Terraform modules, and a destroy script exist. State is local rather than shared and session-surviving. |
| L4 — High availability | Not complete | An ALB is provisioned, but listener, target group, health checks, Launch Template, and multi-AZ Auto Scaling are missing. No instance replacement demonstration is documented. |
| L5 — Data and backup | Partially implemented | Private RDS with app-SG-only ingress and an S3 deployment-artifact use exist. Automated backup configuration and restore/full-rebuild demonstrations are not evidenced. |
| L6 — Monitoring, security, and cost | Not complete | CloudWatch logs/dashboard/alarms are absent. Secret handling needs remediation; the Terraform DB password has a committed default and is placed in instance user data. Cost measurement and a quantified optimization are not documented. |
| L7 — Operations and defense | Not complete | A destroy script exists, but load/failure testing, incident report, final runbook, and live destroy/rebuild evidence are not documented. |

Use [architecture.md](./architecture.md) for the detailed implementation inventory and [cost-estimate.md](./cost-estimate.md) for current cost drivers and remaining L2 cost work.
