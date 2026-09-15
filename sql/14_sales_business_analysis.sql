\set ON_ERROR_STOP on
\pset pager off

BEGIN;

-- =====================================================
-- Overall sales KPIs
-- =====================================================

CREATE OR REPLACE VIEW
analytics.v_sales_kpis AS

SELECT
    COUNT(*) AS completed_order_count,

    COUNT(
        DISTINCT customer_unique_id
    ) AS completed_customer_count,

    SUM(
        COALESCE(item_count, 0)
    ) AS item_count,

    ROUND(
        SUM(
            COALESCE(item_price_total, 0)
        ),
        2
    ) AS item_price_total,

    ROUND(
        SUM(
            COALESCE(freight_total, 0)
        ),
        2
    ) AS freight_total,

    ROUND(
        SUM(
            COALESCE(item_price_total, 0)
            + COALESCE(freight_total, 0)
        ),
        2
    ) AS item_and_freight_total,

    ROUND(
        SUM(payment_value_total),
        2
    ) AS payment_value_total,

    ROUND(
        AVG(payment_value_total),
        2
    ) AS average_order_value,

    ROUND(
        SUM(COALESCE(item_count, 0))::NUMERIC
        / NULLIF(COUNT(*), 0),
        2
    ) AS average_items_per_order,

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

    ROUND(
        SUM(payment_value_total)
        - SUM(
            COALESCE(item_price_total, 0)
            + COALESCE(freight_total, 0)
        ),
        2
    ) AS payment_difference,

    MIN(purchase_date)
        AS first_completed_purchase_date,

    MAX(purchase_date)
        AS last_completed_purchase_date

FROM analytics.v_order_summary

WHERE order_status = 'delivered'
  AND payment_value_total IS NOT NULL;


-- =====================================================
-- Product revenue concentration
-- =====================================================

CREATE OR REPLACE VIEW
analytics.v_product_revenue_concentration AS

WITH ranked_products AS (
    SELECT
        product_id,
        item_price_total,
        cumulative_item_revenue_pct,

        ROW_NUMBER() OVER (
            ORDER BY
                item_price_total DESC,
                product_id
        ) AS product_position,

        COUNT(*) OVER ()
            AS total_product_count

    FROM analytics.v_product_performance
),

thresholds AS (
    SELECT *
    FROM (
        VALUES
            (50.00::NUMERIC),
            (80.00::NUMERIC),
            (90.00::NUMERIC),
            (95.00::NUMERIC)
    ) AS values_table(threshold_pct)
)

SELECT
    t.threshold_pct,

    MIN(r.product_position) FILTER (
        WHERE
            r.cumulative_item_revenue_pct
            >= t.threshold_pct
    ) AS products_required,

    MAX(r.total_product_count)
        AS total_product_count,

    ROUND(
        100.0 * MIN(
            r.product_position
        ) FILTER (
            WHERE
                r.cumulative_item_revenue_pct
                >= t.threshold_pct
        )
        / NULLIF(
            MAX(r.total_product_count),
            0
        ),
        2
    ) AS product_share_required_pct

FROM thresholds AS t

CROSS JOIN ranked_products AS r

GROUP BY t.threshold_pct;


-- =====================================================
-- Sales validation
-- =====================================================

CREATE OR REPLACE VIEW
analytics.v_sales_validation AS

WITH source_metrics AS (
    SELECT
        COUNT(*)::NUMERIC
            AS source_order_count,

        ROUND(
            SUM(payment_value_total),
            2
        ) AS source_payment_value,

        ROUND(
            SUM(
                COALESCE(item_price_total, 0)
            ),
            2
        ) AS source_item_price,

        ROUND(
            SUM(
                COALESCE(freight_total, 0)
            ),
            2
        ) AS source_freight

    FROM analytics.v_order_summary

    WHERE order_status = 'delivered'
      AND payment_value_total IS NOT NULL
),

view_metrics AS (
    SELECT
        (
            SELECT SUM(order_count)
            FROM analytics.v_monthly_sales
        )::NUMERIC AS monthly_order_count,

        (
            SELECT ROUND(
                SUM(payment_value_total),
                2
            )
            FROM analytics.v_monthly_sales
        ) AS monthly_payment_value,

        (
            SELECT ROUND(
                SUM(item_price_total),
                2
            )
            FROM analytics.v_category_performance
        ) AS category_item_price,

        (
            SELECT ROUND(
                SUM(freight_total),
                2
            )
            FROM analytics.v_category_performance
        ) AS category_freight,

        (
            SELECT ROUND(
                SUM(item_price_total),
                2
            )
            FROM analytics.v_product_performance
        ) AS product_item_price,

        (
            SELECT ROUND(
                SUM(freight_total),
                2
            )
            FROM analytics.v_product_performance
        ) AS product_freight
)

