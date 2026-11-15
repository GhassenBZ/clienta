# Requirements and project scope

- Host the selected Vikunja open-source task-management application with its browser frontend and REST API.
- Use a relational database for persistent accounts, projects, and tasks; this branch uses private MySQL 8.0 RDS.
- Provision the AWS environment with Terraform and use a real, private S3 workload for the deployment bundle and runtime configuration.
- Block public access to the artifact bucket and restrict each instance tier to the required S3 objects.
- Seed real demo accounts and database-backed projects/tasks during initial deployment, with Kanban and Gantt views populated.
- Keep secrets out of source code and EC2 user data; protect Terraform state and private runtime configuration.
- Use separate frontend/backend bundles, multi-AZ Auto Scaling groups, and ALB path routing between the browser frontend and API.
- Continue toward the cahier des charges requirements for RDS backups and restore, CloudWatch observability, cost control, and operational testing.

Terraform configures frontend and backend Auto Scaling groups with a minimum/desired capacity of two and a maximum of four, plus CPU target tracking. The groups have not been applied or tested in AWS. Automated RDS backups, CloudWatch dashboards/operational alarms, and shared Terraform state remain outside the current implementation.
