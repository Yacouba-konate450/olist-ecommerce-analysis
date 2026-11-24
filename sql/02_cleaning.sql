-- =====================================================================
-- 02_cleaning.sql : fix or flag each problem found while profiling
-- Rule: never silently delete. Fix what is safe to fix, flag the rest.
-- =====================================================================

-- 1. Products: fill missing categories and translate to English.
--    610 products have no category; 2 Portuguese categories have no translation.
CREATE OR REPLACE TABLE clean_products AS
SELECT
    p.*,
    COALESCE(
        c.category_en,
        CASE p.category_pt
            WHEN 'pc_gamer' THEN 'pc_gamer'
            WHEN 'portateis_cozinha_e_preparadores_de_alimentos' THEN 'portable_kitchen_appliances'
        END,
        'unknown'
    ) AS category
FROM stg_products p
LEFT JOIN stg_categories c USING (category_pt);

-- 2. Reviews: some orders have several reviews. Keep the most recent one per order.
CREATE OR REPLACE TABLE clean_reviews AS
SELECT * EXCLUDE (rn)
FROM (
    SELECT r.*,
           ROW_NUMBER() OVER (PARTITION BY order_id
                              ORDER BY answered_at DESC NULLS LAST, created_at DESC, review_id) AS rn
    FROM stg_reviews r
    WHERE review_score BETWEEN 1 AND 5
) t
WHERE rn = 1;

-- 3. Payments: drop 'not_defined' rows and zero-value rows (vouchers recorded as 0);
--    an installment count of 0 is impossible, so treat it as 1.
CREATE OR REPLACE TABLE clean_payments AS
SELECT
    order_id, payment_seq, payment_type,
    CASE WHEN installments < 1 THEN 1 ELSE installments END AS installments,
    payment_value
FROM stg_payments
WHERE payment_type <> 'not_defined'
  AND payment_value > 0;

-- 4. Orders: add flags instead of deleting.
--    - is_complete_month : excludes the sparse months at both ends of the data
--      (Sep-Dec 2016 and Sep-Oct 2018 have only a handful of orders)
--    - delivery_data_ok   : delivered orders that really have a delivery date
--      in a plausible order (purchase <= delivery)
CREATE OR REPLACE TABLE clean_orders AS
SELECT
    o.*,
    DATE_TRUNC('month', purchased_at)::DATE                         AS order_month,
    (purchased_at >= TIMESTAMP '2017-01-01'
     AND purchased_at <  TIMESTAMP '2018-09-01')                    AS is_complete_month,
    (order_status = 'delivered'
     AND delivered_at IS NOT NULL
     AND delivered_at >= purchased_at)                               AS delivery_data_ok
FROM stg_orders o;
