output "instance_ids" {
  description = "Application EC2 instance ID."
  value       = [aws_instance.app.id]
}

output "app_ami_id" {
  description = "AMI used by the private application EC2 instance."
  value       = aws_instance.app.ami
}

output "image_builder_instance_id" {
  description = "Temporary AMI builder ID; save it locally before the cleanup apply."
  value       = var.build_ami ? aws_instance.image_builder[0].id : var.ami_builder_instance_id
}