SELECT
    'monthly_order_count'
        AS metric_name,
    s.source_order_count
        AS expected_value,
    v.monthly_order_count
        AS actual_value,
    v.monthly_order_count
        - s.source_order_count
        AS difference,
    v.monthly_order_count
        = s.source_order_count
        AS passed

FROM source_metrics AS s
CROSS JOIN view_metrics AS v

UNION ALL

SELECT
    'monthly_payment_value',
    s.source_payment_value,
    v.monthly_payment_value,
    v.monthly_payment_value
        - s.source_payment_value,
    ABS(
        v.monthly_payment_value
        - s.source_payment_value
    ) < 0.01

FROM source_metrics AS s
CROSS JOIN view_metrics AS v

UNION ALL

SELECT
    'category_item_price',
    s.source_item_price,
    v.category_item_price,
    v.category_item_price
        - s.source_item_price,
    ABS(
        v.category_item_price
        - s.source_item_price
    ) < 0.01

FROM source_metrics AS s
CROSS JOIN view_metrics AS v

UNION ALL

SELECT
    'category_freight',
    s.source_freight,
    v.category_freight,
    v.category_freight
        - s.source_freight,
    ABS(
        v.category_freight
        - s.source_freight
    ) < 0.01

FROM source_metrics AS s
CROSS JOIN view_metrics AS v

UNION ALL

SELECT
    'product_item_price',
    s.source_item_price,
    v.product_item_price,
    v.product_item_price
        - s.source_item_price,
    ABS(
        v.product_item_price
        - s.source_item_price
    ) < 0.01

FROM source_metrics AS s
CROSS JOIN view_metrics AS v

UNION ALL

SELECT
    'product_freight',
    s.source_freight,
    v.product_freight,
    v.product_freight
        - s.source_freight,
    ABS(
        v.product_freight
        - s.source_freight
    ) < 0.01

FROM source_metrics AS s
CROSS JOIN view_metrics AS v

UNION ALL

SELECT
    'category_duplicate_grains',
    0,
    (
        SELECT
            COUNT(*)
            - COUNT(
                DISTINCT
                product_category_name_english
            )
        FROM analytics.v_category_performance
    ),
    (
        SELECT
            COUNT(*)
            - COUNT(
                DISTINCT
                product_category_name_english
            )
        FROM analytics.v_category_performance
    ),
    (
        SELECT
            COUNT(*)
            = COUNT(
                DISTINCT
                product_category_name_english
            )
        FROM analytics.v_category_performance
    )

UNION ALL

SELECT
    'product_duplicate_grains',
    0,
    (
        SELECT
            COUNT(*)
            - COUNT(DISTINCT product_id)
        FROM analytics.v_product_performance
    ),
    (
        SELECT
            COUNT(*)
            - COUNT(DISTINCT product_id)
        FROM analytics.v_product_performance
    ),
    (
        SELECT
            COUNT(*)
            = COUNT(DISTINCT product_id)
        FROM analytics.v_product_performance
    );

COMMIT;


-- =====================================================
-- Display results
-- =====================================================

SELECT *
FROM analytics.v_sales_kpis;

SELECT *
FROM analytics.v_product_revenue_concentration
ORDER BY threshold_pct;

SELECT *
FROM analytics.v_sales_validation
ORDER BY metric_name;


-- =====================================================
-- Export CSV reports
-- =====================================================

\copy (SELECT * FROM analytics.v_sales_kpis) TO 'reports/overall_sales_kpis.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_monthly_sales ORDER BY sales_month) TO 'reports/monthly_sales_metrics.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_category_performance ORDER BY item_price_total DESC) TO 'reports/category_performance.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_product_performance ORDER BY item_price_total DESC LIMIT 20) TO 'reports/top_products.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_product_revenue_concentration ORDER BY threshold_pct) TO 'reports/product_revenue_concentration.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy (SELECT * FROM analytics.v_sales_validation ORDER BY metric_name) TO 'reports/sales_analysis_validation.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');