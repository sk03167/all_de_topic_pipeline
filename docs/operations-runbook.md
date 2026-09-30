# Operations and troubleshooting runbook

## Health checks

```bash
systemctl status kafka kafka-connect karapace
curl http://localhost:8083/connectors
curl http://localhost:8081/subjects
/opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --all-groups --describe
```

## CDC debugging order

1. Confirm RDS has `rds.logical_replication=1` and the instance reboot completed.
2. Confirm `olist_publication` contains the source tables and the Debezium replication slot exists.
3. Check Kafka Connect task status and connector logs.
4. Inspect the Kafka topic before changing Spark logic; distinguish a source problem from an ingestion problem.
5. Check Delta streaming checkpoints and query progress. Never casually delete a checkpoint; doing so changes replay semantics.
6. Reconcile source current-state count with non-deleted Silver count. Investigate any mismatch through Bronze payload and audit tables.

## Common failure modes

| Symptom | Likely cause | Safe response |
|---|---|---|
| Debezium fails to start | logical replication or publication missing | run the SQL preflight and inspect connector config |
| Duplicate Silver rows | MERGE target lacks primary-key condition | verify `order_id` key and source timestamp ordering |
| Stale record overwrites correction | arrival order used instead of source timestamp | retain `source.ts_ms`; replay from Bronze if needed |
| Schema registration rejected | incompatible contract change | add an optional field with a default, or version topic/subject |
| Streaming query replays unexpectedly | checkpoint changed/deleted | restore the original checkpoint or intentionally backfill to a separate target |
