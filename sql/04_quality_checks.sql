-- =====================================================================
-- 04_quality_checks.sql : each row must show 0 failures (or a known count)
-- =====================================================================
SELECT 'orders: duplicate order_id'                  AS check_name, COUNT(*) - COUNT(DISTINCT order_id) AS failures FROM fact_orders
UNION ALL SELECT 'orders: lost during joins',          (SELECT COUNT(*) FROM stg_orders) - (SELECT COUNT(*) FROM fact_orders)
UNION ALL SELECT 'orders: purchase date not parsed',   COUNT(*) FROM fact_orders WHERE purchased_at IS NULL
UNION ALL SELECT 'orders: no customer match',          COUNT(*) FROM fact_orders WHERE customer_unique_id IS NULL
UNION ALL SELECT 'reviews: >1 review per order',       COUNT(*) - COUNT(DISTINCT order_id) FROM clean_reviews
UNION ALL SELECT 'items: negative price or freight',   COUNT(*) FROM fact_order_items WHERE price < 0 OR freight < 0
UNION ALL SELECT 'items: category missing',            COUNT(*) FROM fact_order_items WHERE category IS NULL
UNION ALL SELECT 'payments: not_defined left',         COUNT(*) FROM clean_payments WHERE payment_type = 'not_defined'
-- informational counts (expected to be > 0, documented in the README)
UNION ALL SELECT 'INFO delivered but no valid date',   COUNT(*) FROM fact_orders WHERE order_status = 'delivered' AND NOT delivery_data_ok
UNION ALL SELECT 'INFO orders with no items',          COUNT(*) FROM fact_orders WHERE n_items IS NULL
UNION ALL SELECT 'INFO paid vs gmv differs by > 1 BRL', COUNT(*) FROM fact_orders WHERE ABS(amount_paid - gmv) > 1
UNION ALL SELECT 'INFO items with unknown category',   COUNT(*) FROM fact_order_items WHERE category = 'unknown';
