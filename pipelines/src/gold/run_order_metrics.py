"""Publish Gold customer-order metrics from the validated Silver table."""

from __future__ import annotations

import argparse


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    spark = __import__("pyspark.sql", fromlist=["SparkSession"]).SparkSession.builder.getOrCreate()
    spark.sql(
        f"""
        CREATE OR REPLACE VIEW {args.catalog}.gold.customer_order_metrics AS
        SELECT
          customer_id,
          COUNT(*) AS order_count,
          SUM(CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END) AS delivered_order_count,
          MIN(purchased_at) AS first_order_at,
          MAX(purchased_at) AS latest_order_at
        FROM {args.catalog}.silver.orders_clean
        GROUP BY customer_id
        """
    )


if __name__ == "__main__":
    main()
