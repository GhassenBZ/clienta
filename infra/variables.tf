variable "db_username" {
  description = "Master username for the RDS database."
  type        = string
  default     = "vikunja_admin"
}

variable "db_password" {
  description = "Master password for RDS; use at least 16 characters and enter it at the Terraform prompt."
  type        = string
  sensitive   = true
}
