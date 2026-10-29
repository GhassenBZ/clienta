# Cost estimate and AWS constraints

- 1 x t3.micro EC2 instance
- Application Load Balancer
- EBS root volume for the EC2 instance
- Budget must be destroyed at end of session
- AWS Budgets only if available in the lab

## L3 cost scope

The current baseline creates an ALB, a private application EC2 instance, and a temporary public EC2 builder when `build_ami=true`. The builder runs only during image creation and should be removed with the follow-up apply. The custom AMI and its backing EBS snapshot storage can continue to incur charges after the builder is removed. Review the Terraform plan before applying and destroy the stack, including the managed AMI, at the end of the lab session.

RDS, NAT gateways, S3 artifacts, CloudWatch alarms, and Auto Scaling are not currently created.
