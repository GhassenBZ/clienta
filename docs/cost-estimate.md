# Cost estimate and AWS constraints

- 1 x t3.micro EC2 application instance
- 1 x db.t3.micro RDS MySQL instance
- Application Load Balancer (created, but not yet configured with a listener or target group)
- Encrypted gp3 EC2 root volume
- Private S3 deployment artifact and S3 gateway endpoint
- Budget must be destroyed at end of session
- AWS Budgets only if available in the lab

## Current cost scope and L2 budget work

The current Terraform branch creates the EC2 instance, RDS instance, ALB, private S3 artifact bucket, and S3 gateway endpoint. The gateway endpoint has no hourly charge; S3 storage and requests can incur small charges. No NAT gateway or custom AMI is created. The ALB, EC2, RDS, and EBS storage incur charges while they exist. The ALB has no listener or target group yet, and no automated EBS snapshot policy or CloudWatch alarms are configured. Review the plan before applying and destroy the stack at the end of the lab session.

The cahier des charges requires an AWS Calculator estimate and a budget alarm at L2. This file currently records cost drivers and the no-NAT design choice, but does not contain a calculator-based monthly estimate, a quantified optimization, or evidence that a budget alarm is configured. Those items remain outstanding.
