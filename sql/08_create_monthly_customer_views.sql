\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE VIEW
analytics.v_customer_monthly_activity AS

WITH monthly_activity AS (

    SELECT
        customer_unique_id,
        purchase_month AS activity_month,

        COUNT(*) AS monthly_order_count,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
        ) AS monthly_delivered_order_count,

        SUM(item_count)
            AS monthly_item_count,

        COALESCE(
            SUM(payment_value_total),
            0
        )::NUMERIC(16, 2)
            AS monthly_payment_value,

        ROUND(
            AVG(payment_value_total)::NUMERIC,
            2
        ) AS monthly_average_order_payment

    FROM analytics.v_order_summary

    GROUP BY
        customer_unique_id,
        purchase_month
)

SELECT
    activity.customer_unique_id,

    customer.first_order_month
        AS cohort_month,

    activity.activity_month,

    (
        (
            EXTRACT(
                YEAR FROM activity.activity_month
            )::INTEGER
            -
            EXTRACT(
                YEAR FROM customer.first_order_month
            )::INTEGER
        ) * 12
        +
        (
            EXTRACT(
                MONTH FROM activity.activity_month
            )::INTEGER
            -
            EXTRACT(
                MONTH FROM customer.first_order_month
            )::INTEGER
        )
    ) AS months_since_first_order,

    activity.activity_month
        = customer.first_order_month
        AS is_new_customer,

    activity.activity_month
        > customer.first_order_month
        AS is_returning_customer,

    activity.monthly_order_count,
    activity.monthly_delivered_order_count,
    activity.monthly_item_count,
    activity.monthly_payment_value,
    activity.monthly_average_order_payment

FROM monthly_activity AS activity

INNER JOIN analytics.v_customer_summary
    AS customer
    ON activity.customer_unique_id
       = customer.customer_unique_id;


CREATE OR REPLACE VIEW
analytics.v_monthly_customer_metrics AS

SELECT
    activity_month,

    COUNT(*) AS active_customer_count,

    COUNT(*) FILTER (
        WHERE is_new_customer
    ) AS new_customer_count,

    COUNT(*) FILTER (
        WHERE is_returning_customer
    ) AS returning_customer_count,

    COUNT(*) FILTER (
        WHERE monthly_order_count > 1
    ) AS multi_order_customer_count,

    SUM(monthly_order_count)
        AS order_count,

    SUM(monthly_delivered_order_count)
        AS delivered_order_count,

    SUM(monthly_item_count)
        AS item_count,

    SUM(monthly_payment_value)
        ::NUMERIC(16, 2)
        AS payment_value,

    ROUND(
        SUM(monthly_payment_value)
        / NULLIF(
            SUM(monthly_order_count),
            0
        ),
        2
    ) AS average_payment_per_order,

    ROUND(
        SUM(monthly_order_count)::NUMERIC
        / NULLIF(COUNT(*), 0),
        2
    ) AS orders_per_active_customer,

    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE is_new_customer
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS new_customer_rate_pct,

    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE is_returning_customer
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS returning_customer_rate_pct

FROM analytics.v_customer_monthly_activity

GROUP BY activity_month;

COMMIT;


SELECT
    COUNT(*) AS month_count,

    MIN(activity_month)
        AS first_activity_month,

    MAX(activity_month)
        AS last_activity_month,

    SUM(new_customer_count)
        AS reconstructed_customer_count,

    SUM(order_count)
        AS reconstructed_order_count

FROM analytics.v_monthly_customer_metrics;


SELECT
    activity_month,
    active_customer_count,
    new_customer_count,
    returning_customer_count,
    order_count,
    payment_value,
    returning_customer_rate_pct

FROM analytics.v_monthly_customer_metrics

ORDER BY activity_month DESC

LIMIT 10;