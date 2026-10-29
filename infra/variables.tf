variable "build_ami" {
  description = "Create a temporary public EC2 instance and build a new application AMI."
  type        = bool
  default     = false
}

variable "ami_builder_instance_id" {
  description = "Source builder instance ID for the retained AMI after the temporary builder is destroyed."
  type        = string
  default     = ""
}

variable "app_repository_ref" {
  description = "Public Git branch or tag to install into the application AMI."
  type        = string
  default     = "main"
}
