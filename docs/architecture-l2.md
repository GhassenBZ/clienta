# L2 architecture draft

- VPC with public and private subnets
- ALB as public entry point
- EC2 application tier in private subnets
- RDS in private data subnet
- S3 for artifacts and state backup
- CloudWatch logs, metrics and alarms
