\set ON_ERROR_STOP on

BEGIN;

-- Overall customer KPIs

CREATE OR REPLACE VIEW
analytics.v_customer_kpi_summary AS

SELECT
    COUNT(*) AS total_customer_count,

    COUNT(*) FILTER (
        WHERE is_repeat_customer
    ) AS all_order_repeat_customer_count,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE is_repeat_customer
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS all_order_repeat_customer_rate_pct,

    COUNT(*) FILTER (
        WHERE completed_order_count > 0
    ) AS completed_purchase_customer_count,

    COUNT(*) FILTER (
        WHERE completed_order_count = 0
    ) AS no_completed_purchase_customer_count,

    COUNT(*) FILTER (
        WHERE completed_order_count > 1
    ) AS completed_repeat_customer_count,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE completed_order_count > 1
        )
        / NULLIF(
            COUNT(*) FILTER (
                WHERE completed_order_count > 0
            ),
            0
        ),
        2
    ) AS completed_repeat_customer_rate_pct,

    SUM(completed_order_count)
        AS completed_order_count,

    SUM(monetary_value)
        ::NUMERIC(16, 2)
        AS completed_payment_value,

    ROUND(
        SUM(monetary_value)
        / NULLIF(
            SUM(completed_order_count),
            0
        ),
        2
    ) AS average_completed_order_value,

    ROUND(
        SUM(monetary_value)
        / NULLIF(
            COUNT(*) FILTER (
                WHERE completed_order_count > 0
            ),
            0
        ),
        2
    ) AS average_completed_customer_value,

    ROUND(
        SUM(completed_order_count)::NUMERIC
        / NULLIF(
            COUNT(*) FILTER (
                WHERE completed_order_count > 0
            ),
            0
        ),
        2
    ) AS average_completed_orders_per_customer,

    MAX(analysis_reference_date)
        AS analysis_reference_date

FROM analytics.v_customer_rfm;


-- Complete calendar series for monthly growth

CREATE OR REPLACE VIEW
analytics.v_monthly_customer_growth AS

WITH date_bounds AS (

    SELECT
        MIN(activity_month)
            AS first_activity_month,
        MAX(activity_month)
            AS last_activity_month

    FROM analytics.v_monthly_customer_metrics
),

calendar_months AS (

    SELECT
        generated.month_start::DATE
            AS activity_month

    FROM date_bounds AS bounds

    CROSS JOIN LATERAL GENERATE_SERIES(
        bounds.first_activity_month,
        bounds.last_activity_month,
        INTERVAL '1 month'
    ) AS generated(month_start)
),

monthly_series AS (

    SELECT
        calendar.activity_month,

        COALESCE(
            metrics.active_customer_count,
            0
        ) AS active_customer_count,

        COALESCE(
            metrics.new_customer_count,
            0
        ) AS new_customer_count,

        COALESCE(
            metrics.returning_customer_count,
            0
        ) AS returning_customer_count,

        COALESCE(
            metrics.order_count,
            0
        ) AS order_count,

        COALESCE(
            metrics.payment_value,
            0
        )::NUMERIC(16, 2)
            AS payment_value

    FROM calendar_months AS calendar

    LEFT JOIN analytics.v_monthly_customer_metrics
        AS metrics
        ON calendar.activity_month
           = metrics.activity_month
),

monthly_with_previous AS (

    SELECT
        *,

        LAG(active_customer_count) OVER (
            ORDER BY activity_month
        ) AS previous_active_customer_count,

        LAG(new_customer_count) OVER (
            ORDER BY activity_month
        ) AS previous_new_customer_count,

        LAG(payment_value) OVER (
            ORDER BY activity_month
        ) AS previous_payment_value

    FROM monthly_series
)

SELECT
    activity_month,
    active_customer_count,
    new_customer_count,
    returning_customer_count,
    order_count,
    payment_value,

    previous_active_customer_count,
    previous_new_customer_count,
    previous_payment_value,

    ROUND(
        100.0
        * (
            active_customer_count
            - previous_active_customer_count
        )
        / NULLIF(
            previous_active_customer_count,
            0
        ),
        2
    ) AS active_customer_growth_pct,

    ROUND(
        100.0
        * (
            new_customer_count
            - previous_new_customer_count
        )
        / NULLIF(
            previous_new_customer_count,
            0
        ),
        2
    ) AS new_customer_growth_pct,

    ROUND(
        100.0
        * (
            payment_value
            - previous_payment_value
        )
        / NULLIF(
            previous_payment_value,
            0
        ),
        2
    ) AS payment_growth_pct

FROM monthly_with_previous;


-- Weighted cohort-retention benchmarks

CREATE OR REPLACE VIEW
analytics.v_cohort_retention_benchmark AS

SELECT
    months_since_first_order,

    COUNT(*) AS observed_cohort_count,

    SUM(cohort_size)
        AS combined_cohort_size,

    SUM(active_customer_count)
        AS active_customer_count,

    ROUND(
        100.0
        * SUM(active_customer_count)
        / NULLIF(
            SUM(cohort_size),
            0
        ),
        2
    ) AS weighted_retention_rate_pct,

    ROUND(
        AVG(retention_rate_pct),
        2
    ) AS average_cohort_retention_pct,

    MIN(retention_rate_pct)
        AS minimum_cohort_retention_pct,

    MAX(retention_rate_pct)
        AS maximum_cohort_retention_pct

FROM analytics.v_customer_cohort_retention

WHERE months_since_first_order <= 12

GROUP BY months_since_first_order;

COMMIT;


-- Overall customer KPIs

SELECT *
FROM analytics.v_customer_kpi_summary;


-- Five months with the most active customers

SELECT
    activity_month,
    active_customer_count,
    new_customer_count,
    returning_customer_count,
    order_count,
    payment_value,
    active_customer_growth_pct

FROM analytics.v_monthly_customer_growth

ORDER BY active_customer_count DESC

LIMIT 5;


-- Retention benchmarks for months 0 to 12

SELECT *
FROM analytics.v_cohort_retention_benchmark

ORDER BY months_since_first_order;


-- Export aggregate business reports

\copy (SELECT * FROM analytics.v_customer_kpi_summary) TO 'reports/customer_kpi_summary.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_monthly_customer_growth ORDER BY activity_month) TO 'reports/monthly_customer_growth.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_cohort_retention_benchmark ORDER BY months_since_first_order) TO 'reports/cohort_retention_benchmark.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');