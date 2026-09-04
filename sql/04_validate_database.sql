\set ON_ERROR_STOP on

CREATE OR REPLACE VIEW
olist.v_database_validation AS

WITH checks AS (

    -- Row-count checks

    SELECT
        'row_count_category_translation'::TEXT
            AS check_name,
        (SELECT COUNT(*)
         FROM olist.category_translation)::BIGINT
            AS actual_value,
        74::BIGINT AS expected_value

    UNION ALL

    SELECT
        'row_count_customers',
        (SELECT COUNT(*)
         FROM olist.customers)::BIGINT,
        99441::BIGINT

    UNION ALL

    SELECT
        'row_count_geolocation',
        (SELECT COUNT(*)
         FROM olist.geolocation)::BIGINT,
        19015::BIGINT

    UNION ALL

    SELECT
        'row_count_order_items',
        (SELECT COUNT(*)
         FROM olist.order_items)::BIGINT,
        112650::BIGINT

    UNION ALL

    SELECT
        'row_count_orders',
        (SELECT COUNT(*)
         FROM olist.orders)::BIGINT,
        99441::BIGINT

    UNION ALL

    SELECT
        'row_count_payments',
        (SELECT COUNT(*)
         FROM olist.payments)::BIGINT,
        103886::BIGINT

    UNION ALL

    SELECT
        'row_count_products',
        (SELECT COUNT(*)
         FROM olist.products)::BIGINT,
        32951::BIGINT

    UNION ALL

    SELECT
        'row_count_reviews',
        (SELECT COUNT(*)
         FROM olist.reviews)::BIGINT,
        99224::BIGINT

    UNION ALL

    SELECT
        'row_count_sellers',
        (SELECT COUNT(*)
         FROM olist.sellers)::BIGINT,
        3095::BIGINT

    -- Foreign-key relationship checks

    UNION ALL

    SELECT
        'orphan_orders_customers',
        (
            SELECT COUNT(*)
            FROM olist.orders AS o
            LEFT JOIN olist.customers AS c
                ON o.customer_id = c.customer_id
            WHERE c.customer_id IS NULL
        )::BIGINT,
        0::BIGINT

    UNION ALL

    SELECT
        'orphan_items_orders',
        (
            SELECT COUNT(*)
            FROM olist.order_items AS oi
            LEFT JOIN olist.orders AS o
                ON oi.order_id = o.order_id
            WHERE o.order_id IS NULL
        )::BIGINT,
        0::BIGINT

    UNION ALL

    SELECT
        'orphan_items_products',
        (
            SELECT COUNT(*)
            FROM olist.order_items AS oi
            LEFT JOIN olist.products AS p
                ON oi.product_id = p.product_id
            WHERE p.product_id IS NULL
        )::BIGINT,
        0::BIGINT

    UNION ALL

    SELECT
        'orphan_items_sellers',
        (
            SELECT COUNT(*)
            FROM olist.order_items AS oi
            LEFT JOIN olist.sellers AS s
                ON oi.seller_id = s.seller_id
            WHERE s.seller_id IS NULL
        )::BIGINT,
        0::BIGINT

    UNION ALL

    SELECT
        'orphan_payments_orders',
        (
            SELECT COUNT(*)
            FROM olist.payments AS p
            LEFT JOIN olist.orders AS o
                ON p.order_id = o.order_id
            WHERE o.order_id IS NULL
        )::BIGINT,
        0::BIGINT

    UNION ALL

    SELECT
        'orphan_reviews_orders',
        (
            SELECT COUNT(*)
            FROM olist.reviews AS r
            LEFT JOIN olist.orders AS o
                ON r.order_id = o.order_id
            WHERE o.order_id IS NULL
        )::BIGINT,
        0::BIGINT

    UNION ALL

    SELECT
        'orphan_products_categories',
        (
            SELECT COUNT(*)
            FROM olist.products AS p
            LEFT JOIN olist.category_translation AS ct
                ON p.product_category_name
                   = ct.product_category_name
            WHERE ct.product_category_name IS NULL
        )::BIGINT,
        0::BIGINT

    -- Data-quality checks

    UNION ALL

    SELECT
        'invalid_payment_installments',
        (
            SELECT COUNT(*)
            FROM olist.payments
            WHERE payment_installments < 1
        )::BIGINT,
        0::BIGINT

    UNION ALL

    SELECT
        'non_positive_product_weights',
        (
            SELECT COUNT(*)
            FROM olist.products
            WHERE product_weight_g <= 0
        )::BIGINT,
        0::BIGINT

    UNION ALL

    SELECT
        'missing_english_categories',
        (
            SELECT COUNT(*)
            FROM olist.products
            WHERE product_category_name_english IS NULL
        )::BIGINT,
        0::BIGINT

    UNION ALL

    SELECT
        'invalid_geolocation_coordinates',
        (
            SELECT COUNT(*)
            FROM olist.geolocation
            WHERE geolocation_lat NOT BETWEEN -90 AND 90
               OR geolocation_lng NOT BETWEEN -180 AND 180
        )::BIGINT,
        0::BIGINT

    -- Database-structure checks

    UNION ALL

    SELECT
        'foreign_key_count',
        (
            SELECT COUNT(*)
            FROM information_schema.table_constraints
            WHERE table_schema = 'olist'
              AND constraint_type = 'FOREIGN KEY'
        )::BIGINT,
        7::BIGINT

    UNION ALL

    SELECT
        'custom_index_count',
        (
            SELECT COUNT(*)
            FROM pg_indexes
            WHERE schemaname = 'olist'
              AND indexname LIKE 'idx_%'
        )::BIGINT,
        9::BIGINT
)

SELECT
    check_name,
    actual_value,
    expected_value,
    CASE
        WHEN actual_value = expected_value
            THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM checks;
SELECT *
FROM olist.v_database_validation
ORDER BY check_name;

SELECT
    status,
    COUNT(*) AS number_of_checks
FROM olist.v_database_validation
GROUP BY status
ORDER BY status;

\copy (SELECT * FROM olist.v_database_validation ORDER BY check_name) TO 'reports/database_validation.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');