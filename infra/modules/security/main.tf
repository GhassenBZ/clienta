resource "aws_security_group" "frontend" {
  name        = "vikunja-frontend-sg"
  description = "Security group for frontend Auto Scaling instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow HTTP traffic from the ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "vikunja-frontend-sg"
    Project = "vikunja"
  }
}

resource "aws_security_group" "backend" {
  name        = "vikunja-backend-sg"
  description = "Security group for Vikunja API Auto Scaling instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow API traffic from the internal ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.internal_alb_security_group_id]
  }

  ingress {
    description = "Allow SSH from the VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "vikunja-backend-sg"
    Project = "vikunja"
  }
}

resource "aws_security_group" "rds" {
  name        = "vikunja-rds-sg"
  description = "Allow MySQL access only from the Vikunja API security group"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from Vikunja API instances"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  tags = {
    Name    = "vikunja-rds-sg"
    Project = "vikunja"
  }
}
