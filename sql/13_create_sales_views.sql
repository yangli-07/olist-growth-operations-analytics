\set ON_ERROR_STOP on

BEGIN;

CREATE SCHEMA IF NOT EXISTS analytics;

CREATE OR REPLACE VIEW
analytics.v_monthly_sales AS

WITH completed_orders AS (
    SELECT
        DATE_TRUNC(
            'month',
            purchase_date
        )::DATE AS sales_month,

        order_id,
        customer_unique_id,
        COALESCE(item_count, 0) AS item_count,
        COALESCE(
            item_price_total,
            0
        )::NUMERIC AS item_price_total,
        COALESCE(
            freight_total,
            0
        )::NUMERIC AS freight_total,
        payment_value_total::NUMERIC
            AS payment_value_total

    FROM analytics.v_order_summary

    WHERE order_status = 'delivered'
      AND purchase_date IS NOT NULL
      AND payment_value_total IS NOT NULL
),

date_bounds AS (
    SELECT
        MIN(sales_month) AS first_month,
        MAX(sales_month) AS last_month
    FROM completed_orders
),

calendar AS (
    SELECT
        GENERATE_SERIES(
            first_month,
            last_month,
            INTERVAL '1 month'
        )::DATE AS sales_month
    FROM date_bounds
),

monthly_metrics AS (
    SELECT
        sales_month,

        COUNT(*) AS order_count,

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
            SUM(
                item_price_total
                + freight_total
            ),
            2
        ) AS item_and_freight_total,

        ROUND(
            SUM(payment_value_total),
            2
        ) AS payment_value_total

    FROM completed_orders

    GROUP BY sales_month
),

monthly_filled AS (
    SELECT
        c.sales_month,

        COALESCE(
            m.order_count,
            0
        ) AS order_count,

        COALESCE(
            m.customer_count,
            0
        ) AS customer_count,

        COALESCE(
            m.item_count,
            0
        ) AS item_count,

        COALESCE(
            m.item_price_total,
            0
        )::NUMERIC AS item_price_total,

        COALESCE(
            m.freight_total,
            0
        )::NUMERIC AS freight_total,

        COALESCE(
            m.item_and_freight_total,
            0
        )::NUMERIC
            AS item_and_freight_total,

        COALESCE(
            m.payment_value_total,
            0
        )::NUMERIC AS payment_value_total

    FROM calendar AS c

    LEFT JOIN monthly_metrics AS m
        ON c.sales_month = m.sales_month
)

SELECT
    sales_month,
    order_count,
    customer_count,
    item_count,
    item_price_total,
    freight_total,
    item_and_freight_total,
    payment_value_total,

    ROUND(
        payment_value_total
        / NULLIF(order_count, 0),
        2
    ) AS average_order_value,

    ROUND(
        100.0 * freight_total
        / NULLIF(
            item_and_freight_total,
            0
        ),
        2
    ) AS freight_share_pct,

    ROUND(
        payment_value_total
        - item_and_freight_total,
        2
    ) AS payment_difference,

    ROUND(
        100.0 * (
            payment_value_total
            - LAG(
                payment_value_total
            ) OVER (
                ORDER BY sales_month
            )
        )
        / NULLIF(
            LAG(
                payment_value_total
            ) OVER (
                ORDER BY sales_month
            ),
            0
        ),
        2
    ) AS payment_growth_pct

FROM monthly_filled;

COMMIT;

-- Validate monthly grain and totals

SELECT
    COUNT(*) AS calendar_month_count,

    COUNT(DISTINCT sales_month)
        AS unique_month_count,

    MIN(sales_month)
        AS first_sales_month,

    MAX(sales_month)
        AS last_sales_month,

    SUM(order_count)
        AS completed_order_count,

    ROUND(
        SUM(payment_value_total),
        2
    ) AS completed_payment_value,

    COUNT(*) FILTER (
        WHERE order_count = 0
    ) AS months_without_sales

FROM analytics.v_monthly_sales;

-- Preview monthly results

SELECT
    sales_month,
    order_count,
    customer_count,
    payment_value_total,
    average_order_value,
    freight_share_pct,
    payment_growth_pct

FROM analytics.v_monthly_sales

ORDER BY sales_month;

-- =====================================================
-- Category performance
-- One row per English product category
-- =====================================================

BEGIN;

CREATE OR REPLACE VIEW
analytics.v_category_performance AS

WITH category_metrics AS (
    SELECT
        COALESCE(
            p.product_category_name_english,
            'unknown'
        ) AS product_category_name_english,

        COUNT(
            DISTINCT oi.order_id
        ) AS order_count,

        COUNT(*) AS item_count,

        COUNT(
            DISTINCT oi.product_id
        ) AS product_count,

        COUNT(
            DISTINCT oi.seller_id
        ) AS seller_count,

        COUNT(
            DISTINCT os.customer_unique_id
        ) AS customer_count,

        ROUND(
            SUM(oi.price),
            2
        ) AS item_price_total,

        ROUND(
            SUM(oi.freight_value),
            2
        ) AS freight_total,

        ROUND(
            SUM(
                oi.price
                + oi.freight_value
            ),
            2
        ) AS item_and_freight_total,

        ROUND(
            AVG(oi.price),
            2
        ) AS average_item_price

    FROM olist.order_items AS oi

    INNER JOIN analytics.v_order_summary AS os
        ON oi.order_id = os.order_id

    LEFT JOIN olist.products AS p
        ON oi.product_id = p.product_id

    WHERE os.order_status = 'delivered'
      AND os.payment_value_total IS NOT NULL

    GROUP BY
        COALESCE(
            p.product_category_name_english,
            'unknown'
        )
)

