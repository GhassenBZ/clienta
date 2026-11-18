data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}

data "aws_caller_identity" "current" {}

locals {
  frontend_bundle_path   = "${path.root}/../build/vikunja-frontend.tar.gz"
  frontend_bundle_sha256 = filesha256(local.frontend_bundle_path)
  backend_bundle_path    = "${path.root}/../build/vikunja-backend.tar.gz"
  backend_bundle_sha256  = filesha256(local.backend_bundle_path)
  runtime_config_key     = "vikunja-runtime.json"
  runtime_config_content = jsonencode({
    service = {
      interface          = ":8080"
      publicurl          = "http://${module.network.alb_dns_name}/"
      enableregistration = true
      rootpath           = "/var/lib/vikunja"
      secret             = sha256("${var.db_password}:vikunja-jwt")
    }
    database = {
      type               = "mysql"
      host               = module.database.address
      user               = module.database.username
      password           = var.db_password
      database           = module.database.db_name
      tls                = "preferred"
      maxopenconnections = 10
      maxidleconnections = 5
    }
    files = {
      type     = "s3"
      basepath = "vikunja-files"
      s3 = {
        endpoint       = "https://s3.us-east-1.amazonaws.com"
        bucket         = "vikunja-uploads-${data.aws_caller_identity.current.account_id}"
        region         = "us-east-1"
        usepathstyle   = false
        disablesigning = false
      }
    }
  })
  runtime_config_sha256 = sha256(local.runtime_config_content)
}

resource "aws_cloudformation_stack" "artifacts" {
  name = "vikunja-artifacts-stack"

  template_body = jsonencode({
    Resources = {
      ArtifactBucket = {
        Type = "AWS::S3::Bucket"
        Properties = {
          BucketName = "vikunja-artifacts-${data.aws_caller_identity.current.account_id}"
          PublicAccessBlockConfiguration = {
            BlockPublicAcls       = true
            BlockPublicPolicy     = true
            IgnorePublicAcls      = true
            RestrictPublicBuckets = true
          }
          BucketEncryption = {
            ServerSideEncryptionConfiguration = [{
              ServerSideEncryptionByDefault = {
                SSEAlgorithm = "AES256"
              }
            }]
          }
          Tags = [
            { Key = "Name", Value = "vikunja-artifacts" },
            { Key = "Project", Value = "vikunja" },
          ]
        }
      }
      UploadBucket = {
        Type = "AWS::S3::Bucket"
        Properties = {
          BucketName = "vikunja-uploads-${data.aws_caller_identity.current.account_id}"
          PublicAccessBlockConfiguration = {
            BlockPublicAcls       = true
            BlockPublicPolicy     = true
            IgnorePublicAcls      = true
            RestrictPublicBuckets = true
          }
          BucketEncryption = {
            ServerSideEncryptionConfiguration = [{
              ServerSideEncryptionByDefault = {
                SSEAlgorithm = "AES256"
              }
            }]
          }
          Tags = [
            { Key = "Name", Value = "vikunja-uploads" },
            { Key = "Project", Value = "vikunja" },
          ]
        }
      }
      ArtifactBucketPolicy = {
        Type = "AWS::S3::BucketPolicy"
        Properties = {
          Bucket = { Ref = "ArtifactBucket" }
          PolicyDocument = {
            Version = "2012-10-17"
            Statement = [{
              Effect    = "Allow"
              Principal = { AWS = data.aws_iam_instance_profile.lab.role_arn }
              Action    = "s3:GetObject"
              Resource = [
                "arn:aws:s3:::vikunja-artifacts-${data.aws_caller_identity.current.account_id}/vikunja-frontend.tar.gz",
                "arn:aws:s3:::vikunja-artifacts-${data.aws_caller_identity.current.account_id}/vikunja-backend.tar.gz",
                "arn:aws:s3:::vikunja-artifacts-${data.aws_caller_identity.current.account_id}/${local.runtime_config_key}",
              ]
            }]
          }
        }
      }
      UploadBucketPolicy = {
        Type = "AWS::S3::BucketPolicy"
        Properties = {
          Bucket = { Ref = "UploadBucket" }
          PolicyDocument = {
            Version = "2012-10-17"
            Statement = [{
              Effect    = "Allow"
              Principal = { AWS = data.aws_iam_instance_profile.lab.role_arn }
              Action = [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
              ]
              Resource = "arn:aws:s3:::vikunja-uploads-${data.aws_caller_identity.current.account_id}/vikunja-files/*"
            }]
          }
        }
      }
    }
    Outputs = {
      ArtifactBucketName = { Value = { Ref = "ArtifactBucket" } }
      ArtifactBucketArn  = { Value = { "Fn::GetAtt" = ["ArtifactBucket", "Arn"] } }
      UploadBucketName   = { Value = { Ref = "UploadBucket" } }
      UploadBucketArn    = { Value = { "Fn::GetAtt" = ["UploadBucket", "Arn"] } }
    }
  })
}

