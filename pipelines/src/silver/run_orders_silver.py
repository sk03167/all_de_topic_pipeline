"""Build the Silver Olist orders table with quality quarantine and Delta MERGE."""

from __future__ import annotations

import argparse

from delta.tables import DeltaTable
from pyspark.sql import DataFrame
from pyspark.sql import functions as F

VALID_STATUSES = (
    "approved",
    "canceled",
    "created",
    "delivered",
    "invoiced",
    "processing",
    "shipped",
    "unavailable",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", required=True)
    return parser.parse_args()


def typed_orders(raw: DataFrame) -> DataFrame:
    return raw.select(
        "order_id",
        "customer_id",
        "order_status",
        F.to_timestamp("order_purchase_timestamp").alias("purchased_at"),
        F.to_timestamp("order_approved_at").alias("approved_at"),
        F.to_timestamp("order_delivered_carrier_date").alias("carrier_delivered_at"),
        F.to_timestamp("order_delivered_customer_date").alias("customer_delivered_at"),
        F.to_timestamp("order_estimated_delivery_date").alias("estimated_delivery_at"),
        "_ingested_at",
        "_source_file",
    )


def split_validity(orders: DataFrame) -> tuple[DataFrame, DataFrame]:
    reason = (
        F.when(F.col("order_id").isNull() | (F.length("order_id") == 0), "missing_order_id")
        .when(F.col("customer_id").isNull() | (F.length("customer_id") == 0), "missing_customer_id")
        .when(~F.col("order_status").isin(*VALID_STATUSES), "invalid_order_status")
    )
    classified = orders.withColumn("quarantine_reason", reason)
    return classified.filter("quarantine_reason IS NULL").drop("quarantine_reason"), classified.filter(
        "quarantine_reason IS NOT NULL"
    )


def merge_snapshot(valid: DataFrame, target_table: str) -> None:
    spark = valid.sparkSession
    if not spark.catalog.tableExists(target_table):
        valid.write.format("delta").mode("overwrite").saveAsTable(target_table)
        return
    (
        DeltaTable.forName(spark, target_table)
        .alias("target")
        .merge(valid.alias("source"), "target.order_id = source.order_id")
        .whenMatchedUpdateAll()
        .whenNotMatchedInsertAll()
        .execute()
    )


def main() -> None:
    args = parse_args()
    spark = __import__("pyspark.sql", fromlist=["SparkSession"]).SparkSession.builder.getOrCreate()
    raw = spark.table(f"{args.catalog}.bronze.orders_raw")
    valid, invalid = split_validity(typed_orders(raw))
    merge_snapshot(valid, f"{args.catalog}.silver.orders_clean")
    invalid.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(
        f"{args.catalog}.audit.orders_quarantine"
    )


if __name__ == "__main__":
    main()
