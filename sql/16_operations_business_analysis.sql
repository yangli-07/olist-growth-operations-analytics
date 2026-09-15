\set ON_ERROR_STOP on
\pset pager off

BEGIN;

-- =====================================================
-- Overall operations KPIs
-- =====================================================

CREATE OR REPLACE VIEW
analytics.v_operations_kpis AS

WITH order_metrics AS (
    SELECT
        COUNT(*) AS completed_order_count,

        COUNT(*) FILTER (
            WHERE is_valid_delivery_record
        ) AS valid_delivery_order_count,

        COUNT(*) FILTER (
            WHERE is_valid_delivery_record
              AND is_late_delivery
        ) AS late_delivery_order_count,

        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE is_valid_delivery_record
                  AND is_late_delivery
            )
            / NULLIF(
                COUNT(*) FILTER (
                    WHERE is_valid_delivery_record
                ),
                0
            ),
            2
        ) AS late_delivery_rate_pct,

        ROUND(
            AVG(delivery_days) FILTER (
                WHERE is_valid_delivery_record
            ),
            2
        ) AS average_delivery_days,

        ROUND(
            AVG(estimated_delivery_days) FILTER (
                WHERE is_valid_delivery_record
            ),
            2
        ) AS average_estimated_delivery_days,

        ROUND(
            AVG(carrier_handling_days) FILTER (
                WHERE is_valid_delivery_record
            ),
            2
        ) AS average_carrier_handling_days,

        ROUND(
            AVG(delivery_delay_days) FILTER (
                WHERE is_valid_delivery_record
            ),
            2
        ) AS average_delivery_delay_days,

        ROUND(
            AVG(delivery_delay_days) FILTER (
                WHERE is_valid_delivery_record
                  AND is_late_delivery
            ),
            2
        ) AS average_delay_days_when_late,

        COUNT(*) FILTER (
            WHERE has_review_record
        ) AS reviewed_order_count,

        ROUND(
            AVG(average_review_score) FILTER (
                WHERE has_review_record
            ),
            2
        ) AS average_review_score,

        COUNT(*) FILTER (
            WHERE average_review_score <= 2
        ) AS low_review_order_count,

        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE average_review_score <= 2
            )
            / NULLIF(
                COUNT(*) FILTER (
                    WHERE has_review_record
                ),
                0
            ),
            2
        ) AS low_review_rate_pct

    FROM analytics.v_order_summary

    WHERE order_status = 'delivered'
      AND payment_value_total IS NOT NULL
),

seller_order_metrics AS (
    SELECT
        COUNT(*) AS seller_order_count,

        COUNT(*) FILTER (
            WHERE shipped_after_shipping_limit
        ) AS shipping_limit_breach_count,

        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE shipped_after_shipping_limit
            )
            / NULLIF(COUNT(*), 0),
            2
        ) AS shipping_limit_breach_rate_pct,

        COUNT(*) FILTER (
            WHERE is_same_state_delivery
        ) AS same_state_seller_order_count,

        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE is_same_state_delivery
            )
            / NULLIF(
                COUNT(*) FILTER (
                    WHERE is_same_state_delivery
                       IS NOT NULL
                ),
                0
            ),
            2
        ) AS same_state_delivery_rate_pct

    FROM analytics.v_seller_order_performance
)

SELECT
    om.*,
    som.seller_order_count,
    som.shipping_limit_breach_count,
    som.shipping_limit_breach_rate_pct,
    som.same_state_seller_order_count,
    som.same_state_delivery_rate_pct

FROM order_metrics AS om

CROSS JOIN seller_order_metrics AS som;


-- =====================================================
-- Delivery and review relationship
-- =====================================================

CREATE OR REPLACE VIEW
analytics.v_delivery_review_impact AS

