\set ON_ERROR_STOP on

BEGIN;

CREATE SCHEMA IF NOT EXISTS analytics;

-- One row per order containing item-level totals

CREATE OR REPLACE VIEW
analytics.v_order_items_agg AS

SELECT
    order_id,
    COUNT(*)::INTEGER AS item_count,
    COUNT(
        DISTINCT product_id
    )::INTEGER AS distinct_product_count,
    COUNT(
        DISTINCT seller_id
    )::INTEGER AS seller_count,
    SUM(price)::NUMERIC(14, 2)
        AS item_price_total,
    SUM(freight_value)::NUMERIC(14, 2)
        AS freight_total,
    SUM(
        price + freight_value
    )::NUMERIC(14, 2)
        AS gross_item_value
FROM olist.order_items
GROUP BY order_id;


-- One row per order containing payment totals

CREATE OR REPLACE VIEW
analytics.v_payments_agg AS

SELECT
    order_id,
    COUNT(*)::INTEGER
        AS payment_record_count,
    COUNT(
        DISTINCT payment_type
    )::INTEGER
        AS payment_type_count,
    SUM(payment_value)::NUMERIC(14, 2)
        AS payment_value_total,
    MAX(payment_installments)
        AS maximum_installments,
    STRING_AGG(
        DISTINCT payment_type,
        ', '
        ORDER BY payment_type
    ) AS payment_types,
    BOOL_OR(
        payment_type = 'credit_card'
    ) AS uses_credit_card,
    BOOL_OR(
        payment_type = 'voucher'
    ) AS uses_voucher
FROM olist.payments
GROUP BY order_id;


-- One row per order containing review metrics

CREATE OR REPLACE VIEW
analytics.v_reviews_agg AS

SELECT
    order_id,
    COUNT(*)::INTEGER
        AS review_record_count,
    ROUND(
        AVG(review_score)::NUMERIC,
        2
    ) AS average_review_score,
    MIN(review_score)
        AS minimum_review_score,
    MAX(review_score)
        AS maximum_review_score,
    MIN(review_creation_date)
        AS first_review_date,
    MAX(review_answer_timestamp)
        AS latest_review_answer,
    BOOL_OR(
        review_comment_message IS NOT NULL
        AND BTRIM(
            review_comment_message
        ) <> ''
    ) AS has_written_comment
FROM olist.reviews
GROUP BY order_id;

COMMIT;


-- Confirm that each view contains one row per order

SELECT
    'v_order_items_agg' AS view_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT order_id)
        AS distinct_order_count
FROM analytics.v_order_items_agg

UNION ALL

SELECT
    'v_payments_agg',
    COUNT(*),
    COUNT(DISTINCT order_id)
FROM analytics.v_payments_agg

UNION ALL

SELECT
    'v_reviews_agg',
    COUNT(*),
    COUNT(DISTINCT order_id)
FROM analytics.v_reviews_agg

ORDER BY view_name;

BEGIN;

-- Main order-level analytical view
-- Grain: one row per order

CREATE OR REPLACE VIEW
analytics.v_order_summary AS

SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,

    o.order_status,
    o.order_purchase_timestamp,
    o.order_purchase_timestamp::DATE
        AS purchase_date,
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )::DATE AS purchase_month,
    EXTRACT(
        YEAR FROM o.order_purchase_timestamp
    )::SMALLINT AS purchase_year,
    EXTRACT(
        QUARTER FROM o.order_purchase_timestamp
    )::SMALLINT AS purchase_quarter,

    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    CASE
        WHEN o.order_approved_at IS NULL
            THEN NULL
        ELSE ROUND(
            (
                EXTRACT(
                    EPOCH FROM (
                        o.order_approved_at
                        - o.order_purchase_timestamp
                    )
                ) / 3600
            )::NUMERIC,
            2
        )
    END AS approval_hours,

    CASE
        WHEN o.order_delivered_carrier_date
            IS NULL
            THEN NULL
        ELSE
            o.order_delivered_carrier_date::DATE
            - o.order_purchase_timestamp::DATE
    END AS carrier_handling_days,

    CASE
        WHEN o.order_delivered_customer_date
            IS NULL
            THEN NULL
        ELSE
            o.order_delivered_customer_date::DATE
            - o.order_purchase_timestamp::DATE
    END AS delivery_days,

    o.order_estimated_delivery_date::DATE
        - o.order_purchase_timestamp::DATE
        AS estimated_delivery_days,

    CASE
        WHEN o.order_delivered_customer_date
            IS NULL
            THEN NULL
        ELSE
            o.order_delivered_customer_date::DATE
            - o.order_estimated_delivery_date::DATE
    END AS delivery_delay_days,

    CASE
        WHEN o.order_delivered_customer_date
            IS NULL
            THEN NULL
        ELSE
            o.order_delivered_customer_date::DATE
            > o.order_estimated_delivery_date::DATE
    END AS is_late_delivery,

    o.order_status = 'canceled'
        AS is_canceled,

    o.order_delivered_customer_date IS NOT NULL
        AS is_delivered,

    COALESCE(
        oi.item_count,
        0
    ) AS item_count,

    COALESCE(
        oi.distinct_product_count,
        0
    ) AS distinct_product_count,

    COALESCE(
        oi.seller_count,
        0
    ) AS seller_count,

    oi.item_price_total,
    oi.freight_total,
    oi.gross_item_value,

    COALESCE(
        pa.payment_record_count,
        0
    ) AS payment_record_count,

    COALESCE(
        pa.payment_type_count,
        0
    ) AS payment_type_count,

    pa.payment_value_total,
    pa.maximum_installments,
    pa.payment_types,
    pa.uses_credit_card,
    pa.uses_voucher,

    COALESCE(
        ra.review_record_count,
        0
    ) AS review_record_count,

    ra.average_review_score,
    ra.minimum_review_score,
    ra.maximum_review_score,
    ra.first_review_date,
    ra.latest_review_answer,
    ra.has_written_comment,

    CASE
        WHEN pa.payment_value_total IS NULL
          OR oi.gross_item_value IS NULL
            THEN NULL
        ELSE ROUND(
            pa.payment_value_total
            - oi.gross_item_value,
            2
        )
    END AS payment_difference,

    oi.order_id IS NOT NULL
        AS has_item_record,

    pa.order_id IS NOT NULL
        AS has_payment_record,

    ra.order_id IS NOT NULL
        AS has_review_record,

    o.has_timestamp_anomaly,
    o.has_status_date_mismatch,
    o.is_valid_delivery_record

