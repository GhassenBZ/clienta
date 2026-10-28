output "vpc_id" {
  description = "Created VPC ID."
  value       = module.network.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the ALB."
  value       = module.network.alb_dns_name
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.network.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of the private application subnets."
  value       = module.network.private_app_subnet_ids
}

output "instance_ids" {
  description = "EC2 instance IDs created for the application layer."
  value       = module.compute.instance_ids
}

output "snapshot_policy_id" {
  description = "Data Lifecycle Manager policy ID for weekly EBS snapshots."
  value       = module.compute.snapshot_policy_id
}

output "artifact_bucket_name" {
  description = "Private S3 bucket containing the packaged application."
  value       = aws_s3_bucket.artifacts.id
}

output "s3_gateway_endpoint_id" {
  description = "S3 gateway endpoint for private application subnet access."
  value       = module.network.s3_gateway_endpoint_id
}

output "rds_security_group_id" {
  description = "Security group ID reserved for the future RDS instance."
  value       = module.security.rds_security_group_id
}
