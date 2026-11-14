variable "db_username" {
  description = "Master username for the RDS database."
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password for the RDS database (at least 8 characters)."
  type        = string
  sensitive   = true
  default     = "Clienta2026Secure!"
}
