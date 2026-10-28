output "instance_ids" {
  description = "The EC2 instance IDs created for the application layer."
  value       = [aws_instance.app.id]
}

output "snapshot_policy_id" {
  description = "The Data Lifecycle Manager policy ID for weekly EBS snapshots."
  value       = aws_dlm_lifecycle_policy.ebs_weekly.id
}
