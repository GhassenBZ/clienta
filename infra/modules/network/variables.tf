variable "artifact_bucket_arn" {
  description = "ARN of the private S3 bucket restricted by the gateway endpoint policy."
  type        = string
}

variable "upload_bucket_arn" {
  description = "ARN of the private Vikunja upload bucket."
  type        = string
}
