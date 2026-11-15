variable "subnet_ids" {
  description = "Private data subnets for the RDS subnet group."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID allowing MySQL traffic from application instances."
  type        = string
}

variable "db_name" {
  description = "Name of the default database to create."
  type        = string
  default     = "vikunja"
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password for the RDS instance."
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS database instance class (AWS Academy Free Tier compatible)."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in gigabytes."
  type        = number
  default     = 20
}
