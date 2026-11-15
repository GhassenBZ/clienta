variable "subnet_id" {
  description = "Private subnet where the application instance is placed."
  type        = string
}

variable "security_group_id" {
  description = "Security group for the application EC2 instance."
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

variable "db_host" {
  description = "Database host address."
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Database name."
  type        = string
  default     = "clienta"
}

variable "db_user" {
  description = "Database username."
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database password."
  type        = string
  sensitive   = true
  default     = ""
}

variable "target_group_arn" {
  description = "ARN of the ALB target group to register the instance with."
  type        = string
}
