variable "subnet_id" {
  description = "Private subnet where the application instance is placed."
  type        = string
}

variable "security_group_id" {
  description = "Security group for the application EC2 instance."
  type        = string
}
