"""Reusable data-quality classification. Invalid records remain inspectable."""
from pyspark.sql import functions as F


def split_valid_orders(df):
    invalid = df.filter(
        F.col("order_id").isNull() | F.col("customer_id").isNull() | (F.col("total_amount") < 0)
    ).withColumn("quarantine_reason", F.when(F.col("order_id").isNull(), "missing_order_id")
      .when(F.col("customer_id").isNull(), "missing_customer_id").otherwise("negative_total_amount"))
    return df.subtract(invalid.drop("quarantine_reason")), invalid
