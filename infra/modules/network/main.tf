data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "clienta-vpc"
    Project = "clienta"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "clienta-igw"
    Project = "clienta"
  }
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = ["10.0.1.0/24", "10.0.2.0/24"][count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "clienta-public-${count.index + 1}"
    Project = "clienta"
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
    Name    = "clienta-app-${count.index + 1}"
    Project = "clienta"
    Tier    = "private-app"
  }
}

resource "aws_subnet" "private_data" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = ["10.0.21.0/24", "10.0.22.0/24"][count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name    = "clienta-data-${count.index + 1}"
    Project = "clienta"
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
    Name    = "clienta-public-rt"
    Project = "clienta"
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
    Name    = "clienta-private-app-rt"
    Project = "clienta"
  }
}

resource "aws_route_table_association" "private_app" {
  count = length(aws_subnet.private_app)

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_app.id]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${var.artifact_bucket_arn}/clienta-app.tar.gz"
    }]
  })

  tags = {
    Name    = "clienta-s3-gateway-endpoint"
    Project = "clienta"
  }
}

resource "aws_security_group" "alb" {
  name        = "clienta-alb-sg"
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
    Name    = "clienta-alb-sg"
    Project = "clienta"
  }
}

resource "aws_lb" "main" {
  name               = "clienta-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name    = "clienta-alb"
    Project = "clienta"
  }
}
