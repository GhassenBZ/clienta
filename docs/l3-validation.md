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

After updating the temporary AWS Academy credentials and verifying the identity:

```powershell
terraform -chdir=infra init
terraform -chdir=infra plan -out=tfplan
terraform -chdir=infra apply tfplan
terraform -chdir=infra output
```

Review the plan for the `clienta` VPC, subnets, ALB/application/RDS security groups, EC2 instance, encrypted gp3 root volume, and weekly EBS snapshot lifecycle policy (Sunday at 03:00 UTC; two snapshots retained). Confirm the RDS security group allows TCP/3306 only from the application security group; it remains unattached until RDS is added.

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
