output "instance_ids" {
  description = "The EC2 instance IDs created for the application layer."
  value       = [aws_instance.app.id]
}
