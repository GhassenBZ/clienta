# AWS Academy account and cost controls

## Before each lab session

1. Start the AWS Academy Learner Lab.
2. Wait until the lab status is active.
3. Open **AWS Details** and copy the temporary CLI credentials.
4. Replace the `default` profile in the local AWS credentials file:
   `%USERPROFILE%\.aws\credentials`.
5. Verify the session with:

```powershell
aws sts get-caller-identity
```

The credentials are temporary and include an access key, secret key, and session token. They must never be committed to this repository.

## Cost discipline

The lab baseline uses small resources and the fixed `clienta` prefix. Before applying, review the plan and confirm the current AWS region is `us-east-1`.

At the end of the session:

```powershell
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

AWS Budgets is a separate account-level control and may be unavailable in the Academy environment. CloudWatch is an infrastructure observability service and is separate from the budget mechanism.
