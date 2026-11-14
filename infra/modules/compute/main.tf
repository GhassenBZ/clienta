data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  iam_instance_profile        = var.instance_profile_name
  user_data_replace_on_change = true

  user_data = <<-EOF
              #!/bin/bash
              # bundle-sha256=${var.bundle_sha256}
              set -Eeuo pipefail
              exec > /var/log/clienta-bootstrap.log 2>&1
              trap 'status=$?; echo "Clienta bootstrap failed with status $status"; exit "$status"' ERR

              mkdir -p /opt/clienta
              aws s3 cp "s3://${var.artifact_bucket_name}/${var.artifact_object_key}" /tmp/clienta-app.tar.gz --region us-east-1
              tar -xzf /tmp/clienta-app.tar.gz -C /opt/clienta
              chmod 755 /opt/clienta/runtime/node

              cat > /opt/clienta/app/backend/.env <<ENV
              PORT=8080
              DB_HOST=${var.db_host}
              DB_USER=${var.db_user}
              DB_PASSWORD=${var.db_password}
              DB_NAME=${var.db_name}
              DB_PORT=3306
              ENV

              chown -R ec2-user:ec2-user /opt/clienta
              chmod 600 /opt/clienta/app/backend/.env

              cat > /etc/systemd/system/clienta.service <<'SERVICE'
              [Unit]
              Description=Clienta application
              After=network-online.target
              Wants=network-online.target

              [Service]
              Type=simple
              User=ec2-user
              WorkingDirectory=/opt/clienta/app/backend
              ExecStart=/opt/clienta/runtime/node /opt/clienta/app/backend/app.js
              Restart=on-failure
              RestartSec=5

              [Install]
              WantedBy=multi-user.target
              SERVICE

              systemctl daemon-reload
              systemctl enable --now clienta.service
              rm -f /tmp/clienta-app.tar.gz
              EOF

  root_block_device {
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name    = "clienta-app-root"
      Project = "clienta"
    }
  }

  tags = {
    Name    = "clienta-app"
    Project = "clienta"
  }
}
