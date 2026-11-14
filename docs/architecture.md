# Clienta AWS architecture

## L1 scope

Clienta is a customer-management application with:

- a browser frontend;
- an Express REST API;
- a MySQL persistence layer.

The target is a reproducible three-tier AWS deployment using services allowed by the project brief and suitable for an AWS Academy lab account.

## L2 target architecture

See the [full target-state diagram](./clienta-architecture-target.drawio).

The target design separates the tiers:

1. **Presentation tier:** public HTTP entry point through an Application Load Balancer.
2. **Application tier:** EC2 instances in private application subnets.
3. **Data tier:** MySQL on RDS in private data subnets.

The VPC uses `10.0.0.0/16` in `us-east-1` with two Availability Zones:

- public subnets: `10.0.1.0/24`, `10.0.2.0/24`;
- private application subnets: `10.0.11.0/24`, `10.0.12.0/24`;
- private data subnets: `10.0.21.0/24`, `10.0.22.0/24`.

Security groups are tier-oriented. Internet traffic reaches the ALB on HTTP, and the application security group accepts application traffic from the ALB security group. SSH is restricted to the VPC CIDR in this lab baseline and should be narrowed further before any non-lab use.

## L3 implemented baseline

The current Terraform configuration creates:

- the VPC and DNS support;
- two public, two private application, and two private data subnets;
- an internet gateway and public route table;
- an internet-facing ALB and its security group;
- an application security group and a pre-created RDS security group that allows MySQL only from the application security group;
- a private S3 bucket (provisioned via a CloudFormation stack to prevent LabRole Object Lock read permission blocks) containing the packaged app, production dependencies, and Linux Node.js runtime;
- an S3 gateway endpoint on the private application route table, allowing the app instance to fetch the bundle without NAT;
- one EC2 application instance in a private application subnet, with an encrypted gp3 root EBS volume and the AWS Academy instance profile.

Run `scripts/package-app.ps1` before Terraform planning. It installs production dependencies locally, adds a checksum-verified Linux Node.js runtime, and creates the deployment archive while excluding `.env` files. Terraform uploads the archive; the instance profile can read only that object, and the private S3 gateway endpoint has no hourly charge. The instance requires no NAT route or internet access for bootstrapping. Destroy removes the EC2 instance, endpoint, bucket, and artifact.

The RDS security group is created now for the planned data tier, but it is not attached until the RDS instance is implemented. RDS, CloudWatch log groups/alarms, and complete ALB listener/target configuration are later increments. Do not present them as deployed by this L3 baseline until their Terraform resources are added and tested.
