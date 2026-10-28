output "vpc_id" {
  description = "The ID of the created VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs of the private application subnets."
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "IDs of the private data subnets."
  value       = aws_subnet.private_data[*].id
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer."
  value       = aws_lb.main.dns_name
}

output "alb_security_group_id" {
  description = "Security group ID used by the public application load balancer."
  value       = aws_security_group.alb.id
}
