"""Batch/incremental ingestion of Olist CSV files using Databricks Auto Loader.

Auto Loader persists discovered files in the checkpoint so reruns are idempotent.
Raw payload and ingestion metadata are retained in Bronze for replay and audit.
"""
from pyspark.sql import DataFrame
from pyspark.sql import functions as F


def read_olist_csv(spark, source_path: str, schema_location: str) -> DataFrame:
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "csv")
        .option("cloudFiles.schemaLocation", schema_location)
        .option("header", "true")
        .option("cloudFiles.inferColumnTypes", "false")
        .load(source_path)
        .withColumn("_ingested_at", F.current_timestamp())
        .withColumn("_source_file", F.input_file_name())
    )


def write_bronze(df: DataFrame, destination: str, checkpoint: str):
    return (
        df.writeStream.format("delta").outputMode("append")
        .option("checkpointLocation", checkpoint)
        .option("mergeSchema", "true")  # Additive source fields are permitted and audited.
        .trigger(availableNow=True)
        .toTable(destination)
    )
