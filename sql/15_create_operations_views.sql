\set ON_ERROR_STOP on
\pset pager off

BEGIN;

-- =====================================================
-- Seller-order performance
-- One row per order and seller combination
-- =====================================================

CREATE OR REPLACE VIEW
analytics.v_seller_order_performance AS

WITH seller_order_items AS (
    SELECT
        order_id,
        seller_id,
        seller_city,
        seller_state,

        COUNT(*) AS item_count,

        COUNT(
            DISTINCT product_id
        ) AS distinct_product_count,

        COUNT(
            DISTINCT COALESCE(
                product_category_name_english,
                'unknown'
            )
        ) AS category_count,

        ROUND(
            SUM(price),
            2
        ) AS item_price_total,

        ROUND(
            SUM(freight_value),
            2
        ) AS freight_total,

        ROUND(
            SUM(gross_item_value),
            2
        ) AS gross_item_value,

        BOOL_OR(
            shipped_after_shipping_limit
        ) AS shipped_after_shipping_limit

    FROM analytics.v_order_item_detail

    GROUP BY
        order_id,
        seller_id,
        seller_city,
        seller_state
)

SELECT
    soi.order_id,
    soi.seller_id,
    soi.seller_city,
    soi.seller_state,

    os.customer_unique_id,
    os.customer_city,
    os.customer_state,

    os.purchase_date,
    os.purchase_month,

    soi.item_count,
    soi.distinct_product_count,
    soi.category_count,
    soi.item_price_total,
    soi.freight_total,
    soi.gross_item_value,

    soi.shipped_after_shipping_limit,

    os.carrier_handling_days,
    os.delivery_days,
    os.estimated_delivery_days,
    os.delivery_delay_days,
    os.is_late_delivery,
    os.is_valid_delivery_record,

    os.average_review_score,
    os.has_review_record,
    os.has_written_comment,

    os.seller_count > 1
        AS is_multi_seller_order,

    CASE
        WHEN soi.seller_state IS NULL
          OR os.customer_state IS NULL
            THEN NULL
        ELSE
            soi.seller_state
            = os.customer_state
    END AS is_same_state_delivery

FROM seller_order_items AS soi

INNER JOIN analytics.v_order_summary AS os
    ON soi.order_id = os.order_id

WHERE os.order_status = 'delivered'
  AND os.payment_value_total IS NOT NULL;


-- =====================================================
-- Seller performance
-- One row per seller
-- =====================================================

CREATE OR REPLACE VIEW
analytics.v_seller_performance AS

WITH seller_metrics AS (
    SELECT
        seller_id,
        MAX(seller_city) AS seller_city,
        MAX(seller_state) AS seller_state,

        COUNT(*) AS completed_order_count,

        COUNT(
            DISTINCT customer_unique_id
        ) AS customer_count,

        SUM(item_count) AS item_count,

        ROUND(
            SUM(item_price_total),
            2
        ) AS item_price_total,

        ROUND(
            SUM(freight_total),
            2
        ) AS freight_total,

        ROUND(
            SUM(gross_item_value),
            2
        ) AS gross_item_value,

        ROUND(
            SUM(item_price_total)
            / NULLIF(COUNT(*), 0),
            2
        ) AS average_item_value_per_order,

        ROUND(
            SUM(item_count)::NUMERIC
            / NULLIF(COUNT(*), 0),
            2
        ) AS average_items_per_order,

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
            AVG(carrier_handling_days) FILTER (
                WHERE is_valid_delivery_record
            ),
            2
        ) AS average_carrier_handling_days,

        ROUND(
            AVG(delivery_delay_days) FILTER (
                WHERE is_valid_delivery_record
                  AND is_late_delivery
            ),
            2
        ) AS average_delay_days_when_late,

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
        ) AS low_review_rate_pct,

        COUNT(*) FILTER (
            WHERE is_same_state_delivery
        ) AS same_state_order_count,

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
        ) AS same_state_delivery_rate_pct,

        MIN(purchase_date)
            AS first_completed_purchase_date,

        MAX(purchase_date)
            AS last_completed_purchase_date

    FROM analytics.v_seller_order_performance

    GROUP BY seller_id
),

seller_catalog AS (
    SELECT
        d.seller_id,

        COUNT(
            DISTINCT d.product_id
        ) AS distinct_product_count,

        COUNT(
            DISTINCT COALESCE(
                d.product_category_name_english,
                'unknown'
            )
        ) AS distinct_category_count

    FROM analytics.v_order_item_detail AS d

    INNER JOIN analytics.v_order_summary AS os
        ON d.order_id = os.order_id

    WHERE os.order_status = 'delivered'
      AND os.payment_value_total IS NOT NULL

    GROUP BY d.seller_id
),

combined AS (
    SELECT
        sm.*,
        sc.distinct_product_count,
        sc.distinct_category_count

    FROM seller_metrics AS sm

    LEFT JOIN seller_catalog AS sc
        ON sm.seller_id = sc.seller_id
)

SELECT
    *,

    DENSE_RANK() OVER (
        ORDER BY item_price_total DESC
    ) AS seller_revenue_rank,

    ROUND(
        100.0 * item_price_total
        / NULLIF(
            SUM(item_price_total) OVER (),
            0
        ),
        4
    ) AS seller_revenue_share_pct

FROM combined;

COMMIT;


-- =====================================================
-- Grain validation
-- =====================================================

