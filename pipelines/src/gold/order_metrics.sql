-- Gold model: current customer-level sales metrics. Exclude soft-deleted CDC rows.
CREATE OR REPLACE VIEW ${catalog}.gold.customer_order_metrics AS
SELECT
  customer_id,
  COUNT(*) AS completed_order_count,
  SUM(total_amount) AS lifetime_order_value,
  MAX(source_updated_at) AS last_order_updated_at
FROM ${catalog}.silver.orders_current
WHERE is_deleted = false
GROUP BY customer_id;
