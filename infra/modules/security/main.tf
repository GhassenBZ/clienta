resource "aws_security_group" "app" {
  name        = "clienta-app-sg"
  description = "Security group for EC2 application instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow traffic from the ALB on application port"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  ingress {
    description = "Allow SSH from designated admin subnet or office range"
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
    Name    = "clienta-app-sg"
    Project = "clienta"
  }
}
