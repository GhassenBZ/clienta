# Clienta – S3-Based Application Deployment Without NAT

## 1. Overview

This solution deploys the Clienta application on an EC2 instance located in a private subnet, without requiring a NAT Gateway or NAT Instance for application package retrieval.

Instead of downloading the application directly from the Internet, we store the application package in a private Amazon S3 bucket and use an S3 Gateway VPC Endpoint to provide private connectivity between EC2 and S3.

## 2. Architecture

The deployment workflow is:

1. Package the application locally into `clienta-app.tar.gz`.
2. Upload the package to a private Amazon S3 bucket.
3. Configure an S3 Gateway VPC Endpoint in the VPC.
4. Launch an EC2 instance in a private application subnet.
5. During EC2 initialization, the User Data script downloads the package from S3.
6. Extract the package and start the Clienta application using systemd.

**Network flow:**

`Private EC2 → S3 Gateway VPC Endpoint → Amazon S3`

No NAT Gateway or NAT Instance is required for this S3 communication.

## 3. AWS Components

| Component | Purpose |
|---|---|
| Amazon S3 | Stores the packaged application |
| S3 Gateway VPC Endpoint | Provides private connectivity to S3 |
| Amazon EC2 | Runs the Clienta application |
| IAM Instance Profile | Grants EC2 permission to retrieve the package |
| S3 Bucket Policy | Allows the EC2 IAM role to access the application object |
| S3 Encryption | Protects stored application artifacts using AES256 |
| Amazon Linux 2023 AMI | Provides the EC2 operating system |

## 4. S3 Security Configuration

The S3 bucket is configured with:

- Public access blocked.
- Server-side encryption using AES256.
- A bucket policy allowing `s3:GetObject` for the EC2 IAM role.
- A restricted S3 Gateway Endpoint policy allowing access to the application package.

The EC2 instance uses its IAM instance profile to authenticate with S3. No AWS access keys are stored in the application or User Data script.

## 5. S3 Gateway Endpoint Configuration

The Gateway Endpoint is associated with the private application route table.

It provides private access to Amazon S3 through the AWS network.

Unlike a NAT Gateway, an S3 Gateway Endpoint:

- Does not require a public IP address.
- Does not require an Internet Gateway route for S3 access.
- Has no hourly endpoint charge.
- Does not provide general Internet connectivity.

## 6. EC2 Application Bootstrap

The EC2 User Data script performs the following operations:

```bash
aws s3 cp \
  s3://BUCKET_NAME/clienta-app.tar.gz \
  /tmp/clienta-app.tar.gz \
  --region us-east-1

mkdir -p /opt/clienta

tar -xzf /tmp/clienta-app.tar.gz -C /opt/clienta
```

It then configures and starts the application using a systemd service.

The actual Terraform configuration uses the bucket name and object key as variables.

## 7. Why This Solution Instead of NAT?

A NAT Gateway or NAT Instance provides general outbound Internet connectivity to private resources.

However, in this deployment, the EC2 instance only needs to retrieve the application package from S3 during initialization.

Using an S3 Gateway Endpoint avoids the additional NAT infrastructure and reduces deployment costs.

**Important limitation:** If the EC2 instance needs to access GitHub, public APIs, external package repositories, or other Internet services, an additional outbound connectivity solution may be required.

## 8. Terraform Resources

The main Terraform resources involved in this solution include:

- `aws_s3_bucket`
- `aws_s3_bucket_public_access_block`
- `aws_s3_bucket_server_side_encryption_configuration`
- `aws_s3_bucket_policy`
- `aws_s3_object`
- `aws_vpc_endpoint`
- `aws_instance`

The application package is prepared locally before Terraform uploads it to S3.

## 9. Deployment

From the `infra` directory:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Terraform provisions the required infrastructure and uploads the application artifact to S3.

## 10. Conclusion

This architecture demonstrates how an S3 Gateway VPC Endpoint can replace the need for NAT connectivity for a specific application deployment requirement.

It reduces infrastructure costs while keeping the EC2 application server in a private subnet and restricting access to the required S3 artifact.
