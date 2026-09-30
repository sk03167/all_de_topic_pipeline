"""Load a bounded Olist history into the operational PostgreSQL source.

The batch lake path preserves original CSV files in S3. This script seeds a subset
into the OLTP database solely so Debezium can take an initial snapshot before live
mutations begin. It is safe to rerun because primary keys use UPSERT semantics.
"""
from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from pathlib import Path

import psycopg


def rows(path: Path):
    with path.open(newline="", encoding="utf-8") as handle:
        yield from csv.DictReader(handle)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--postgres-dsn", required=True)
    parser.add_argument("--olist-dir", type=Path, required=True)
    parser.add_argument("--max-orders", type=int, default=5000)
    args = parser.parse_args()
    directory = args.olist_dir
    totals: dict[str, float] = defaultdict(float)
    for item in rows(directory / "olist_order_items_dataset.csv"):
        totals[item["order_id"]] += float(item["price"] or 0)

    customers = {item["customer_id"]: item for item in rows(directory / "olist_customers_dataset.csv")}
    selected_orders = list(rows(directory / "olist_orders_dataset.csv"))[: args.max_orders]
    with psycopg.connect(args.postgres_dsn) as connection, connection.cursor() as cursor:
        for order in selected_orders:
            customer = customers[order["customer_id"]]
            customer_id = customer["customer_id"]
            # Olist has no e-mail field; a deterministic placeholder permits the
            # Unity Catalog masking exercise without pretending it is real PII.
            cursor.execute(
                """INSERT INTO public.customers (customer_id, customer_email)
                   VALUES (%s, %s)
                   ON CONFLICT (customer_id) DO NOTHING""",
                (customer_id, f"{customer_id}@olist.example.invalid"),
            )
            cursor.execute(
                """INSERT INTO public.orders (order_id, customer_id, order_status, total_amount)
                   VALUES (%s, %s, %s, %s)
                   ON CONFLICT (order_id) DO UPDATE SET order_status = EXCLUDED.order_status,
                     total_amount = EXCLUDED.total_amount, updated_at = now()""",
                (order["order_id"], customer_id, order["order_status"], totals[order["order_id"]]),
            )
        connection.commit()


if __name__ == "__main__":
    main()
