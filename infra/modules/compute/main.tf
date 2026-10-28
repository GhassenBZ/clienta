resource "aws_instance" "app" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t3.micro"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

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

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y git nodejs npm
              git clone https://github.com/GhassenBZ/clienta.git /opt/clienta
              cd /opt/clienta/app/backend
              npm install
              nohup npm start > /tmp/clienta.log 2>&1 &
              EOF

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
