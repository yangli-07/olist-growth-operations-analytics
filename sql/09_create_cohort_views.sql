\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE VIEW
analytics.v_customer_cohort_retention AS

WITH cohort_sizes AS (

    SELECT
        first_order_month
            AS cohort_month,
        COUNT(*) AS cohort_size

    FROM analytics.v_customer_summary

    GROUP BY first_order_month
),

latest_activity_month AS (

    SELECT
        MAX(activity_month)
            AS maximum_activity_month

    FROM analytics.v_customer_monthly_activity
),

cohort_grid AS (

    SELECT
        cohort.cohort_month,
        cohort.cohort_size,

        month_series.month_number
            AS months_since_first_order,

        (
            cohort.cohort_month
            + month_series.month_number
              * INTERVAL '1 month'
        )::DATE AS activity_month

    FROM cohort_sizes AS cohort

    CROSS JOIN latest_activity_month AS latest

    CROSS JOIN LATERAL GENERATE_SERIES(
        0,
        (
            (
                EXTRACT(
                    YEAR FROM
                    latest.maximum_activity_month
                )::INTEGER
                -
                EXTRACT(
                    YEAR FROM cohort.cohort_month
                )::INTEGER
            ) * 12
            +
            (
                EXTRACT(
                    MONTH FROM
                    latest.maximum_activity_month
                )::INTEGER
                -
                EXTRACT(
                    MONTH FROM cohort.cohort_month
                )::INTEGER
            )
        )
    ) AS month_series(month_number)
),

cohort_activity AS (

    SELECT
        cohort_month,
        activity_month,
        months_since_first_order,

        COUNT(*) AS active_customer_count,

        SUM(monthly_order_count)
            AS order_count,

        SUM(monthly_payment_value)
            ::NUMERIC(16, 2)
            AS payment_value

    FROM analytics.v_customer_monthly_activity

    GROUP BY
        cohort_month,
        activity_month,
        months_since_first_order
)

SELECT
    grid.cohort_month,
    grid.activity_month,
    grid.months_since_first_order,
    grid.cohort_size,

    COALESCE(
        activity.active_customer_count,
        0
    ) AS active_customer_count,

    grid.cohort_size
    - COALESCE(
        activity.active_customer_count,
        0
    ) AS inactive_customer_count,

    COALESCE(
        activity.order_count,
        0
    ) AS order_count,

    COALESCE(
        activity.payment_value,
        0
    )::NUMERIC(16, 2)
        AS payment_value,

    ROUND(
        100.0
        * COALESCE(
            activity.active_customer_count,
            0
        )
        / NULLIF(
            grid.cohort_size,
            0
        ),
        2
    ) AS retention_rate_pct,

    ROUND(
        COALESCE(
            activity.order_count,
            0
        )::NUMERIC
        / NULLIF(
            activity.active_customer_count,
            0
        ),
        2
    ) AS orders_per_active_customer,

    ROUND(
        COALESCE(
            activity.payment_value,
            0
        )
        / NULLIF(
            activity.active_customer_count,
            0
        ),
        2
    ) AS payment_per_active_customer

FROM cohort_grid AS grid

LEFT JOIN cohort_activity AS activity
    ON grid.cohort_month
       = activity.cohort_month
    AND grid.activity_month
       = activity.activity_month
    AND grid.months_since_first_order
       = activity.months_since_first_order;


CREATE OR REPLACE VIEW
analytics.v_cohort_retention_matrix_12m AS

SELECT
    cohort_month,
    cohort_size,

    MAX(retention_rate_pct) FILTER (
        WHERE months_since_first_order = 0
    ) AS month_0,

    MAX(retention_rate_pct) FILTER (
        WHERE months_since_first_order = 1
    ) AS month_1,

    MAX(retention_rate_pct) FILTER (
        WHERE months_since_first_order = 2
    ) AS month_2,

    MAX(retention_rate_pct) FILTER (
        WHERE months_since_first_order = 3
    ) AS month_3,

    MAX(retention_rate_pct) FILTER (
        WHERE months_since_first_order = 4
    ) AS month_4,

    MAX(retention_rate_pct) FILTER (
        WHERE months_since_first_order = 5
    ) AS month_5,

    MAX(retention_rate_pct) FILTER (
        WHERE months_since_first_order = 6
    ) AS month_6,

    MAX(retention_rate_pct) FILTER (
        WHERE months_since_first_order = 7
    ) AS month_7,

    MAX(retention_rate_pct) FILTER (
        WHERE months_since_first_order = 8
    ) AS month_8,

    MAX(retention_rate_pct) FILTER (
        WHERE months_since_first_order = 9
    ) AS month_9,

    MAX(retention_rate_pct) FILTER (
        WHERE months_since_first_order = 10
    ) AS month_10,

    MAX(retention_rate_pct) FILTER (
        WHERE months_since_first_order = 11
    ) AS month_11,

    MAX(retention_rate_pct) FILTER (
        WHERE months_since_first_order = 12
    ) AS month_12

FROM analytics.v_customer_cohort_retention

WHERE months_since_first_order <= 12

GROUP BY
    cohort_month,
    cohort_size;

COMMIT;


-- Validate the cohort model

SELECT
    COUNT(
        DISTINCT cohort_month
    ) AS cohort_count,

    SUM(active_customer_count) FILTER (
        WHERE months_since_first_order = 0
    ) AS reconstructed_customer_count,

    MIN(retention_rate_pct) FILTER (
        WHERE months_since_first_order = 0
    ) AS minimum_month_0_retention,

    MAX(retention_rate_pct) FILTER (
        WHERE months_since_first_order = 0
    ) AS maximum_month_0_retention,

    COUNT(*) FILTER (
        WHERE retention_rate_pct < 0
           OR retention_rate_pct > 100
    ) AS invalid_retention_rows

FROM analytics.v_customer_cohort_retention;


-- Preview one cohort

SELECT
    cohort_month,
    activity_month,
    months_since_first_order,
    cohort_size,
    active_customer_count,
    retention_rate_pct

FROM analytics.v_customer_cohort_retention

WHERE cohort_month = DATE '2017-01-01'

ORDER BY months_since_first_order

LIMIT 13;