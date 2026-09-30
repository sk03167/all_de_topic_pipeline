"""Produce repeatable marketplace activity for CDC and streaming demonstrations.

This process has two intentionally separate write paths:
* SQL mutations go to PostgreSQL and appear later through its WAL/Debezium topic.
* Clickstream events are born in Kafka because they have no relational source of truth.

Use a fixed --seed during demos to reproduce ordering and data-quality scenarios.
"""
from __future__ import annotations

import argparse
import json
import random
import time
import uuid
from datetime import UTC, datetime

import psycopg
from confluent_kafka import Producer


def utc_now() -> str:
    return datetime.now(UTC).isoformat()


def emit_clickstream(producer: Producer, customer_id: str | None) -> None:
    event = {
        "event_id": str(uuid.uuid4()), "event_ts": utc_now(),
        "session_id": str(uuid.uuid4()), "customer_id": customer_id,
        "event_name": random.choice(["product_viewed", "product_added_to_cart", "checkout_started"]),
        "product_id": f"product-{random.randint(1, 100):03d}",
        "page_url": "/products/example",
    }
    producer.produce("olist.clickstream.v1", key=event["session_id"], value=json.dumps(event))
    producer.poll(0)


def mutate_order(connection: psycopg.Connection) -> str:
    """Insert or update an order. Debezium records both operations from WAL."""
    customer_id = f"customer-{random.randint(1, 500):04d}"
    order_id = str(uuid.uuid4())
    amount = round(random.uniform(20, 500), 2)
    with connection.cursor() as cursor:
        # Seed data will provide most customers. This upsert also makes the generator
        # independently runnable and emits an insert/update on the customers CDC topic.
        cursor.execute(
            """
            INSERT INTO public.customers (customer_id, customer_email, updated_at)
            VALUES (%s, %s, now())
            ON CONFLICT (customer_id) DO UPDATE SET updated_at = EXCLUDED.updated_at
            """, (customer_id, f"{customer_id}@example.invalid"),
        )
        cursor.execute(
            """
            INSERT INTO public.orders (order_id, customer_id, order_status, total_amount, updated_at)
            VALUES (%s, %s, 'created', %s, now())
            """, (order_id, customer_id, amount),
        )
        # Some events deliberately become corrections. Silver MERGE must use updated_at,
        # not Kafka arrival order, to keep the latest source state.
        if random.random() < 0.2:
            cursor.execute(
                "UPDATE public.orders SET order_status = 'cancelled', updated_at = now() WHERE order_id = %s",
                (order_id,),
            )
    connection.commit()
    return customer_id


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--postgres-dsn", required=True)
    parser.add_argument("--kafka-bootstrap", required=True)
    parser.add_argument("--events", type=int, default=100)
    parser.add_argument("--interval-seconds", type=float, default=0.5)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    random.seed(args.seed)
    producer = Producer({"bootstrap.servers": args.kafka_bootstrap, "acks": "all", "enable.idempotence": True})
    with psycopg.connect(args.postgres_dsn) as connection:
        for _ in range(args.events):
            customer_id = mutate_order(connection)
            emit_clickstream(producer, customer_id)
            time.sleep(args.interval_seconds)
    producer.flush(30)


if __name__ == "__main__":
    main()
