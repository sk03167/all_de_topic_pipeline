"""Apply Debezium CDC safely with Delta MERGE.

The deduplication window is per source primary key and source timestamp. Arrival order
is unreliable: retries and late Kafka partitions must not overwrite newer database state.
"""
from delta.tables import DeltaTable
from pyspark.sql import functions as F
from pyspark.sql.window import Window


def latest_debezium_state(raw_df):
    parsed = raw_df.select(
        F.from_json("payload_json", "op STRING, before STRING, after STRING, source STRUCT<ts_ms: BIGINT>").alias("cdc"),
        "_kafka_partition", "_kafka_offset", "_ingested_at",
    )
    changes = parsed.select(
        F.col("cdc.op").alias("operation"),
        F.coalesce(F.col("cdc.after"), F.col("cdc.before")).alias("record_json"),
        (F.col("cdc.source.ts_ms") / 1000).cast("timestamp").alias("source_updated_at"),
        "_kafka_partition", "_kafka_offset", "_ingested_at",
    ).filter(F.col("operation").isin("c", "u", "d", "r"))
    typed = changes.select(
        "operation", "source_updated_at", "_kafka_partition", "_kafka_offset", "_ingested_at",
        F.get_json_object("record_json", "$.order_id").alias("order_id"),
        F.get_json_object("record_json", "$.customer_id").alias("customer_id"),
        F.get_json_object("record_json", "$.order_status").alias("order_status"),
        F.get_json_object("record_json", "$.total_amount").cast("decimal(18,2)").alias("total_amount"),
    )
    return typed.withColumn(
        "_rank", F.row_number().over(Window.partitionBy("order_id").orderBy(F.col("source_updated_at").desc(), F.col("_kafka_offset").desc()))
    ).filter("_rank = 1").drop("_rank")


def merge_orders(microbatch_df, batch_id: int, target_table: str):
    latest = latest_debezium_state(microbatch_df)
    target = DeltaTable.forName(microbatch_df.sparkSession, target_table)
    (
        target.alias("target").merge(latest.alias("source"), "target.order_id = source.order_id")
        .whenMatchedUpdate(condition="source.operation <> 'd' AND source.source_updated_at >= target.source_updated_at", set={
            "customer_id": "source.customer_id", "order_status": "source.order_status", "total_amount": "source.total_amount", "source_updated_at": "source.source_updated_at", "is_deleted": "false", "last_batch_id": str(batch_id)
        })
        .whenMatchedUpdate(condition="source.operation = 'd' AND source.source_updated_at >= target.source_updated_at", set={"is_deleted": "true", "source_updated_at": "source.source_updated_at", "last_batch_id": str(batch_id)})
        .whenNotMatchedInsert(condition="source.operation <> 'd'", values={
            "order_id": "source.order_id", "customer_id": "source.customer_id", "order_status": "source.order_status", "total_amount": "source.total_amount", "source_updated_at": "source.source_updated_at", "is_deleted": "false", "last_batch_id": str(batch_id)
        }).execute()
    )
