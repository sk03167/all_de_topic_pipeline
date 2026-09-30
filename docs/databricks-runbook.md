# Databricks runbook

## Prerequisites

- An existing Databricks on AWS workspace and Unity Catalog metastore.
- An administrator-created storage credential/external location referencing the encrypted lab bucket.
- Databricks CLI authenticated through an OAuth profile or approved secure mechanism. Do not commit tokens.

## Safe validation

```bash
cd databricks
# Keep the workspace URL and token outside source control. The CLI reads them
# for this terminal session; the bundle never persists either value.
export DATABRICKS_HOST=https://YOUR_WORKSPACE
export DATABRICKS_TOKEN=YOUR_SHORT_LIVED_TOKEN
databricks bundle validate --target dev
```

Validation does not deploy jobs. Bundle deployment and any Databricks compute use require separate approval.

## EC2 service installation

After the approved AWS deployment, copy the repository's `kafka-connect/` and `scripts/` directories to the EC2 host, then run `scripts/install-services.sh` from the repository root. Next run `scripts/register-contracts.sh` against Karapace and `scripts/register-connector.sh` on the EC2 host. `scripts/prepare_postgres.sql` must run before registering Debezium. These commands are operational steps, not Terraform resources; review each command before executing it.

## Governance exercise

Create the catalog/schemas from `resources/governance.sql`, grant pipeline ownership only to the deployment service principal, and grant analysts `USE CATALOG`, `USE SCHEMA`, and explicit table `SELECT` privileges. Demonstrate a column mask after the customer table exists.

## Cost control

Use ephemeral job compute or serverless jobs; never leave an all-purpose cluster running. The included job has a 10-minute auto-termination setting. Tag every workload with `project=olist-lakehouse` so its DBU usage can be queried from Databricks billing system tables.
