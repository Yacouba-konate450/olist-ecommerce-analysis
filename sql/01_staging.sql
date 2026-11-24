-- =====================================================================
-- 01_staging.sql : load raw CSVs as text, then cast to proper types
-- Dialect: DuckDB (PostgreSQL-compatible). TRY_CAST returns NULL instead
-- of failing, so bad values surface as NULLs we can count in step 04.
-- =====================================================================

-- Raw layer: everything as VARCHAR, exactly as delivered
CREATE OR REPLACE TABLE raw_orders      AS SELECT * FROM read_csv('data/olist_orders_dataset.csv',         all_varchar = true, header = true);
CREATE OR REPLACE TABLE raw_customers   AS SELECT * FROM read_csv('data/olist_customers_dataset.csv',      all_varchar = true, header = true);
CREATE OR REPLACE TABLE raw_items       AS SELECT * FROM read_csv('data/olist_order_items_dataset.csv',    all_varchar = true, header = true);
CREATE OR REPLACE TABLE raw_payments    AS SELECT * FROM read_csv('data/olist_order_payments_dataset.csv', all_varchar = true, header = true);
CREATE OR REPLACE TABLE raw_reviews     AS SELECT * FROM read_csv('data/olist_order_reviews_dataset.csv',  all_varchar = true, header = true);
CREATE OR REPLACE TABLE raw_products    AS SELECT * FROM read_csv('data/olist_products_dataset.csv',       all_varchar = true, header = true);
CREATE OR REPLACE TABLE raw_sellers     AS SELECT * FROM read_csv('data/olist_sellers_dataset.csv',        all_varchar = true, header = true);
CREATE OR REPLACE TABLE raw_categories  AS SELECT * FROM read_csv('data/product_category_name_translation.csv', all_varchar = true, header = true);

-- Staging layer: typed, trimmed, lower-cased text, consistent names
CREATE OR REPLACE TABLE stg_orders AS
SELECT
    TRIM(order_id)                                        AS order_id,
    TRIM(customer_id)                                     AS customer_id,
    LOWER(TRIM(order_status))                             AS order_status,
    TRY_CAST(order_purchase_timestamp      AS TIMESTAMP)  AS purchased_at,
    TRY_CAST(order_approved_at             AS TIMESTAMP)  AS approved_at,
    TRY_CAST(order_delivered_carrier_date  AS TIMESTAMP)  AS shipped_at,
    TRY_CAST(order_delivered_customer_date AS TIMESTAMP)  AS delivered_at,
    TRY_CAST(order_estimated_delivery_date AS TIMESTAMP)  AS estimated_at
FROM raw_orders;

CREATE OR REPLACE TABLE stg_customers AS
SELECT
    TRIM(customer_id)                    AS customer_id,
    TRIM(customer_unique_id)             AS customer_unique_id,   -- the real person; customer_id changes per order
    LPAD(TRIM(customer_zip_code_prefix), 5, '0') AS zip_prefix,   -- leading zeros are lost in some exports
    LOWER(TRIM(customer_city))           AS city,
    UPPER(TRIM(customer_state))          AS state
FROM raw_customers;

CREATE OR REPLACE TABLE stg_items AS
SELECT
    TRIM(order_id)                                   AS order_id,
    TRY_CAST(order_item_id AS INTEGER)               AS item_seq,
    TRIM(product_id)                                 AS product_id,
    TRIM(seller_id)                                  AS seller_id,
    TRY_CAST(shipping_limit_date AS TIMESTAMP)       AS shipping_limit_at,
    TRY_CAST(price         AS DECIMAL(10,2))         AS price,
    TRY_CAST(freight_value AS DECIMAL(10,2))         AS freight
FROM raw_items;

CREATE OR REPLACE TABLE stg_payments AS
SELECT
    TRIM(order_id)                                   AS order_id,
    TRY_CAST(payment_sequential   AS INTEGER)        AS payment_seq,
    LOWER(TRIM(payment_type))                        AS payment_type,
    TRY_CAST(payment_installments AS INTEGER)        AS installments,
    TRY_CAST(payment_value        AS DECIMAL(10,2))  AS payment_value
FROM raw_payments;

CREATE OR REPLACE TABLE stg_reviews AS
SELECT
    TRIM(review_id)                                  AS review_id,
    TRIM(order_id)                                   AS order_id,
    TRY_CAST(review_score AS INTEGER)                AS review_score,
    NULLIF(TRIM(review_comment_message), '')         AS comment,
    TRY_CAST(review_creation_date    AS TIMESTAMP)   AS created_at,
    TRY_CAST(review_answer_timestamp AS TIMESTAMP)   AS answered_at
FROM raw_reviews;

CREATE OR REPLACE TABLE stg_products AS
SELECT
    TRIM(product_id)                                 AS product_id,
    NULLIF(LOWER(TRIM(product_category_name)), '')   AS category_pt,
    TRY_CAST(product_name_lenght        AS INTEGER)  AS name_length,        -- fixes source typo "lenght"
    TRY_CAST(product_description_lenght AS INTEGER)  AS description_length,
    TRY_CAST(product_photos_qty         AS INTEGER)  AS photos_qty,
    TRY_CAST(product_weight_g           AS INTEGER)  AS weight_g,
    TRY_CAST(product_length_cm          AS INTEGER)  AS length_cm,
    TRY_CAST(product_height_cm          AS INTEGER)  AS height_cm,
    TRY_CAST(product_width_cm           AS INTEGER)  AS width_cm
FROM raw_products;

CREATE OR REPLACE TABLE stg_sellers AS
SELECT
    TRIM(seller_id)                      AS seller_id,
    LPAD(TRIM(seller_zip_code_prefix), 5, '0') AS zip_prefix,
    LOWER(TRIM(seller_city))             AS city,
    UPPER(TRIM(seller_state))            AS state
FROM raw_sellers;

CREATE OR REPLACE TABLE stg_categories AS
SELECT LOWER(TRIM(product_category_name)) AS category_pt,
       LOWER(TRIM(product_category_name_english)) AS category_en
FROM raw_categories;
