output "endpoint" {
  description = "The connection endpoint for the RDS instance (host:port)."
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "The hostname of the RDS database instance."
  value       = aws_db_instance.main.address
}

output "port" {
  description = "The database port."
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "The database name."
  value       = aws_db_instance.main.db_name
}

output "username" {
  description = "The database master username."
  value       = aws_db_instance.main.username
}