SELECT
    CASE
        WHEN is_late_delivery
            THEN 'Late'
        ELSE 'On Time or Early'
    END AS delivery_status,

    COUNT(*) AS order_count,

    COUNT(*) FILTER (
        WHERE has_review_record
    ) AS reviewed_order_count,

    ROUND(
        AVG(delivery_days),
        2
    ) AS average_delivery_days,

    ROUND(
        AVG(delivery_delay_days),
        2
    ) AS average_delivery_delay_days,

    ROUND(
        AVG(average_review_score) FILTER (
            WHERE has_review_record
        ),
        2
    ) AS average_review_score,

    COUNT(*) FILTER (
        WHERE average_review_score <= 2
    ) AS low_review_order_count,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE average_review_score <= 2
        )
        / NULLIF(
            COUNT(*) FILTER (
                WHERE has_review_record
            ),
            0
        ),
        2
    ) AS low_review_rate_pct,

    COUNT(*) FILTER (
        WHERE has_written_comment
    ) AS written_comment_order_count,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE has_written_comment
        )
        / NULLIF(
            COUNT(*) FILTER (
                WHERE has_review_record
            ),
            0
        ),
        2
    ) AS written_comment_rate_pct

FROM analytics.v_order_summary

WHERE order_status = 'delivered'
  AND payment_value_total IS NOT NULL
  AND is_valid_delivery_record

GROUP BY
    CASE
        WHEN is_late_delivery
            THEN 'Late'
        ELSE 'On Time or Early'
    END;


-- =====================================================
-- Seller risk classification
-- Minimum 20 deliveries and 20 reviewed orders
-- =====================================================

CREATE OR REPLACE VIEW
analytics.v_seller_risk AS

WITH eligible_sellers AS (
    SELECT
        seller_id,
        seller_city,
        seller_state,
        completed_order_count,
        customer_count,
        item_count,
        item_price_total,
        valid_delivery_order_count,
        late_delivery_rate_pct,
        average_delivery_days,
        shipping_limit_breach_rate_pct,
        reviewed_order_count,
        average_review_score,
        low_review_rate_pct,
        seller_revenue_rank,
        seller_revenue_share_pct,

        NTILE(4) OVER (
            ORDER BY
                late_delivery_rate_pct,
                seller_id
        ) AS late_delivery_quartile,

        NTILE(4) OVER (
            ORDER BY
                shipping_limit_breach_rate_pct,
                seller_id
        ) AS shipping_breach_quartile,

        NTILE(4) OVER (
            ORDER BY
                low_review_rate_pct,
                seller_id
        ) AS low_review_quartile

    FROM analytics.v_seller_performance

    WHERE valid_delivery_order_count >= 20
      AND reviewed_order_count >= 20
),

risk_scores AS (
    SELECT
        *,

        late_delivery_quartile
        + shipping_breach_quartile
        + low_review_quartile
            AS operational_risk_score

    FROM eligible_sellers
)

SELECT
    *,

    seller_revenue_rank <= 100
        AS is_high_value_seller,

    CASE
        WHEN operational_risk_score >= 10
         AND seller_revenue_rank <= 100
            THEN 'High-Value At Risk'

        WHEN operational_risk_score >= 10
            THEN 'High Risk'

        WHEN operational_risk_score >= 7
            THEN 'Monitor'

        ELSE 'Stable'
    END AS seller_risk_segment

FROM risk_scores;

COMMIT;


-- =====================================================
-- Validation view
-- =====================================================

CREATE OR REPLACE VIEW
analytics.v_operations_validation AS

WITH source_metrics AS (
    SELECT
        COUNT(*)::NUMERIC
            AS completed_order_count,

        COUNT(*) FILTER (
            WHERE is_valid_delivery_record
        )::NUMERIC
            AS valid_delivery_order_count

    FROM analytics.v_order_summary

    WHERE order_status = 'delivered'
      AND payment_value_total IS NOT NULL
)

SELECT
    'monthly_completed_orders'
        AS metric_name,

    s.completed_order_count
        AS expected_value,

    (
        SELECT SUM(completed_order_count)
        FROM analytics.v_monthly_delivery_performance
    )::NUMERIC AS actual_value,

    (
        SELECT SUM(completed_order_count)
        FROM analytics.v_monthly_delivery_performance
    )::NUMERIC - s.completed_order_count
        AS difference,

    (
        SELECT SUM(completed_order_count)
        FROM analytics.v_monthly_delivery_performance
    )::NUMERIC = s.completed_order_count
        AS passed

FROM source_metrics AS s

UNION ALL

SELECT
    'state_completed_orders',
    s.completed_order_count,

    (
        SELECT SUM(completed_order_count)
        FROM analytics.v_state_delivery_performance
    )::NUMERIC,

    (
        SELECT SUM(completed_order_count)
        FROM analytics.v_state_delivery_performance
    )::NUMERIC - s.completed_order_count,

    (
        SELECT SUM(completed_order_count)
        FROM analytics.v_state_delivery_performance
    )::NUMERIC = s.completed_order_count

