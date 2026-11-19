data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "vikunja-vpc"
    Project = "vikunja"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "vikunja-igw"
    Project = "vikunja"
  }
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = ["10.0.1.0/24", "10.0.2.0/24"][count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "vikunja-public-${count.index + 1}"
    Project = "vikunja"
    Tier    = "public"
  }
}

resource "aws_subnet" "private_app" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = ["10.0.11.0/24", "10.0.12.0/24"][count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name    = "vikunja-app-${count.index + 1}"
    Project = "vikunja"
    Tier    = "private-app"
  }
}

resource "aws_subnet" "private_backend" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = ["10.0.31.0/24", "10.0.32.0/24"][count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name    = "vikunja-backend-app-${count.index + 1}"
    Project = "vikunja"
    Tier    = "private-backend"
  }
}

resource "aws_subnet" "private_data" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = ["10.0.21.0/24", "10.0.22.0/24"][count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name    = "vikunja-data-${count.index + 1}"
    Project = "vikunja"
    Tier    = "private-data"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "vikunja-public-rt"
    Project = "vikunja"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "vikunja-private-app-rt"
    Project = "vikunja"
  }
}

resource "aws_route_table_association" "private_app" {
  count = length(aws_subnet.private_app)

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table" "private_backend" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "vikunja-private-backend-rt"
    Project = "vikunja"
  }
}

resource "aws_route_table_association" "private_backend" {
  count = length(aws_subnet.private_backend)

  subnet_id      = aws_subnet.private_backend[count.index].id
  route_table_id = aws_route_table.private_backend.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id, aws_route_table.private_app.id, aws_route_table.private_backend.id]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = [
          "${var.artifact_bucket_arn}/vikunja-frontend.tar.gz",
          "${var.artifact_bucket_arn}/vikunja-backend.tar.gz",
          "${var.artifact_bucket_arn}/vikunja-runtime.json",
        ]
      },
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.upload_bucket_arn}/vikunja-files/*"
      }
    ]
  })

  tags = {
    Name    = "vikunja-s3-gateway-endpoint"
    Project = "vikunja"
  }
}

resource "aws_security_group" "alb" {
  name        = "vikunja-alb-sg"
  description = "Public ALB security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "vikunja-alb-sg"
    Project = "vikunja"
  }
}

resource "aws_security_group" "internal_alb" {
  name        = "vikunja-internal-alb-sg"
  description = "Private API load balancer security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow API traffic from private frontend subnets"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.11.0/24", "10.0.12.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "vikunja-internal-alb-sg"
    Project = "vikunja"
  }
}

resource "aws_lb" "main" {
  name               = "vikunja-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name    = "vikunja-alb"
    Project = "vikunja"
  }
}

resource "aws_lb_target_group" "frontend" {
  name        = "vikunja-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name    = "vikunja-frontend-tg"
    Project = "vikunja"
  }
}

resource "aws_lb_target_group" "backend" {
  name        = "vikunja-backend-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/api/v1/info"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

}

resource "aws_lb" "internal" {
  name               = "vikunja-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal_alb.id]
  subnets            = aws_subnet.private_app[*].id

  tags = {
    Name    = "vikunja-internal-alb"
    Project = "vikunja"
  }
}

resource "aws_lb_listener" "internal" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  tags = {
    Name    = "vikunja-http-listener"
    Project = "vikunja"
  }
}
