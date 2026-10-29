# L3 validation and teardown

## Local validation

From the repository root:

```powershell
terraform -chdir=infra fmt -recursive
terraform -chdir=infra init -backend=false
terraform -chdir=infra validate
```

The L3 baseline must validate before any AWS resources are created.

## Apply

From the repository root, after updating the temporary AWS Academy credentials and verifying the identity:

```powershell
terraform -chdir=infra init
terraform -chdir=infra plan -out=tfplan
terraform -chdir=infra apply tfplan
terraform -chdir=infra output
```

Review the plan for the VPC, six subnets, public route table and internet gateway, ALB, application and RDS security groups, and one EC2 instance in a private application subnet. The EC2 root volume is encrypted gp3. Confirm the RDS security group allows TCP/3306 only from the application security group; it remains unattached until RDS is added.

This baseline only creates infrastructure. The EC2 instance uses a stock Amazon Linux AMI and does not yet install the app. The ALB also has no listener or target group, so it is not expected to serve traffic.

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
