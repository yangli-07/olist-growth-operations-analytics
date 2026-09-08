\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE VIEW
analytics.v_analytics_model_validation AS

WITH checks (
    check_name,
    actual_value,
    expected_value
) AS (

    SELECT
        'order_summary_row_count',
        COUNT(*)::NUMERIC,
        99441::NUMERIC
    FROM analytics.v_order_summary

    UNION ALL

    SELECT
        'order_summary_unique_orders',
        COUNT(DISTINCT order_id)::NUMERIC,
        99441::NUMERIC
    FROM analytics.v_order_summary

    UNION ALL

    SELECT
        'item_detail_row_count',
        COUNT(*)::NUMERIC,
        112650::NUMERIC
    FROM analytics.v_order_item_detail

    UNION ALL

    SELECT
        'item_detail_unique_items',
        COUNT(
            DISTINCT (
                order_id,
                order_item_id
            )
        )::NUMERIC,
        112650::NUMERIC
    FROM analytics.v_order_item_detail

    UNION ALL

    SELECT
        'items_aggregation_row_count',
        COUNT(*)::NUMERIC,
        98666::NUMERIC
    FROM analytics.v_order_items_agg

    UNION ALL

    SELECT
        'payments_aggregation_row_count',
        COUNT(*)::NUMERIC,
        99440::NUMERIC
    FROM analytics.v_payments_agg

    UNION ALL

    SELECT
        'reviews_aggregation_row_count',
        COUNT(*)::NUMERIC,
        98673::NUMERIC
    FROM analytics.v_reviews_agg

    UNION ALL

    SELECT
        'order_summary_item_count_total',
        SUM(item_count)::NUMERIC,
        112650::NUMERIC
    FROM analytics.v_order_summary

    UNION ALL

    SELECT
        'order_summary_review_count_total',
        SUM(review_record_count)::NUMERIC,
        99224::NUMERIC
    FROM analytics.v_order_summary

    UNION ALL

    SELECT
        'item_price_total_reconciliation',
        (
            SELECT SUM(item_price_total)
            FROM analytics.v_order_items_agg
        )::NUMERIC,
        (
            SELECT SUM(price)
            FROM olist.order_items
        )::NUMERIC

    UNION ALL

    SELECT
        'freight_total_reconciliation',
        (
            SELECT SUM(freight_total)
            FROM analytics.v_order_items_agg
        )::NUMERIC,
        (
            SELECT SUM(freight_value)
            FROM olist.order_items
        )::NUMERIC

    UNION ALL

    SELECT
        'gross_item_total_reconciliation',
        (
            SELECT SUM(gross_item_value)
            FROM analytics.v_order_items_agg
        )::NUMERIC,
        (
            SELECT SUM(
                price + freight_value
            )
            FROM olist.order_items
        )::NUMERIC

    UNION ALL

    SELECT
        'payment_total_reconciliation',
        (
            SELECT SUM(payment_value_total)
            FROM analytics.v_payments_agg
        )::NUMERIC,
        (
            SELECT SUM(payment_value)
            FROM olist.payments
        )::NUMERIC

    UNION ALL

    SELECT
        'item_detail_gross_reconciliation',
        (
            SELECT SUM(gross_item_value)
            FROM analytics.v_order_item_detail
        )::NUMERIC,
        (
            SELECT SUM(
                price + freight_value
            )
            FROM olist.order_items
        )::NUMERIC

    UNION ALL

    SELECT
        'missing_customer_unique_id',
        COUNT(*)::NUMERIC,
        0::NUMERIC
    FROM analytics.v_order_summary
    WHERE customer_unique_id IS NULL

    UNION ALL

    SELECT
        'missing_item_product_category',
        COUNT(*)::NUMERIC,
        0::NUMERIC
    FROM analytics.v_order_item_detail
    WHERE product_category_name_english
        IS NULL

    UNION ALL

    SELECT
        'missing_item_seller',
        COUNT(*)::NUMERIC,
        0::NUMERIC
    FROM analytics.v_order_item_detail
    WHERE seller_state IS NULL

    UNION ALL

    SELECT
        'invalid_valid_delivery_days',
        COUNT(*)::NUMERIC,
        0::NUMERIC
    FROM analytics.v_order_summary
    WHERE is_valid_delivery_record
      AND delivery_days < 0

    UNION ALL

    SELECT
        'late_delivery_flag_mismatch',
        COUNT(*)::NUMERIC,
        0::NUMERIC
    FROM analytics.v_order_summary
    WHERE delivery_delay_days IS NOT NULL
      AND is_late_delivery IS DISTINCT FROM (
          delivery_delay_days > 0
      )

    UNION ALL

    SELECT
        'orders_without_items',
        COUNT(*)::NUMERIC,
        775::NUMERIC
    FROM analytics.v_order_summary
    WHERE NOT has_item_record

    UNION ALL

    SELECT
        'orders_without_payments',
        COUNT(*)::NUMERIC,
        1::NUMERIC
    FROM analytics.v_order_summary
    WHERE NOT has_payment_record

    UNION ALL

    SELECT
        'orders_without_reviews',
        COUNT(*)::NUMERIC,
        768::NUMERIC
    FROM analytics.v_order_summary
    WHERE NOT has_review_record
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

COMMIT;


SELECT *
FROM analytics.v_analytics_model_validation
ORDER BY check_name;


SELECT
    status,
    COUNT(*) AS number_of_checks
FROM analytics.v_analytics_model_validation
GROUP BY status
ORDER BY status;


\copy (SELECT * FROM analytics.v_analytics_model_validation ORDER BY check_name) TO 'reports/analytics_model_validation.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');