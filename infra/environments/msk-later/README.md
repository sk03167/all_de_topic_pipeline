# Managed Kafka migration (do not deploy during the low-cost lab)

This environment is deliberately separate from `lab-ec2`. It is enabled only when you want to practice AWS-managed Kafka.

The migration retains topics, Avro contracts, Debezium semantics, Spark consumers, Delta tables, and checkpoints. It changes only broker connectivity, TLS/SASL IAM authentication, networking, and the Kafka Connect hosting model.

1. Create MSK Serverless and IAM client permissions.
2. Mirror or replay lab topics into MSK.
3. Update Databricks Kafka options and validate consumer lag.
4. Deploy Debezium as an MSK Connect custom plugin, using the same connector configuration.
5. Cut consumers over per topic, then retire EC2 Kafka.

Run `terraform plan` here only after reviewing current AWS MSK pricing and accepting the managed-service costs.
