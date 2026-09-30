# EC2 Kafka to Amazon MSK migration

## Why both are in this project

EC2 teaches Kafka internals: KRaft metadata, topics, partition assignment, offsets, connector plugin installation, and failure recovery. MSK teaches AWS production concerns: IAM authentication, private VPC connectivity, managed broker operations, and managed connector deployment.

## Compatibility contract

The following must remain stable through migration:

- topic names and partition keys;
- Avro subject names and backward-compatibility setting;
- Debezium source metadata and PostgreSQL replication slot behaviour;
- Delta checkpoint paths and target-table `MERGE` semantics;
- data-quality and reconciliation metrics.

## Cutover checklist

1. Provision MSK only after a cost-reviewed Terraform plan.
2. Create topics with the same retention/partition policy.
3. Configure IAM client authentication and restrict security groups to Databricks and connector subnets.
4. Replay the PostgreSQL snapshot or mirror source topics; do not point two Debezium connectors at the same replication slot.
5. Run a parallel consumer into a temporary Delta table and reconcile record counts, keys, and source timestamps.
6. Cut one consumer group at a time, retain the EC2 broker until offset and reconciliation checks are clean.

## Important distinction

MSK is managed Kafka; it does not remove your responsibility for topic design, schema compatibility, consumer lag, delivery semantics, or CDC correctness.
