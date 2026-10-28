# Cost estimate and AWS constraints

- 2 x t3.micro EC2 instances
- 1 x db.t3.micro RDS instance
- ALB and CloudWatch costs tracked
- S3 bucket for project artifacts
- Budget must be destroyed at end of session
- AWS Budgets only if available in the lab

## S3 bundle and egress

Terraform uploads a compressed deployment bundle (application, production dependencies, and Node.js runtime) to a private S3 bucket. The private app subnet reaches only that bucket through an S3 gateway endpoint. Gateway endpoints have no hourly or data-processing charge; the small bundle incurs S3 storage and request charges while the lab exists.

Packaging and dependency downloads happen on the developer workstation, not in AWS. A bundle change causes Terraform to upload the new object and replace the app instance. Terraform destroy removes the object, bucket, and gateway endpoint. No NAT gateway or temporary builder instance is created.