FROM source_metrics AS s

UNION ALL

SELECT
    'overall_completed_orders',
    s.completed_order_count,

    (
        SELECT completed_order_count
        FROM analytics.v_operations_kpis
    )::NUMERIC,

    (
        SELECT completed_order_count
        FROM analytics.v_operations_kpis
    )::NUMERIC - s.completed_order_count,

    (
        SELECT completed_order_count
        FROM analytics.v_operations_kpis
    )::NUMERIC = s.completed_order_count

FROM source_metrics AS s

UNION ALL

SELECT
    'delivery_status_orders',
    s.valid_delivery_order_count,

    (
        SELECT SUM(order_count)
        FROM analytics.v_delivery_review_impact
    )::NUMERIC,

    (
        SELECT SUM(order_count)
        FROM analytics.v_delivery_review_impact
    )::NUMERIC - s.valid_delivery_order_count,

    (
        SELECT SUM(order_count)
        FROM analytics.v_delivery_review_impact
    )::NUMERIC = s.valid_delivery_order_count

FROM source_metrics AS s

UNION ALL

SELECT
    'seller_duplicate_grains',
    0,

    (
        SELECT
            COUNT(*) - COUNT(DISTINCT seller_id)
        FROM analytics.v_seller_performance
    )::NUMERIC,

    (
        SELECT
            COUNT(*) - COUNT(DISTINCT seller_id)
        FROM analytics.v_seller_performance
    )::NUMERIC,

    (
        SELECT
            COUNT(*) = COUNT(DISTINCT seller_id)
        FROM analytics.v_seller_performance
    )

FROM source_metrics AS s

UNION ALL

SELECT
    'seller_order_duplicate_grains',
    0,

    (
        SELECT
            COUNT(*)
            - COUNT(
                DISTINCT (
                    order_id,
                    seller_id
                )
            )
        FROM analytics.v_seller_order_performance
    )::NUMERIC,

    (
        SELECT
            COUNT(*)
            - COUNT(
                DISTINCT (
                    order_id,
                    seller_id
                )
            )
        FROM analytics.v_seller_order_performance
    )::NUMERIC,

    (
        SELECT
            COUNT(*)
            = COUNT(
                DISTINCT (
                    order_id,
                    seller_id
                )
            )
        FROM analytics.v_seller_order_performance
    )

FROM source_metrics AS s;


-- =====================================================
-- Display results
-- =====================================================

SELECT *
FROM analytics.v_operations_kpis;

SELECT *
FROM analytics.v_delivery_review_impact
ORDER BY delivery_status;

SELECT
    seller_risk_segment,
    COUNT(*) AS seller_count,

    COUNT(*) FILTER (
        WHERE is_high_value_seller
    ) AS high_value_seller_count,

    ROUND(
        AVG(late_delivery_rate_pct),
        2
    ) AS average_late_delivery_rate_pct,

    ROUND(
        AVG(low_review_rate_pct),
        2
    ) AS average_low_review_rate_pct,

    ROUND(
        SUM(item_price_total),
        2
    ) AS item_price_total

FROM analytics.v_seller_risk

GROUP BY seller_risk_segment

ORDER BY item_price_total DESC;

SELECT *
FROM analytics.v_operations_validation
ORDER BY metric_name;


-- =====================================================
-- Export reports
-- =====================================================

\copy (SELECT * FROM analytics.v_operations_kpis) TO 'reports/overall_operations_kpis.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_monthly_delivery_performance ORDER BY purchase_month) TO 'reports/monthly_delivery_performance.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_state_delivery_performance ORDER BY completed_order_count DESC) TO 'reports/state_delivery_performance.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_seller_performance ORDER BY item_price_total DESC) TO 'reports/seller_performance.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_seller_risk WHERE seller_risk_segment <> 'Stable' ORDER BY is_high_value_seller DESC, operational_risk_score DESC, item_price_total DESC) TO 'reports/priority_sellers.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_delivery_review_impact ORDER BY delivery_status) TO 'reports/delivery_review_impact.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_operations_validation ORDER BY metric_name) TO 'reports/operations_validation.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');
