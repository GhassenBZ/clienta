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

resource "aws_launch_template" "frontend" {
  name_prefix   = "vikunja-frontend-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = var.instance_profile_name
  }

  network_interfaces {
    device_index                = 0
    associate_public_ip_address = false
    security_groups             = [var.frontend_security_group_id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              # bundle-sha256=${var.frontend_bundle_sha256}
              set -Eeuo pipefail
              exec > /var/log/vikunja-frontend-bootstrap.log 2>&1
              trap 'status=$?; echo "Vikunja frontend bootstrap failed with status $status"; exit "$status"' ERR

              mkdir -p /opt/vikunja/frontend /var/www/vikunja
              aws s3 cp "s3://${var.artifact_bucket_name}/${var.frontend_bundle_key}" /tmp/vikunja-frontend.tar.gz --region us-east-1
              echo "${var.frontend_bundle_sha256}  /tmp/vikunja-frontend.tar.gz" | sha256sum --check
              tar -xzf /tmp/vikunja-frontend.tar.gz -C /opt/vikunja/frontend
              cp -a /opt/vikunja/frontend/www/. /var/www/vikunja/
              dnf install -y --disablerepo='*' /opt/vikunja/frontend/nginx/nginx.rpm
              install -m 0644 /opt/vikunja/frontend/nginx/nginx.conf /etc/nginx/nginx.conf
              systemctl daemon-reload
              systemctl enable --now nginx.service
              rm -f /tmp/vikunja-frontend.tar.gz
              EOF
  )

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = "vikunja-frontend"
      Project = "vikunja"
      Tier    = "frontend"
    }
  }
}

resource "aws_launch_template" "backend" {
  name_prefix   = "vikunja-backend-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = var.instance_profile_name
  }

  vpc_security_group_ids = [var.backend_security_group_id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              # bundle-sha256=${var.backend_bundle_sha256}
              # runtime-config-sha256=${var.runtime_config_sha256}
              set -Eeuo pipefail
              exec > /var/log/vikunja-backend-bootstrap.log 2>&1
              trap 'status=$?; echo "Vikunja backend bootstrap failed with status $status"; exit "$status"' ERR

              useradd --system --user-group --home-dir /var/lib/vikunja --create-home --shell /sbin/nologin vikunja
              mkdir -p /opt/vikunja /etc/vikunja /var/lib/vikunja/files
              aws s3 cp "s3://${var.artifact_bucket_name}/${var.backend_bundle_key}" /tmp/vikunja-backend.tar.gz --region us-east-1
              echo "${var.backend_bundle_sha256}  /tmp/vikunja-backend.tar.gz" | sha256sum --check
              aws s3 cp "s3://${var.artifact_bucket_name}/${var.runtime_config_key}" /etc/vikunja/config.yml --region us-east-1
              echo "${var.runtime_config_sha256}  /etc/vikunja/config.yml" | sha256sum --check
              tar -xzf /tmp/vikunja-backend.tar.gz -C /opt/vikunja
              chmod 755 /opt/vikunja/vikunja/vikunja
              chown -R vikunja:vikunja /var/lib/vikunja
              chown root:vikunja /etc/vikunja /etc/vikunja/config.yml
              chmod 750 /etc/vikunja
              chmod 640 /etc/vikunja/config.yml

              cat > /etc/systemd/system/vikunja.service <<'SERVICE'
              [Unit]
              Description=Vikunja API
              After=network-online.target
              Wants=network-online.target

              [Service]
              Type=simple
              User=vikunja
              Group=vikunja
              WorkingDirectory=/var/lib/vikunja
              ExecStart=/opt/vikunja/vikunja/vikunja --config /etc/vikunja/config.yml
              Restart=on-failure
              RestartSec=5

              [Install]
              WantedBy=multi-user.target
              SERVICE

              cat > /etc/systemd/system/vikunja-seed.service <<'SERVICE'
              [Unit]
              Description=Seed persistent Vikunja demo accounts and projects
              Requires=vikunja.service
              After=vikunja.service
              StartLimitIntervalSec=0

              [Service]
              Type=oneshot
              User=vikunja
              Group=vikunja
              WorkingDirectory=/var/lib/vikunja
              ExecStart=/usr/bin/python3 /opt/vikunja/vikunja/seed-demo.py --url http://127.0.0.1:8080 --binary /opt/vikunja/vikunja/vikunja --config /etc/vikunja/config.yml
              TimeoutStartSec=10min
              Restart=on-failure
              RestartSec=30
              RemainAfterExit=yes

              [Install]
              WantedBy=multi-user.target
              SERVICE

              systemctl daemon-reload
              systemctl enable --now vikunja.service vikunja-seed.service
              rm -f /tmp/vikunja-backend.tar.gz
              EOF
  )

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = "vikunja-backend"
      Project = "vikunja"
      Tier    = "backend"
    }
  }
}

resource "aws_autoscaling_group" "frontend" {
  name                      = "vikunja-frontend-asg"
  min_size                  = 2
  desired_capacity          = 2
  max_size                  = 4
  vpc_zone_identifier       = var.frontend_subnet_ids
  target_group_arns         = [var.frontend_target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 300
  force_delete              = true

  launch_template {
    id      = aws_launch_template.frontend.id
    version = aws_launch_template.frontend.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      max_healthy_percentage = 150
      instance_warmup        = 300
    }
  }

  tag {
    key                 = "Name"
    value               = "vikunja-frontend"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "vikunja"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_group" "backend" {
  name                      = "vikunja-backend-asg"
  min_size                  = 2
  desired_capacity          = 2
  max_size                  = 4
  vpc_zone_identifier       = var.backend_subnet_ids
  target_group_arns         = [var.backend_target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 300
  force_delete              = true

  launch_template {
    id      = aws_launch_template.backend.id
    version = aws_launch_template.backend.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      max_healthy_percentage = 150
      instance_warmup        = 300
    }
  }

  tag {
    key                 = "Name"
    value               = "vikunja-backend"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "vikunja"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_policy" "frontend_cpu" {
  name                   = "vikunja-frontend-cpu"
  autoscaling_group_name = aws_autoscaling_group.frontend.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60
  }
}

resource "aws_autoscaling_policy" "backend_cpu" {
  name                   = "vikunja-backend-cpu"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60
  }
}
