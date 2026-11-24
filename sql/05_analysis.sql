-- =====================================================================
-- 05_analysis.sql : business questions (each query = one finding)
-- Scope: delivered orders in complete months (Jan 2017 - Aug 2018)
-- =====================================================================

-- Q1. Monthly GMV, orders, average order value and month-over-month growth
CREATE OR REPLACE TABLE a_monthly AS
SELECT order_month,
       COUNT(*)                         AS orders,
       ROUND(SUM(gmv), 2)               AS gmv,
       ROUND(AVG(gmv), 2)               AS avg_order_value,
       ROUND(100.0 * (SUM(gmv) / LAG(SUM(gmv)) OVER (ORDER BY order_month) - 1), 1) AS gmv_mom_pct
FROM fact_orders
WHERE is_complete_month AND order_status = 'delivered'
GROUP BY order_month
ORDER BY order_month;

-- Q2. Top 10 categories by revenue, with share of total
CREATE OR REPLACE TABLE a_categories AS
SELECT i.category,
       COUNT(DISTINCT i.order_id)                                        AS orders,
       ROUND(SUM(i.price), 2)                                            AS product_revenue,
       ROUND(100.0 * SUM(i.price) / SUM(SUM(i.price)) OVER (), 1)        AS revenue_share_pct,
       ROUND(AVG(i.price), 2)                                            AS avg_item_price
FROM fact_order_items i
JOIN fact_orders o USING (order_id)
WHERE o.is_complete_month AND o.order_status = 'delivered'
GROUP BY i.category
ORDER BY product_revenue DESC;

-- Q3. Delivery performance by customer state
CREATE OR REPLACE TABLE a_states AS
SELECT customer_state,
       COUNT(*)                                     AS orders,
       ROUND(MEDIAN(delivery_days), 1)              AS median_delivery_days,
       ROUND(100.0 * AVG(is_late::INT), 1)          AS late_pct,
       ROUND(AVG(freight_revenue / NULLIF(gmv,0)) * 100, 1) AS freight_share_pct,
       ROUND(AVG(review_score), 2)                  AS avg_review
FROM fact_orders
WHERE is_complete_month AND delivery_data_ok
GROUP BY customer_state
ORDER BY orders DESC;

-- Q4. Does lateness drive bad reviews?
CREATE OR REPLACE TABLE a_late_vs_review AS
SELECT CASE
         WHEN days_vs_estimate <= -10 THEN '1. 10+ days early'
         WHEN days_vs_estimate <=   0 THEN '2. 0-9 days early'
         WHEN days_vs_estimate <=   3 THEN '3. 1-3 days late'
         WHEN days_vs_estimate <=  10 THEN '4. 4-10 days late'
         ELSE                              '5. 10+ days late'
       END                                           AS delivery_bucket,
       COUNT(*)                                      AS orders,
       ROUND(AVG(review_score), 2)                   AS avg_review,
       ROUND(100.0 * AVG((review_score <= 2)::INT), 1) AS pct_1_2_stars
FROM fact_orders
WHERE is_complete_month AND delivery_data_ok AND review_score IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- Q5. Repeat customers (based on customer_unique_id, not customer_id)
CREATE OR REPLACE TABLE a_repeat AS
WITH per_customer AS (
    SELECT customer_unique_id, COUNT(*) AS n_orders, SUM(gmv) AS gmv
    FROM fact_orders
    WHERE order_status = 'delivered'
    GROUP BY customer_unique_id
)
SELECT COUNT(*)                                              AS customers,
       SUM((n_orders > 1)::INT)                              AS repeat_customers,
       ROUND(100.0 * AVG((n_orders > 1)::INT), 2)            AS repeat_rate_pct,
       ROUND(100.0 * SUM(CASE WHEN n_orders > 1 THEN gmv END) / SUM(gmv), 1) AS repeat_gmv_share_pct
FROM per_customer;

-- Q6. Payment mix and instalments
CREATE OR REPLACE TABLE a_payments AS
SELECT main_payment_type,
       COUNT(*)                                     AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct,
       ROUND(AVG(gmv), 2)                           AS avg_order_value,
       ROUND(AVG(installments), 1)                  AS avg_installments
FROM fact_orders
WHERE is_complete_month AND order_status = 'delivered' AND main_payment_type IS NOT NULL
GROUP BY 1
ORDER BY orders DESC;

-- Q7. Day-of-week x hour heatmap of purchases
CREATE OR REPLACE TABLE a_heatmap AS
SELECT ISODOW(purchased_at) AS iso_dow, HOUR(purchased_at) AS hour, COUNT(*) AS orders
FROM fact_orders
WHERE is_complete_month
GROUP BY 1, 2;
