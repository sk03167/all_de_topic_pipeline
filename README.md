# Olist Marketplace Lakehouse

An end-to-end, deliberately small AWS + Databricks data-engineering lab. It demonstrates batch ingestion, PostgreSQL WAL CDC with Debezium, Kafka streaming, schema contracts, Delta Lake `MERGE`, medallion layers, data quality, reconciliation, governance, observability, and automated deployment.

## What runs where

```text
Olist CSV history ──> S3 landing ──Auto Loader──> Bronze Delta
                                                    │
RDS PostgreSQL ──WAL──> Debezium ──> Kafka ────────┼─> Silver Delta ─> Gold Delta
                      (EC2 lab / MSK later)         │
Clickstream generator ──────────────────────────────┘
```

The live lab uses **S3, IAM, one KMS key, a single-AZ RDS PostgreSQL instance, and one EC2 instance**. Kafka, Kafka Connect, Debezium, Karapace, and the data generator run directly on EC2 as system services—there is no Docker, ECS, NAT Gateway, MSK, or DMS in the initial deployment.

The historical seed is Kaggle's public [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). Accept its terms and download it manually before running the upload script. The included generator creates new orders, inventory adjustments, and clickstream events from that seed data so the CDC and streaming paths are real and repeatable.

## Safety and cost controls

- Terraform files are code only. They do not create resources until `terraform apply` is run.
- The default region is `ap-south-1`; set it explicitly in `terraform.tfvars`.
- Budget alerts are included. Set `budget_limit_usd` to `15` initially.
- Destroy the lab immediately after use: `make destroy-lab`.
- Never place AWS keys, database passwords, or Databricks tokens in this repository. `.gitignore` blocks common secret and state files.

## Repository map

| Path | Purpose |
|---|---|
| `infra/environments/lab-ec2` | Low-cost Terraform environment to deploy only after approval |
| `infra/environments/msk-later` | Disabled-by-default managed Kafka migration environment |
| `services/generator` | Annotated PostgreSQL and clickstream event producer |
| `kafka-connect` | Debezium connector and Karapace configuration |
| `pipelines/src` | Databricks Spark Bronze/Silver/Gold transformations |
| `databricks` | Databricks Asset Bundle and job definitions |
| `data/contracts` | Versioned Avro event contracts |
| `docs` | Architecture, operating guide, CDC runbook, and migration guide |

## Development flow

1. Download and unzip Olist data into a local directory you control. After deployment, `services/generator/src/seed_olist.py` loads a bounded source snapshot into PostgreSQL and `scripts/upload_olist_data.sh` sends original files to S3.
2. Review `docs/deployment-plan.md` and `infra/environments/lab-ec2/terraform.tfvars.example`.
3. Run `make validate` to validate Terraform formatting and Python syntax. This makes **no cloud calls**.
4. Ask for a reviewed Terraform plan, then run `make plan-lab`.
5. Only after explicit approval, run `make apply-lab`.
6. Configure the Databricks workspace host/auth outside source control and run the DAB validation/deployment commands in `docs/databricks-runbook.md`.

## Learning checkpoints

- Batch: S3 CSV → Auto Loader → Bronze Delta
- CDC: PostgreSQL logical replication/WAL → Debezium → Kafka → idempotent Silver `MERGE`
- Streaming: clickstream → Kafka → Structured Streaming with checkpoints and watermarks
- Contracts: Avro subjects, backward-compatible field additions, Karapace registry
- Lakehouse: Bronze/Silver/Gold, Delta history, Change Data Feed, late data
- Governance: Unity Catalog catalog/schema permissions, row filter and column mask examples
- Operations: audit events, quality quarantine, reconciliation, CI validation, runbooks

## Not deployed in the lab

MSK, MSK Connect, AWS DMS, NAT Gateway, MySQL, SQL Server, Oracle, Snowflake, and Flink have architecture/migration documentation but no billable runtime. See `docs/msk-migration.md`.
