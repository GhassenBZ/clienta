# L3 validation and teardown

## Local validation

From the repository root:

```powershell
terraform -chdir=infra fmt -recursive
terraform -chdir=infra init -backend=false
terraform -chdir=infra validate
```

From the repository root, build the deployment bundle before creating a plan:

```powershell
.\scripts\package-app.ps1
```

The script requires `npm` and internet access on the developer workstation. It creates `build\clienta-app.tar.gz`, including production dependencies and a checksum-verified Linux Node.js runtime, while excluding `.env` files.

## Apply

From the repository root, after updating the temporary AWS Academy credentials and verifying the identity:

```powershell
terraform -chdir=infra init
terraform -chdir=infra plan -out=tfplan
terraform -chdir=infra apply tfplan
terraform -chdir=infra output
```

Review the plan for the VPC, six subnets, public route table and internet gateway, ALB, application and RDS security groups, private S3 bucket and artifact, S3 gateway endpoint, one EC2 instance in a private application subnet, and the private MySQL RDS instance. The EC2 root volume is encrypted gp3. Confirm the RDS security group allows TCP/3306 only from the application security group and is attached to RDS. Confirm the S3 bucket blocks public access and the app instance uses the existing `LabInstanceProfile` to read the bundle.

The app bootstrap downloads and extracts the deployment bundle from S3. Express runs on the EC2 instance and serves the frontend files alongside the API; S3 is not currently serving the frontend directly. There is no NAT route. The ALB currently has no listener or target group, so it is not expected to serve app traffic. This branch also has no Data Lifecycle Manager policy for automatic EBS snapshots.

## Destroy

Before the lab session ends:

```powershell
terraform -chdir=infra plan -destroy -out=destroy.tfplan
terraform -chdir=infra apply destroy.tfplan
```

If the destroy plan is reviewed and approved, the shorter equivalent is:

```powershell
terraform -chdir=infra destroy
```

Keep the local state until destruction succeeds. Generated state, plans, credentials, and `.terraform/` are ignored by Git.
