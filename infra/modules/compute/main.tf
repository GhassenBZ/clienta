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

resource "aws_instance" "image_builder" {
  count = var.build_ami ? 1 : 0

  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  subnet_id                   = var.builder_subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/templates/image-builder.sh.tftpl", {
    app_repository_ref = var.app_repository_ref
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name    = "clienta-image-builder"
    Project = "clienta"
    Role    = "temporary-image-builder"
  }
}

resource "terraform_data" "wait_for_image_builder" {
  count = var.build_ami ? 1 : 0

  input = aws_instance.image_builder[0].id

  provisioner "local-exec" {
    command = "& '${replace(path.module, "/", "\\")}\\..\\..\\..\\scripts\\wait-for-image-builder.ps1' -InstanceId '${self.input}'"
    interpreter = [
      "PowerShell",
      "-NoProfile",
      "-NonInteractive",
      "-ExecutionPolicy",
      "Bypass",
      "-Command",
    ]
  }
}

resource "aws_ami_from_instance" "app" {
  count = var.build_ami || var.ami_builder_instance_id != "" ? 1 : 0

  name                    = "clienta-app-${var.build_ami ? aws_instance.image_builder[0].id : var.ami_builder_instance_id}"
  source_instance_id      = var.build_ami ? aws_instance.image_builder[0].id : var.ami_builder_instance_id
  snapshot_without_reboot = true

  tags = {
    Name    = "clienta-app"
    Project = "clienta"
    Role    = "application-image"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [terraform_data.wait_for_image_builder]
}

resource "aws_instance" "app" {
  ami = var.build_ami || var.ami_builder_instance_id != "" ? (
    aws_ami_from_instance.app[0].id
  ) : data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  root_block_device {
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name    = "clienta-app"
    Project = "clienta"
  }
}
