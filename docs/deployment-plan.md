# Deployment plan and approval boundary

## Initial lab resources

Terraform will create exactly the following after a separately approved `terraform apply`:

1. One VPC, one public subnet, route table, internet gateway, and security groups.
2. One customer-managed KMS key (rotation enabled) for S3, RDS, and Parameter Store encryption.
3. One versioned S3 lake bucket with `landing/`, `bronze/`, `silver/`, `gold/`, `checkpoints/`, `audit/`, and `artifacts/` prefixes.
4. One single-AZ `db.t4g.micro` RDS PostgreSQL database with logical replication enabled.
5. One `t3.medium` EC2 instance with 30 GB gp3 disk. Cloud-init installs Kafka, Kafka Connect/Debezium, Karapace, and the generator as direct system services.
6. Two encrypted SSM parameters: database endpoint metadata and generated database password.
7. CloudWatch log groups and two AWS Budget email thresholds.

## Explicit exclusions

No MSK, MSK Connect, AWS DMS, NAT Gateway, ECS/Fargate, EKS, Lambda, VPC interface endpoints, multi-AZ databases, or persistent Databricks cluster will be created.

## Cost guardrails

- Default budget alerts: 80% and 100% of `budget_limit_usd`.
- EC2 and RDS are intentionally small and single-AZ.
- S3 lifecycle expires transient landing/checkpoint data after seven days.
- Terraform destroy removes all billable resources. The bucket is configured to force-destroy only because it is lab-only; do not use this setting in production.

## Approval rule

Running `terraform fmt`, `validate`, or `plan` is safe and does not create cloud infrastructure. Do not run `apply` or `destroy` without user confirmation.
