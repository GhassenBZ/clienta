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
              chown -R ec2-user:ec2-user /opt/clienta

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
      Name         = "clienta-app-root"
      Project      = "clienta"
      BackupPolicy = "clienta-weekly"
    }
  }

  tags = {
    Name    = "clienta-app"
    Project = "clienta"
  }
}

resource "aws_iam_role" "dlm" {
  name = "clienta-dlm-lifecycle"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "dlm.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dlm" {
  role       = aws_iam_role.dlm.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "ebs_weekly" {
  description        = "Weekly Clienta EC2 root volume snapshots - retain two"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]
    target_tags = {
      BackupPolicy = "clienta-weekly"
    }

    schedule {
      name      = "Clienta weekly EBS snapshots"
      copy_tags = true

      create_rule {
        cron_expression = "cron(0 3 ? * SUN *)"
      }

      retain_rule {
        count = 2
      }

      tags_to_add = {
        SnapshotPolicy = "clienta-weekly"
      }
    }
  }

  depends_on = [aws_iam_role_policy_attachment.dlm]

  tags = {
    Name    = "clienta-weekly-ebs-snapshots"
    Project = "clienta"
  }
}
