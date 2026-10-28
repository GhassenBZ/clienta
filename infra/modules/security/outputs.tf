output "app_security_group_id" {
  description = "Security group ID for EC2 application instances."
  value       = aws_security_group.app.id
}
