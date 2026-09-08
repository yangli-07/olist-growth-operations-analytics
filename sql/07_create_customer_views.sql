\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE VIEW
analytics.v_customer_summary AS

WITH customer_metrics AS (

    SELECT
        customer_unique_id,

        MIN(order_purchase_timestamp)
            AS first_order_timestamp,

        MAX(order_purchase_timestamp)
            AS last_order_timestamp,

        MIN(purchase_date)
            AS first_order_date,

        MAX(purchase_date)
            AS last_order_date,

        DATE_TRUNC(
            'month',
            MIN(order_purchase_timestamp)
        )::DATE AS first_order_month,

        DATE_TRUNC(
            'month',
            MAX(order_purchase_timestamp)
        )::DATE AS last_order_month,

        COUNT(*) AS order_count,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
        ) AS delivered_order_count,

        COUNT(*) FILTER (
            WHERE order_status = 'canceled'
        ) AS canceled_order_count,

        COUNT(*) FILTER (
            WHERE has_payment_record
        ) AS paid_order_count,

        COUNT(*) FILTER (
            WHERE has_review_record
        ) AS reviewed_order_count,

        COUNT(*) FILTER (
            WHERE is_valid_delivery_record
        ) AS valid_delivery_order_count,

        COUNT(*) FILTER (
            WHERE is_valid_delivery_record
              AND is_late_delivery
        ) AS late_delivery_order_count,

        SUM(item_count)
            AS total_item_count,

        SUM(item_price_total)
            AS total_product_value,

        SUM(freight_total)
            AS total_freight_value,

        SUM(gross_item_value)
            AS total_gross_item_value,

        SUM(payment_value_total)
            AS total_payment_value,

        ROUND(
            AVG(payment_value_total)::NUMERIC,
            2
        ) AS average_order_payment,

        ROUND(
            AVG(item_count)::NUMERIC,
            2
        ) AS average_items_per_order,

        ROUND(
            AVG(average_review_score)::NUMERIC,
            2
        ) AS average_review_score,

        ROUND(
            AVG(delivery_days) FILTER (
                WHERE is_valid_delivery_record
            )::NUMERIC,
            2
        ) AS average_delivery_days

    FROM analytics.v_order_summary

    GROUP BY customer_unique_id
),

latest_customer_location AS (

    SELECT DISTINCT ON (
        customer_unique_id
    )
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state

    FROM analytics.v_order_summary

    ORDER BY
        customer_unique_id,
        order_purchase_timestamp DESC,
        order_id DESC
)

SELECT
    cm.customer_unique_id,

    location.customer_zip_code_prefix
        AS latest_zip_code_prefix,

    location.customer_city
        AS latest_customer_city,

    location.customer_state
        AS latest_customer_state,

    cm.first_order_timestamp,
    cm.last_order_timestamp,
    cm.first_order_date,
    cm.last_order_date,
    cm.first_order_month,
    cm.last_order_month,

    cm.last_order_date
        - cm.first_order_date
        AS customer_relationship_days,

    cm.order_count,
    cm.delivered_order_count,
    cm.canceled_order_count,
    cm.paid_order_count,
    cm.reviewed_order_count,
    cm.valid_delivery_order_count,
    cm.late_delivery_order_count,

    GREATEST(
        cm.order_count - 1,
        0
    ) AS repeat_order_count,

    cm.order_count > 1
        AS is_repeat_customer,

    COALESCE(
        cm.total_item_count,
        0
    ) AS total_item_count,

    COALESCE(
        cm.total_product_value,
        0
    )::NUMERIC(16, 2)
        AS total_product_value,

    COALESCE(
        cm.total_freight_value,
        0
    )::NUMERIC(16, 2)
        AS total_freight_value,

    COALESCE(
        cm.total_gross_item_value,
        0
    )::NUMERIC(16, 2)
        AS total_gross_item_value,

    COALESCE(
        cm.total_payment_value,
        0
    )::NUMERIC(16, 2)
        AS total_payment_value,

    cm.average_order_payment,
    cm.average_items_per_order,
    cm.average_review_score,
    cm.average_delivery_days,

    ROUND(
        100.0
        * cm.late_delivery_order_count
        / NULLIF(
            cm.valid_delivery_order_count,
            0
        ),
        2
    ) AS late_delivery_rate_pct

FROM customer_metrics AS cm

LEFT JOIN latest_customer_location AS location
    ON cm.customer_unique_id
       = location.customer_unique_id;

COMMIT;


-- Validate the customer-level grain

SELECT
    COUNT(*) AS customer_count,

    COUNT(
        DISTINCT customer_unique_id
    ) AS unique_customer_count,

    SUM(order_count)
        AS reconstructed_order_count,

    COUNT(*) FILTER (
        WHERE is_repeat_customer
    ) AS repeat_customer_count,

    COUNT(*) FILTER (
        WHERE NOT is_repeat_customer
    ) AS one_time_customer_count

FROM analytics.v_customer_summary;
