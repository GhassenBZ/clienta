
data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}

locals {
  app_bundle_path   = "${path.root}/../build/clienta-app.tar.gz"
  app_bundle_sha256 = filesha256(local.app_bundle_path)

  # Existing S3 bucket created previously
  artifact_bucket_name = "clienta-artifacts-20261114164802640300000001"
  artifact_bucket_arn  = "arn:aws:s3:::${local.artifact_bucket_name}"
}


resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = local.artifact_bucket_name

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = local.artifact_bucket_name

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


resource "aws_s3_bucket_policy" "artifacts" {
  bucket = local.artifact_bucket_name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        AWS = data.aws_iam_instance_profile.lab.role_arn
      }

      Action = "s3:GetObject"

      Resource = "${local.artifact_bucket_arn}/clienta-app.tar.gz"
    }]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.artifacts
  ]
}


resource "aws_s3_object" "app" {
  bucket                 = local.artifact_bucket_name
  key                    = "clienta-app.tar.gz"
  source                 = local.app_bundle_path
  source_hash            = local.app_bundle_sha256
  server_side_encryption = "AES256"
  content_type           = "application/gzip"
}


module "network" {
  source = "./modules/network"

  artifact_bucket_arn = local.artifact_bucket_arn
}


module "security" {
  source = "./modules/security"

  vpc_id                = module.network.vpc_id
  alb_security_group_id = module.network.alb_security_group_id
}



module "compute" {
  source = "./modules/compute"

  subnet_id         = module.network.private_app_subnet_ids[0]
  security_group_id = module.security.app_security_group_id

  artifact_bucket_name = local.artifact_bucket_name
  artifact_object_key  = aws_s3_object.app.key
  bundle_sha256        = local.app_bundle_sha256

  instance_profile_name = data.aws_iam_instance_profile.lab.name

  depends_on = [
    module.network,
    aws_s3_bucket_policy.artifacts,
    aws_s3_object.app
  ]
}