SELECT
    'v_seller_order_performance'
        AS view_name,

    COUNT(*) AS row_count,

    COUNT(
        DISTINCT (
            order_id,
            seller_id
        )
    ) AS unique_grain_count

FROM analytics.v_seller_order_performance

UNION ALL

SELECT
    'v_seller_performance',

    COUNT(*),

    COUNT(DISTINCT seller_id)

FROM analytics.v_seller_performance;


-- =====================================================
-- Amount reconciliation
-- =====================================================

SELECT
    SUM(item_count)
        AS reconstructed_item_count,

    ROUND(
        SUM(item_price_total),
        2
    ) AS reconstructed_item_price,

    ROUND(
        SUM(freight_total),
        2
    ) AS reconstructed_freight

FROM analytics.v_seller_performance;


-- =====================================================
-- Preview highest-value sellers
-- =====================================================

SELECT
    seller_id,
    seller_state,
    completed_order_count,
    customer_count,
    item_price_total,
    late_delivery_rate_pct,
    shipping_limit_breach_rate_pct,
    average_review_score,
    low_review_rate_pct,
    seller_revenue_rank

FROM analytics.v_seller_performance

ORDER BY item_price_total DESC

LIMIT 10;

-- =====================================================
-- Monthly delivery performance
-- One row per calendar month
-- =====================================================

BEGIN;

CREATE OR REPLACE VIEW
analytics.v_monthly_delivery_performance AS

WITH monthly_operations AS (
    SELECT
        purchase_month,

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
      AND purchase_month IS NOT NULL

    GROUP BY purchase_month
)

SELECT
    ms.sales_month AS purchase_month,
    ms.order_count AS completed_order_count,
    ms.customer_count,
    ms.payment_value_total,

    COALESCE(
        mo.valid_delivery_order_count,
        0
    ) AS valid_delivery_order_count,

    COALESCE(
        mo.late_delivery_order_count,
        0
    ) AS late_delivery_order_count,

    mo.late_delivery_rate_pct,
    mo.average_delivery_days,
    mo.average_estimated_delivery_days,
    mo.average_carrier_handling_days,
    mo.average_delivery_delay_days,
    mo.average_delay_days_when_late,

    COALESCE(
        mo.reviewed_order_count,
        0
    ) AS reviewed_order_count,

    mo.average_review_score,

    COALESCE(
        mo.low_review_order_count,
        0
    ) AS low_review_order_count,

    mo.low_review_rate_pct

FROM analytics.v_monthly_sales AS ms

LEFT JOIN monthly_operations AS mo
    ON ms.sales_month = mo.purchase_month;


-- =====================================================
-- Customer-state delivery performance
-- One row per destination state
-- =====================================================

CREATE OR REPLACE VIEW
analytics.v_state_delivery_performance AS

SELECT
    COALESCE(
        customer_state,
        'unknown'
    ) AS customer_state,

    COUNT(*) AS completed_order_count,

    COUNT(
        DISTINCT customer_unique_id
    ) AS customer_count,

    ROUND(
        SUM(payment_value_total),
        2
    ) AS payment_value_total,

    ROUND(
        SUM(COALESCE(freight_total, 0)),
        2
    ) AS freight_total,

    ROUND(
        100.0 * SUM(
            COALESCE(freight_total, 0)
        )
        / NULLIF(
            SUM(
                COALESCE(item_price_total, 0)
                + COALESCE(freight_total, 0)
            ),
            0
        ),
        2
    ) AS freight_share_pct,

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

GROUP BY
    COALESCE(
        customer_state,
        'unknown'
    );

COMMIT;


-- =====================================================
-- Grain validation
-- =====================================================

SELECT
    'v_monthly_delivery_performance'
        AS view_name,

    COUNT(*) AS row_count,

    COUNT(
        DISTINCT purchase_month
    ) AS unique_grain_count

FROM analytics.v_monthly_delivery_performance

UNION ALL

SELECT
    'v_state_delivery_performance',

    COUNT(*),

    COUNT(DISTINCT customer_state)

FROM analytics.v_state_delivery_performance;


-- =====================================================
-- Reconciliation
-- =====================================================

SELECT
    'monthly_delivery'
        AS view_name,

    SUM(completed_order_count)
        AS reconstructed_order_count,

    ROUND(
        SUM(payment_value_total),
        2
    ) AS reconstructed_payment_value

FROM analytics.v_monthly_delivery_performance

UNION ALL

SELECT
    'state_delivery',

    SUM(completed_order_count),

    ROUND(
        SUM(payment_value_total),
        2
    )

FROM analytics.v_state_delivery_performance;


-- =====================================================
-- Preview recent monthly performance
-- =====================================================

SELECT
    purchase_month,
    completed_order_count,
    late_delivery_rate_pct,
    average_delivery_days,
    average_delay_days_when_late,
    average_review_score,
    low_review_rate_pct

FROM analytics.v_monthly_delivery_performance

ORDER BY purchase_month DESC

LIMIT 12;


-- =====================================================
-- Preview state performance
-- Only states with at least 100 completed orders
-- =====================================================

SELECT
    customer_state,
    completed_order_count,
    customer_count,
    freight_share_pct,
    late_delivery_rate_pct,
    average_delivery_days,
    average_delay_days_when_late,
    average_review_score,
    low_review_rate_pct

FROM analytics.v_state_delivery_performance

WHERE completed_order_count >= 100

ORDER BY late_delivery_rate_pct DESC;