resource "terraform_data" "upload_bucket_cleanup" {
  input = aws_cloudformation_stack.artifacts.outputs["UploadBucketName"]

  provisioner "local-exec" {
    when    = destroy
    command = "aws s3 rm s3://${self.input}/ --recursive --region us-east-1"
  }

  depends_on = [aws_cloudformation_stack.artifacts]
}

resource "aws_s3_object" "frontend" {
  bucket                 = aws_cloudformation_stack.artifacts.outputs["ArtifactBucketName"]
  key                    = "vikunja-frontend.tar.gz"
  source                 = local.frontend_bundle_path
  source_hash            = local.frontend_bundle_sha256
  server_side_encryption = "AES256"
  content_type           = "application/gzip"
}

resource "aws_s3_object" "backend" {
  bucket                 = aws_cloudformation_stack.artifacts.outputs["ArtifactBucketName"]
  key                    = "vikunja-backend.tar.gz"
  source                 = local.backend_bundle_path
  source_hash            = local.backend_bundle_sha256
  server_side_encryption = "AES256"
  content_type           = "application/gzip"
}

resource "aws_s3_object" "runtime_config" {
  bucket                 = aws_cloudformation_stack.artifacts.outputs["ArtifactBucketName"]
  key                    = local.runtime_config_key
  content                = local.runtime_config_content
  source_hash            = local.runtime_config_sha256
  server_side_encryption = "AES256"
  content_type           = "application/json"
}

module "network" {
  source = "./modules/network"

  artifact_bucket_arn = aws_cloudformation_stack.artifacts.outputs["ArtifactBucketArn"]
  upload_bucket_arn   = aws_cloudformation_stack.artifacts.outputs["UploadBucketArn"]
}

module "security" {
  source = "./modules/security"

  vpc_id                = module.network.vpc_id
  alb_security_group_id = module.network.alb_security_group_id
}

module "database" {
  source = "./modules/database"

  subnet_ids        = module.network.private_data_subnet_ids
  security_group_id = module.security.rds_security_group_id
  db_name           = "vikunja"
  db_username       = var.db_username
  db_password       = var.db_password
}

module "compute" {
  source = "./modules/compute"

  frontend_subnet_ids        = module.network.private_app_subnet_ids
  backend_subnet_ids         = module.network.private_app_subnet_ids
  frontend_security_group_id = module.security.frontend_security_group_id
  backend_security_group_id  = module.security.backend_security_group_id
  artifact_bucket_name       = aws_cloudformation_stack.artifacts.outputs["ArtifactBucketName"]
  frontend_bundle_key        = aws_s3_object.frontend.key
  backend_bundle_key         = aws_s3_object.backend.key
  runtime_config_key         = aws_s3_object.runtime_config.key
  frontend_bundle_sha256     = local.frontend_bundle_sha256
  backend_bundle_sha256      = local.backend_bundle_sha256
  runtime_config_sha256      = local.runtime_config_sha256
  instance_profile_name      = data.aws_iam_instance_profile.lab.name
  frontend_target_group_arn  = module.network.frontend_target_group_arn
  backend_target_group_arn   = module.network.backend_target_group_arn

  depends_on = [
    module.network,
    aws_s3_object.frontend,
    aws_s3_object.backend,
    aws_s3_object.runtime_config,
    module.database,
  ]
}
