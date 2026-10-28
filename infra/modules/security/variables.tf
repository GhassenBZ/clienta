variable "vpc_id" {
  description = "The VPC ID to attach security groups to."
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID used by the public application load balancer."
  type        = string
}
