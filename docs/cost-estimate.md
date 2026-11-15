# Cost estimate and AWS constraints

- 2 x `t3.micro` frontend EC2 instances at ASG baseline; scales to 4
- 2 x `t3.micro` backend EC2 instances at ASG baseline; scales to 4
- 1 x `db.t3.micro` RDS MySQL instance
- Application Load Balancer with listener and target group
- Encrypted gp3 EC2 root volume
- Private S3 deployment bundle and runtime configuration, plus an S3 gateway endpoint
- No NAT gateway or custom AMI

## Current cost scope and L2 budget work

The current Terraform branch creates four baseline EC2 instances across the two ASGs (with target-tracking scale-out up to eight total), one RDS instance, an ALB, a private S3 artifact bucket, and an S3 gateway endpoint. The gateway endpoint has no hourly charge; S3 storage and requests can incur small charges. The ALB, EC2, RDS, and EBS storage incur charges while they exist. No automated RDS backup retention, final snapshot, CloudWatch log groups, dashboard, or operational alarms are configured; ASG target tracking creates AWS-managed scaling alarms. Review the full plan and AWS Academy budget before applying; destroy the stack at the end of the lab session.

The cahier des charges requires an AWS Calculator estimate and a budget alarm at L2. This file currently records cost drivers and the no-NAT design choice, but does not contain a calculator-based monthly estimate, a quantified optimization, or evidence that a budget alarm is configured. Those items remain outstanding.
