data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}

data "aws_caller_identity" "current" {}

locals {
  app_bundle_path   = "${path.root}/../build/clienta-app.tar.gz"
  app_bundle_sha256 = filesha256(local.app_bundle_path)
}

resource "aws_cloudformation_stack" "artifacts" {
  name = "clienta-artifacts-stack"

  template_body = jsonencode({
    Resources = {
      ArtifactBucket = {
        Type = "AWS::S3::Bucket"
        Properties = {
          BucketName = "clienta-artifacts-${data.aws_caller_identity.current.account_id}"
          PublicAccessBlockConfiguration = {
            BlockPublicAcls       = true
            BlockPublicPolicy     = true
            IgnorePublicAcls      = true
            RestrictPublicBuckets = true
          }
          BucketEncryption = {
            ServerSideEncryptionConfiguration = [
              {
                ServerSideEncryptionByDefault = {
                  SSEAlgorithm = "AES256"
                }
              }
            ]
          }
          Tags = [
            {
              Key   = "Name"
              Value = "clienta-artifacts"
            },
            {
              Key   = "Project"
              Value = "clienta"
            }
          ]
        }
      }
      ArtifactBucketPolicy = {
        Type = "AWS::S3::BucketPolicy"
        Properties = {
          Bucket = {
            Ref = "ArtifactBucket"
          }
          PolicyDocument = {
            Version = "2012-10-17"
            Statement = [
              {
                Effect = "Allow"
                Principal = {
                  AWS = data.aws_iam_instance_profile.lab.role_arn
                }
                Action   = "s3:GetObject"
                Resource = "arn:aws:s3:::clienta-artifacts-${data.aws_caller_identity.current.account_id}/clienta-app.tar.gz"
              }
            ]
          }
        }
      }
    }
    Outputs = {
      BucketName = {
        Value = {
          Ref = "ArtifactBucket"
        }
      }
      BucketArn = {
        Value = {
          "Fn::GetAtt" = ["ArtifactBucket", "Arn"]
        }
      }
    }
  })
}

resource "aws_s3_object" "app" {
  bucket                 = aws_cloudformation_stack.artifacts.outputs["BucketName"]
  key                    = "clienta-app.tar.gz"
  source                 = local.app_bundle_path
  source_hash            = local.app_bundle_sha256
  server_side_encryption = "AES256"
  content_type           = "application/gzip"
}

module "network" {
  source = "./modules/network"

  artifact_bucket_arn = aws_cloudformation_stack.artifacts.outputs["BucketArn"]
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
  db_name           = "clienta"
  db_username       = var.db_username
  db_password       = var.db_password
}

module "compute" {
  source = "./modules/compute"

  subnet_id             = module.network.private_app_subnet_ids[0]
  security_group_id     = module.security.app_security_group_id
  artifact_bucket_name  = aws_cloudformation_stack.artifacts.outputs["BucketName"]
  artifact_object_key   = aws_s3_object.app.key
  bundle_sha256         = local.app_bundle_sha256
  instance_profile_name = data.aws_iam_instance_profile.lab.name
  db_host               = module.database.address
  db_name               = module.database.db_name
  db_user               = module.database.username
  db_password           = var.db_password

  depends_on = [
    module.network,
    aws_s3_object.app,
    module.database,
  ]
}