FROM olist.orders AS o

LEFT JOIN olist.customers AS c
    ON o.customer_id = c.customer_id

LEFT JOIN analytics.v_order_items_agg AS oi
    ON o.order_id = oi.order_id

LEFT JOIN analytics.v_payments_agg AS pa
    ON o.order_id = pa.order_id

LEFT JOIN analytics.v_reviews_agg AS ra
    ON o.order_id = ra.order_id;


-- Item-level analytical view
-- Grain: one row per order item

CREATE OR REPLACE VIEW
analytics.v_order_item_detail AS

SELECT
    oi.order_id,
    oi.order_item_id,

    o.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,

    o.order_status,
    o.order_purchase_timestamp,
    o.order_purchase_timestamp::DATE
        AS purchase_date,
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )::DATE AS purchase_month,
    EXTRACT(
        YEAR FROM o.order_purchase_timestamp
    )::SMALLINT AS purchase_year,

    oi.product_id,
    p.product_category_name,
    p.product_category_name_english,

    oi.seller_id,
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state,

    oi.shipping_limit_date,
    oi.price,
    oi.freight_value,

    (
        oi.price + oi.freight_value
    )::NUMERIC(14, 2)
        AS gross_item_value,

    CASE
        WHEN o.order_delivered_carrier_date
            IS NULL
            THEN NULL
        ELSE
            o.order_delivered_carrier_date
            > oi.shipping_limit_date
    END AS shipped_after_shipping_limit,

    CASE
        WHEN o.order_delivered_customer_date
            IS NULL
            THEN NULL
        ELSE
            o.order_delivered_customer_date::DATE
            - o.order_purchase_timestamp::DATE
    END AS delivery_days,

    CASE
        WHEN o.order_delivered_customer_date
            IS NULL
            THEN NULL
        ELSE
            o.order_delivered_customer_date::DATE
            - o.order_estimated_delivery_date::DATE
    END AS delivery_delay_days,

    CASE
        WHEN o.order_delivered_customer_date
            IS NULL
            THEN NULL
        ELSE
            o.order_delivered_customer_date::DATE
            > o.order_estimated_delivery_date::DATE
    END AS is_late_delivery,

    o.has_timestamp_anomaly,
    o.has_status_date_mismatch,
    o.is_valid_delivery_record

FROM olist.order_items AS oi

LEFT JOIN olist.orders AS o
    ON oi.order_id = o.order_id

LEFT JOIN olist.customers AS c
    ON o.customer_id = c.customer_id

LEFT JOIN olist.products AS p
    ON oi.product_id = p.product_id

LEFT JOIN olist.sellers AS s
    ON oi.seller_id = s.seller_id;

COMMIT;


-- Validate the grain of the two analytical views

SELECT
    'v_order_summary' AS view_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT order_id)
        AS unique_grain_count
FROM analytics.v_order_summary

UNION ALL

SELECT
    'v_order_item_detail',
    COUNT(*),
    COUNT(
        DISTINCT (
            order_id,
            order_item_id
        )
    )
FROM analytics.v_order_item_detail

ORDER BY view_name;


-- Profile missing related records

SELECT
    COUNT(*) FILTER (
        WHERE NOT has_item_record
    ) AS orders_without_items,

    COUNT(*) FILTER (
        WHERE NOT has_payment_record
    ) AS orders_without_payments,

    COUNT(*) FILTER (
        WHERE NOT has_review_record
    ) AS orders_without_reviews

FROM analytics.v_order_summary;