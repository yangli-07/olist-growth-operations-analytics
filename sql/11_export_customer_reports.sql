\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE VIEW
analytics.v_customer_analytics_validation AS

WITH checks (
    check_name,
    actual_value,
    expected_value
) AS (

    SELECT
        'customer_summary_row_count',
        COUNT(*)::NUMERIC,
        96096::NUMERIC
    FROM analytics.v_customer_summary

    UNION ALL

    SELECT
        'customer_summary_unique_customers',
        COUNT(
            DISTINCT customer_unique_id
        )::NUMERIC,
        96096::NUMERIC
    FROM analytics.v_customer_summary

    UNION ALL

    SELECT
        'customer_summary_order_reconciliation',
        SUM(order_count)::NUMERIC,
        99441::NUMERIC
    FROM analytics.v_customer_summary

    UNION ALL

    SELECT
        'repeat_customer_count',
        COUNT(*)::NUMERIC,
        2997::NUMERIC
    FROM analytics.v_customer_summary
    WHERE is_repeat_customer

    UNION ALL

    SELECT
        'one_time_customer_count',
        COUNT(*)::NUMERIC,
        93099::NUMERIC
    FROM analytics.v_customer_summary
    WHERE NOT is_repeat_customer

    UNION ALL

    SELECT
        'monthly_new_customer_reconciliation',
        SUM(new_customer_count)::NUMERIC,
        96096::NUMERIC
    FROM analytics.v_monthly_customer_metrics

    UNION ALL

    SELECT
        'monthly_order_reconciliation',
        SUM(order_count)::NUMERIC,
        99441::NUMERIC
    FROM analytics.v_monthly_customer_metrics

    UNION ALL

    SELECT
        'monthly_customer_balance_mismatch',
        COUNT(*)::NUMERIC,
        0::NUMERIC
    FROM analytics.v_monthly_customer_metrics
    WHERE active_customer_count
          <> new_customer_count
             + returning_customer_count

    UNION ALL

    SELECT
        'negative_months_since_first_order',
        COUNT(*)::NUMERIC,
        0::NUMERIC
    FROM analytics.v_customer_monthly_activity
    WHERE months_since_first_order < 0

    UNION ALL

    SELECT
        'cohort_month_0_customer_reconciliation',
        SUM(active_customer_count)::NUMERIC,
        96096::NUMERIC
    FROM analytics.v_customer_cohort_retention
    WHERE months_since_first_order = 0

    UNION ALL

    SELECT
        'invalid_month_0_retention',
        COUNT(*)::NUMERIC,
        0::NUMERIC
    FROM analytics.v_customer_cohort_retention
    WHERE months_since_first_order = 0
      AND retention_rate_pct <> 100

    UNION ALL

    SELECT
        'invalid_retention_rate',
        COUNT(*)::NUMERIC,
        0::NUMERIC
    FROM analytics.v_customer_cohort_retention
    WHERE retention_rate_pct < 0
       OR retention_rate_pct > 100

    UNION ALL

    SELECT
        'rfm_customer_row_count',
        COUNT(*)::NUMERIC,
        96096::NUMERIC
    FROM analytics.v_customer_rfm

    UNION ALL

    SELECT
        'rfm_unique_customer_count',
        COUNT(
            DISTINCT customer_unique_id
        )::NUMERIC,
        96096::NUMERIC
    FROM analytics.v_customer_rfm

    UNION ALL

    SELECT
        'rfm_unsegmented_customers',
        COUNT(*)::NUMERIC,
        0::NUMERIC
    FROM analytics.v_customer_rfm
    WHERE customer_segment IS NULL

    UNION ALL

    SELECT
        'rfm_invalid_scores',
        COUNT(*)::NUMERIC,
        0::NUMERIC
    FROM analytics.v_customer_rfm
    WHERE (
        completed_order_count > 0
        AND (
            recency_score NOT BETWEEN 1 AND 5
            OR frequency_score NOT BETWEEN 1 AND 5
            OR monetary_score NOT BETWEEN 1 AND 5
        )
    )
    OR (
        completed_order_count = 0
        AND (
            recency_score <> 0
            OR frequency_score <> 0
            OR monetary_score <> 0
        )
    )

    UNION ALL

    SELECT
        'rfm_completed_order_reconciliation',
        (
            SELECT SUM(completed_order_count)
            FROM analytics.v_customer_rfm
        )::NUMERIC,
        (
            SELECT COUNT(*)
            FROM analytics.v_order_summary
            WHERE order_status = 'delivered'
              AND has_payment_record
        )::NUMERIC

    UNION ALL

    SELECT
        'rfm_payment_value_reconciliation',
        (
            SELECT SUM(monetary_value)
            FROM analytics.v_customer_rfm
        )::NUMERIC,
        (
            SELECT SUM(payment_value_total)
            FROM analytics.v_order_summary
            WHERE order_status = 'delivered'
              AND has_payment_record
        )::NUMERIC

    UNION ALL

    SELECT
        'segment_customer_reconciliation',
        SUM(customer_count)::NUMERIC,
        96096::NUMERIC
    FROM analytics.v_customer_segment_summary

    UNION ALL

    SELECT
        'customers_without_completed_purchase',
        COUNT(*)::NUMERIC,
        2739::NUMERIC
    FROM analytics.v_customer_rfm
    WHERE completed_order_count = 0
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
FROM analytics.v_customer_analytics_validation
ORDER BY check_name;


SELECT
    status,
    COUNT(*) AS number_of_checks
FROM analytics.v_customer_analytics_validation
GROUP BY status
ORDER BY status;


\copy (SELECT * FROM analytics.v_monthly_customer_metrics ORDER BY activity_month) TO 'reports/monthly_customer_metrics.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_customer_cohort_retention ORDER BY cohort_month, months_since_first_order) TO 'reports/customer_cohort_retention.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_cohort_retention_matrix_12m ORDER BY cohort_month) TO 'reports/cohort_retention_matrix_12m.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_customer_segment_summary ORDER BY monetary_value DESC) TO 'reports/customer_segment_summary.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_customer_analytics_validation ORDER BY check_name) TO 'reports/customer_analytics_validation.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');