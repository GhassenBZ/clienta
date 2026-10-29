variable "subnet_id" {
  description = "Private subnet where the application instance is placed."
  type        = string
}

variable "builder_subnet_id" {
  description = "Public subnet where the temporary AMI builder is placed."
  type        = string
}

variable "security_group_id" {
  description = "Security group for the application EC2 instance."
  type        = string
}

variable "build_ami" {
  description = "Whether to create a temporary builder and a new application AMI."
  type        = bool
}

variable "ami_builder_instance_id" {
  description = "Source builder instance ID used to keep the AMI managed after builder cleanup."
  type        = string
}

variable "app_repository_ref" {
  description = "Public Git branch or tag containing the application source."
  type        = string
}
