output "frontend_asg_name" {
  description = "Name of the static frontend Auto Scaling group."
  value       = aws_autoscaling_group.frontend.name
}

output "backend_asg_name" {
  description = "Name of the Vikunja API Auto Scaling group."
  value       = aws_autoscaling_group.backend.name
}
