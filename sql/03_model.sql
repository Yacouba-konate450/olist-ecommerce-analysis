-- =====================================================================
-- 03_model.sql : analysis-ready tables (one grain per table)
-- =====================================================================

-- fact_order_items : one row per item sold, with category and seller state
CREATE OR REPLACE TABLE fact_order_items AS
SELECT
    i.order_id, i.item_seq, i.product_id, i.seller_id,
    p.category, s.state AS seller_state,
    i.price, i.freight, i.price + i.freight AS item_total
FROM stg_items i
LEFT JOIN clean_products p USING (product_id)
LEFT JOIN stg_sellers    s USING (seller_id);

-- fact_orders : one row per order
CREATE OR REPLACE TABLE fact_orders AS
WITH items AS (
    SELECT order_id,
           COUNT(*)            AS n_items,
           SUM(price)          AS product_revenue,
           SUM(freight)        AS freight_revenue,
           -- main category = category of the most expensive item
           ARG_MAX(category, price) AS main_category
    FROM fact_order_items
    GROUP BY order_id
),
pay AS (
    SELECT order_id,
           SUM(payment_value)           AS amount_paid,
           ARG_MAX(payment_type, payment_value) AS main_payment_type,
           MAX(installments)            AS installments
    FROM clean_payments
    GROUP BY order_id
)
SELECT
    o.order_id, o.order_status, o.purchased_at, o.order_month, o.is_complete_month,
    c.customer_unique_id, c.state AS customer_state, c.city AS customer_city,
    i.n_items, i.product_revenue, i.freight_revenue,
    i.product_revenue + i.freight_revenue AS gmv,       -- gross merchandise value
    i.main_category,
    p.amount_paid, p.main_payment_type, p.installments,
    r.review_score,
    o.delivery_data_ok,
    CASE WHEN o.delivery_data_ok
         THEN DATE_DIFF('day', o.purchased_at, o.delivered_at) END          AS delivery_days,
    CASE WHEN o.delivery_data_ok
         THEN DATE_DIFF('day', o.estimated_at, o.delivered_at) END          AS days_vs_estimate,  -- >0 = late
    CASE WHEN o.delivery_data_ok
         THEN o.delivered_at::DATE > o.estimated_at::DATE END                AS is_late
FROM clean_orders o
LEFT JOIN stg_customers c USING (customer_id)
LEFT JOIN items         i USING (order_id)
LEFT JOIN pay           p USING (order_id)
LEFT JOIN clean_reviews r USING (order_id);
