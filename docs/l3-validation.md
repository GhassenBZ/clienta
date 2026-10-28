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
.\scripts\package-app.ps1
terraform -chdir=infra init
terraform -chdir=infra plan -out=tfplan
terraform -chdir=infra apply tfplan
terraform -chdir=infra output
```

Run the packaging script from the repository root before planning; it requires `npm` and downloads the pinned Linux Node.js runtime with checksum verification. Review the plan for the private artifact bucket/object, S3 gateway endpoint and private app route table, existing `LabInstanceProfile`, app EC2 instance, encrypted gp3 root volume, and weekly EBS snapshot lifecycle policy (Sunday at 03:00 UTC; two snapshots retained). Confirm the bucket blocks public access and only the profile role is granted `GetObject`. The private app subnet has no NAT route. Confirm the RDS security group allows TCP/3306 only from the application security group; it remains unattached until RDS is added.

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
