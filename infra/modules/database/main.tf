resource "aws_db_subnet_group" "main" {
  name        = "vikunja-rds-subnet-group"
  description = "Database subnet group for Vikunja private data subnets"
  subnet_ids  = var.subnet_ids

  tags = {
    Name    = "vikunja-rds-subnet-group"
    Project = "vikunja"
  }
}

resource "aws_db_instance" "main" {
  identifier                 = "vikunja-db"
  engine                     = "mysql"
  engine_version             = "8.0"
  instance_class             = var.instance_class
  allocated_storage          = var.allocated_storage
  storage_type               = "gp3"
  db_name                    = var.db_name
  username                   = var.db_username
  password                   = var.db_password
  db_subnet_group_name       = aws_db_subnet_group.main.name
  vpc_security_group_ids     = [var.security_group_id]
  publicly_accessible        = false
  multi_az                   = false
  skip_final_snapshot        = true
  auto_minor_version_upgrade = true
  deletion_protection        = false

  tags = {
    Name    = "vikunja-db"
    Project = "vikunja"
  }
}
