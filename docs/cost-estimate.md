# Cost estimate and AWS constraints

- 1 x t3.micro EC2 instance
- Application Load Balancer
- EBS root volume for the EC2 instance
- Budget must be destroyed at end of session
- AWS Budgets only if available in the lab

## L3 cost scope

The L3 baseline does not create RDS, NAT gateways, S3 artifacts, custom AMIs, or CloudWatch alarms. The ALB and EC2 incur charges while they exist. Review the Terraform plan before applying and destroy the stack at the end of the lab session.
