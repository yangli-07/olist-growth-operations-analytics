\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE VIEW
analytics.v_customer_rfm AS

WITH reference_date AS (

    SELECT
        MAX(purchase_date) + 1
            AS analysis_reference_date

    FROM analytics.v_order_summary

    WHERE order_status = 'delivered'
      AND has_payment_record
),

completed_customer_metrics AS (

    SELECT
        customer_unique_id,

        MIN(purchase_date)
            AS first_completed_order_date,

        MAX(purchase_date)
            AS last_completed_order_date,

        COUNT(*) AS completed_order_count,

        SUM(payment_value_total)
            ::NUMERIC(16, 2)
            AS completed_payment_value,

        ROUND(
            AVG(payment_value_total)::NUMERIC,
            2
        ) AS average_completed_order_payment

    FROM analytics.v_order_summary

    WHERE order_status = 'delivered'
      AND has_payment_record

    GROUP BY customer_unique_id
),

rfm_values AS (

    SELECT
        metrics.customer_unique_id,
        reference.analysis_reference_date,
        metrics.first_completed_order_date,
        metrics.last_completed_order_date,

        reference.analysis_reference_date
            - metrics.last_completed_order_date
            AS recency_days,

        metrics.completed_order_count,
        metrics.completed_payment_value,
        metrics.average_completed_order_payment

    FROM completed_customer_metrics AS metrics

    CROSS JOIN reference_date AS reference
),

rfm_scored AS (

    SELECT
        customer_unique_id,
        analysis_reference_date,
        first_completed_order_date,
        last_completed_order_date,
        recency_days,
        completed_order_count,
        completed_payment_value,
        average_completed_order_payment,

        CASE
            WHEN recency_days <= 30 THEN 5
            WHEN recency_days <= 90 THEN 4
            WHEN recency_days <= 180 THEN 3
            WHEN recency_days <= 365 THEN 2
            ELSE 1
        END AS recency_score,

        LEAST(
            completed_order_count,
            5
        )::INTEGER AS frequency_score,

        NTILE(5) OVER (
            ORDER BY
                completed_payment_value,
                customer_unique_id
        ) AS monetary_score

    FROM rfm_values
),

all_customer_rfm AS (

    SELECT
        customer.customer_unique_id,
        customer.latest_customer_state,
        customer.order_count
            AS all_order_count,
        customer.total_payment_value
            AS all_order_payment_value,
        customer.is_repeat_customer,

        scored.analysis_reference_date,
        scored.first_completed_order_date,
        scored.last_completed_order_date,
        scored.recency_days,

        COALESCE(
            scored.completed_order_count,
            0
        ) AS completed_order_count,

        COALESCE(
            scored.completed_payment_value,
            0
        )::NUMERIC(16, 2)
            AS monetary_value,

        scored.average_completed_order_payment,

        COALESCE(
            scored.recency_score,
            0
        ) AS recency_score,

        COALESCE(
            scored.frequency_score,
            0
        ) AS frequency_score,

        COALESCE(
            scored.monetary_score,
            0
        ) AS monetary_score

    FROM analytics.v_customer_summary
        AS customer

    LEFT JOIN rfm_scored AS scored
        ON customer.customer_unique_id
           = scored.customer_unique_id
),

rfm_with_codes AS (

    SELECT
        *,

        recency_score
        + frequency_score
        + monetary_score
            AS rfm_total_score,

        CONCAT(
            recency_score,
            frequency_score,
            monetary_score
        ) AS rfm_code

    FROM all_customer_rfm
)

SELECT
    *,

    CASE
        WHEN completed_order_count = 0
            THEN 'No Completed Purchase'

        WHEN recency_score >= 4
         AND frequency_score >= 3
         AND monetary_score >= 4
            THEN 'Champions'

        WHEN recency_score >= 3
         AND frequency_score >= 3
            THEN 'Loyal Customers'

        WHEN recency_score >= 4
         AND frequency_score = 2
            THEN 'Potential Loyalists'

        WHEN recency_score = 5
         AND frequency_score = 1
            THEN 'New Customers'

        WHEN recency_score >= 4
         AND frequency_score = 1
            THEN 'Promising'

        WHEN recency_score <= 2
         AND monetary_score >= 4
            THEN 'High Value at Risk'

        WHEN recency_score <= 2
         AND frequency_score >= 2
            THEN 'At Risk'

        WHEN recency_score <= 2
         AND frequency_score = 1
            THEN 'Hibernating'

        ELSE 'Need Attention'
    END AS customer_segment

FROM rfm_with_codes;


CREATE OR REPLACE VIEW
analytics.v_customer_segment_summary AS

SELECT
    customer_segment,

    COUNT(*) AS customer_count,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct,

    SUM(completed_order_count)
        AS completed_order_count,

    SUM(monetary_value)
        ::NUMERIC(16, 2)
        AS monetary_value,

    ROUND(
        AVG(recency_days)::NUMERIC,
        2
    ) AS average_recency_days,

    ROUND(
        AVG(completed_order_count)::NUMERIC,
        2
    ) AS average_completed_orders,

    ROUND(
        AVG(monetary_value)::NUMERIC,
        2
    ) AS average_customer_value

FROM analytics.v_customer_rfm

GROUP BY customer_segment;

COMMIT;


-- Validate customer-level grain and RFM scores

SELECT
    COUNT(*) AS customer_count,

    COUNT(
        DISTINCT customer_unique_id
    ) AS unique_customer_count,

    COUNT(*) FILTER (
        WHERE customer_segment IS NULL
    ) AS unsegmented_customer_count,

    COUNT(*) FILTER (
        WHERE completed_order_count > 0
          AND (
              recency_score NOT BETWEEN 1 AND 5
              OR frequency_score NOT BETWEEN 1 AND 5
              OR monetary_score NOT BETWEEN 1 AND 5
          )
    ) AS invalid_score_count,

    COUNT(*) FILTER (
        WHERE completed_order_count = 0
    ) AS customers_without_completed_purchase

FROM analytics.v_customer_rfm;


-- Reconcile completed orders and payment value

SELECT
    (
        SELECT SUM(completed_order_count)
        FROM analytics.v_customer_rfm
    ) AS rfm_completed_orders,

    (
        SELECT COUNT(*)
        FROM analytics.v_order_summary
        WHERE order_status = 'delivered'
          AND has_payment_record
    ) AS source_completed_orders,

    (
        SELECT SUM(monetary_value)
        FROM analytics.v_customer_rfm
    ) AS rfm_payment_value,

    (
        SELECT SUM(payment_value_total)
        FROM analytics.v_order_summary
        WHERE order_status = 'delivered'
          AND has_payment_record
    ) AS source_payment_value;


-- Display segment summary

SELECT
    customer_segment,
    customer_count,
    customer_share_pct,
    completed_order_count,
    monetary_value,
    average_recency_days,
    average_customer_value

FROM analytics.v_customer_segment_summary

ORDER BY
    monetary_value DESC,
    customer_count DESC;
    