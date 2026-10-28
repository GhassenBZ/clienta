# Destruction and rebuild journal

Record one entry for every lab session in which Terraform is applied.

| Date | AWS region | Resources applied | Destroyed | Verification |
|---|---|---|---|---|
| YYYY-MM-DD | us-east-1 | `terraform apply` resources | yes/no | `terraform state list`, AWS console |

## Session checklist

1. Run `aws sts get-caller-identity`.
2. Run `terraform plan` and review the resource list.
3. Apply only after confirming the plan and region.
4. Test the resources needed for the session.
5. Run the destroy plan before the lab expires.
6. Apply the destroy plan.
7. Confirm that no unexpected `clienta-*` resources remain in the AWS console.

Never delete Terraform state before destroying the resources it tracks. Never commit state files, plans, credentials, or `.terraform/` to Git.
