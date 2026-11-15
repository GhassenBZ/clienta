output "frontend_security_group_id" {
  description = "Security group ID for frontend Auto Scaling instances."
  value       = aws_security_group.frontend.id
}

output "backend_security_group_id" {
  description = "Security group ID for Vikunja API Auto Scaling instances."
  value       = aws_security_group.backend.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS; permits MySQL only from the application security group."
  value       = aws_security_group.rds.id
}
