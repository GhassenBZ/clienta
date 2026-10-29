output "instance_ids" {
  description = "Application EC2 instance ID."
  value       = [aws_instance.app.id]
}
