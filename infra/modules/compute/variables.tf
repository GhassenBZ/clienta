variable "subnet_id" {
  description = "Private subnet where the application instance is placed."
  type        = string
}

variable "artifact_bucket_name" {
  description = "Private S3 bucket containing the packaged application."
  type        = string
}

variable "artifact_object_key" {
  description = "S3 object key for the packaged application."
  type        = string
}

variable "bundle_sha256" {
  description = "SHA-256 of the packaged application, used to redeploy on bundle changes."
  type        = string
}

variable "instance_profile_name" {
  description = "Existing AWS Academy instance profile used to read the application bundle."
  type        = string
}

variable "security_group_id" {
  description = "Security group for the application EC2 instance."
  type        = string
}
