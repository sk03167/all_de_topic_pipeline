"""Ingest append-only Kafka payloads without parsing away evidence in Bronze."""
from pyspark.sql import functions as F


def read_kafka(spark, bootstrap_servers: str, topic: str):
    return (
        spark.readStream.format("kafka")
        .option("kafka.bootstrap.servers", bootstrap_servers)
        .option("subscribe", topic)
        .option("startingOffsets", "earliest")
        .load()
        .select(
            F.col("key").cast("string").alias("_kafka_key"),
            F.col("value").cast("string").alias("payload_json"),
            F.col("topic").alias("_kafka_topic"),
            F.col("partition").alias("_kafka_partition"),
            F.col("offset").alias("_kafka_offset"),
            F.col("timestamp").alias("_kafka_timestamp"),
            F.current_timestamp().alias("_ingested_at"),
        )
    )