SELECT
    product_category_name_english,
    order_count,
    item_count,
    product_count,
    seller_count,
    customer_count,
    item_price_total,
    freight_total,
    item_and_freight_total,
    average_item_price,

    ROUND(
        item_count::NUMERIC
        / NULLIF(order_count, 0),
        2
    ) AS average_items_per_order,

    ROUND(
        100.0 * freight_total
        / NULLIF(
            item_and_freight_total,
            0
        ),
        2
    ) AS freight_share_pct,

    ROUND(
        100.0 * item_price_total
        / NULLIF(
            SUM(
                item_price_total
            ) OVER (),
            0
        ),
        2
    ) AS item_revenue_share_pct,

    DENSE_RANK() OVER (
        ORDER BY item_price_total DESC
    ) AS item_revenue_rank

FROM category_metrics;


-- =====================================================
-- Product performance
-- One row per product
-- =====================================================

CREATE OR REPLACE VIEW
analytics.v_product_performance AS

WITH product_metrics AS (
    SELECT
        oi.product_id,

        COALESCE(
            p.product_category_name_english,
            'unknown'
        ) AS product_category_name_english,

        COUNT(
            DISTINCT oi.order_id
        ) AS order_count,

        COUNT(*) AS item_count,

        COUNT(
            DISTINCT os.customer_unique_id
        ) AS customer_count,

        COUNT(
            DISTINCT oi.seller_id
        ) AS seller_count,

        ROUND(
            SUM(oi.price),
            2
        ) AS item_price_total,

        ROUND(
            SUM(oi.freight_value),
            2
        ) AS freight_total,

        ROUND(
            AVG(oi.price),
            2
        ) AS average_item_price,

        ROUND(
            MIN(oi.price),
            2
        ) AS minimum_item_price,

        ROUND(
            MAX(oi.price),
            2
        ) AS maximum_item_price,

        MIN(os.purchase_date)
            AS first_purchase_date,

        MAX(os.purchase_date)
            AS last_purchase_date

    FROM olist.order_items AS oi

    INNER JOIN analytics.v_order_summary AS os
        ON oi.order_id = os.order_id

    LEFT JOIN olist.products AS p
        ON oi.product_id = p.product_id

    WHERE os.order_status = 'delivered'
      AND os.payment_value_total IS NOT NULL

    GROUP BY
        oi.product_id,
        COALESCE(
            p.product_category_name_english,
            'unknown'
        )
),

product_rankings AS (
    SELECT
        *,

        DENSE_RANK() OVER (
            ORDER BY item_price_total DESC
        ) AS item_revenue_rank,

        ROUND(
            100.0 * item_price_total
            / NULLIF(
                SUM(
                    item_price_total
                ) OVER (),
                0
            ),
            4
        ) AS item_revenue_share_pct,

        ROUND(
            100.0 * SUM(
                item_price_total
            ) OVER (
                ORDER BY
                    item_price_total DESC,
                    product_id
                ROWS BETWEEN
                    UNBOUNDED PRECEDING
                    AND CURRENT ROW
            )
            / NULLIF(
                SUM(
                    item_price_total
                ) OVER (),
                0
            ),
            2
        ) AS cumulative_item_revenue_pct

    FROM product_metrics
)

SELECT
    product_id,
    product_category_name_english,
    order_count,
    item_count,
    customer_count,
    seller_count,
    item_price_total,
    freight_total,
    average_item_price,
    minimum_item_price,
    maximum_item_price,
    first_purchase_date,
    last_purchase_date,
    item_revenue_rank,
    item_revenue_share_pct,
    cumulative_item_revenue_pct

FROM product_rankings;

COMMIT;


-- =====================================================
-- Validation
-- =====================================================

SELECT
    'v_category_performance'
        AS view_name,

    COUNT(*) AS row_count,

    COUNT(
        DISTINCT
        product_category_name_english
    ) AS unique_grain_count,

    ROUND(
        SUM(item_price_total),
        2
    ) AS reconstructed_item_price,

    ROUND(
        SUM(freight_total),
        2
    ) AS reconstructed_freight

FROM analytics.v_category_performance

UNION ALL

SELECT
    'v_product_performance',

    COUNT(*),

    COUNT(
        DISTINCT product_id
    ),

    ROUND(
        SUM(item_price_total),
        2
    ),

    ROUND(
        SUM(freight_total),
        2
    )

FROM analytics.v_product_performance;


-- Category revenue-share validation

SELECT
    ROUND(
        SUM(item_revenue_share_pct),
        2
    ) AS category_revenue_share_total
FROM analytics.v_category_performance;


-- Preview top 10 categories

SELECT
    product_category_name_english,
    order_count,
    item_count,
    item_price_total,
    item_revenue_share_pct,
    freight_share_pct,
    item_revenue_rank

FROM analytics.v_category_performance

ORDER BY item_price_total DESC

LIMIT 10;


-- Preview top 10 products

SELECT
    product_id,
    product_category_name_english,
    order_count,
    item_count,
    item_price_total,
    item_revenue_share_pct,
    cumulative_item_revenue_pct,
    item_revenue_rank

FROM analytics.v_product_performance

ORDER BY item_price_total DESC

LIMIT 10;