-- Run against RDS after Terraform reports the endpoint. The RDS parameter group
-- enables logical replication; this publication makes source tables visible to Debezium.
CREATE TABLE IF NOT EXISTS public.customers (
  customer_id TEXT PRIMARY KEY,
  customer_email TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.orders (
  order_id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES public.customers(customer_id),
  order_status TEXT NOT NULL,
  total_amount NUMERIC(18,2) NOT NULL CHECK (total_amount >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.inventory (
  product_id TEXT PRIMARY KEY,
  quantity_available INTEGER NOT NULL CHECK (quantity_available >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.customers REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.inventory REPLICA IDENTITY FULL;
DO $$ BEGIN
  CREATE PUBLICATION olist_publication FOR TABLE public.customers, public.orders, public.inventory;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
