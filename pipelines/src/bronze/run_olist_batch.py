"""Run an idempotent Olist-orders batch ingestion with Auto Loader.

The job receives paths rather than embedding storage credentials or workspace
URLs.  This keeps the same code deployable in a local Spark test, a Databricks
development catalog, and a production catalog.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# A Databricks bundle syncs the whole `pipelines/src` tree.  Add that tree when
# this script is invoked directly by a Spark Python task instead of as a wheel.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from bronze.ingest_olist_files import read_olist_csv, write_bronze


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--source-path", required=True)
    parser.add_argument("--state-path", required=True)
    parser.add_argument("--table-name", default="orders_raw")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    spark = __import__("pyspark.sql", fromlist=["SparkSession"]).SparkSession.builder.getOrCreate()
    destination = f"{args.catalog}.bronze.{args.table_name}"
    dataframe = read_olist_csv(
        spark=spark,
        source_path=args.source_path,
        schema_location=f"{args.state_path}/schemas/{args.table_name}",
    )
    query = write_bronze(
        df=dataframe,
        destination=destination,
        checkpoint=f"{args.state_path}/checkpoints/{args.table_name}",
    )
    query.awaitTermination()


if __name__ == "__main__":
    main()
