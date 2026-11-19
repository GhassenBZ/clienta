variable "frontend_subnet_ids" {
  description = "Private frontend subnets used by the static frontend Auto Scaling group."
  type        = list(string)
}

variable "backend_subnet_ids" {
  description = "Private subnets used by the Vikunja API Auto Scaling group."
  type        = list(string)
}

variable "frontend_security_group_id" {
  description = "Security group for static frontend instances."
  type        = string
}

variable "backend_security_group_id" {
  description = "Security group for Vikunja API instances."
  type        = string
}

variable "artifact_bucket_name" {
  description = "Private S3 bucket containing the separate frontend, backend, and runtime bundles."
  type        = string
}

variable "frontend_bundle_key" {
  description = "S3 object key for the static frontend bundle."
  type        = string
}

variable "backend_bundle_key" {
  description = "S3 object key for the Vikunja API bundle."
  type        = string
}

variable "runtime_config_key" {
  description = "S3 object key for the private Vikunja runtime configuration."
  type        = string
}

variable "frontend_bundle_sha256" {
  description = "SHA-256 of the static frontend bundle, used to roll out bundle changes."
  type        = string
}

variable "backend_bundle_sha256" {
  description = "SHA-256 of the Vikunja API bundle, used to roll out bundle changes."
  type        = string
}

variable "runtime_config_sha256" {
  description = "SHA-256 of the private runtime configuration, used to redeploy on configuration changes."
  type        = string
}

variable "instance_profile_name" {
  description = "Existing AWS Academy instance profile used to read Vikunja assets."
  type        = string
}

variable "frontend_target_group_arn" {
  description = "ARN of the ALB target group for the static frontend."
  type        = string
}

variable "backend_target_group_arn" {
  description = "ARN of the ALB target group for the Vikunja API."
  type        = string
}

variable "internal_api_dns_name" {
  description = "Private DNS name of the internal ALB used by frontend instances to reach Vikunja."
  type        = string
}
