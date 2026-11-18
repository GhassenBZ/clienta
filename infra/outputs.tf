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

output "frontend_asg_name" {
  description = "Name of the static frontend Auto Scaling group."
  value       = module.compute.frontend_asg_name
}

output "backend_asg_name" {
  description = "Name of the Vikunja API Auto Scaling group."
  value       = module.compute.backend_asg_name
}

output "artifact_bucket_name" {
  description = "Private S3 bucket containing separate frontend, backend, and runtime bundles."
  value       = aws_cloudformation_stack.artifacts.outputs["ArtifactBucketName"]
}

output "upload_bucket_name" {
  description = "Private S3 bucket containing Vikunja uploaded files."
  value       = aws_cloudformation_stack.artifacts.outputs["UploadBucketName"]
}

output "s3_gateway_endpoint_id" {
  description = "S3 gateway endpoint for private application subnet access."
  value       = module.network.s3_gateway_endpoint_id
}

output "rds_security_group_id" {
  description = "Security group ID protecting the private RDS instance."
  value       = module.security.rds_security_group_id
}

output "rds_endpoint" {
  description = "Connection endpoint for the RDS MySQL instance."
  value       = module.database.endpoint
}
