# Analytics Data Model

## Overview

The analytics layer transforms the cleaned Olist database tables into reusable SQL views designed for business analysis.

The cleaned source tables remain in the `olist` schema. Analytical views are stored separately in the `analytics` schema.

This separation creates two database layers:

| Layer       | Purpose                                                                       |
| ----------- | ----------------------------------------------------------------------------- |
| `olist`     | Cleaned source tables with primary keys, foreign keys and quality constraints |
| `analytics` | Analysis-ready views with calculated metrics and controlled data grains       |

## Objective

The main purpose of the analytics layer is to prevent duplicated metrics when joining tables with different grains.

For example, an order may contain multiple items, payments and reviews. Directly joining all these tables could multiply the number of rows and incorrectly increase sales, freight or payment totals.

The analytical model therefore aggregates each one-to-many table to the order level before joining it to the orders table.

## Analytics Schema

The analytical views are stored in a dedicated schema:

```sql
CREATE SCHEMA IF NOT EXISTS analytics;
```

This keeps analytical logic separate from the cleaned source data.

## Supporting Views

Three supporting views aggregate one-to-many tables to one row per order.

### `analytics.v_order_items_agg`

Grain:

```text
One row per order
```

This view aggregates the `olist.order_items` table.

| Field                    | Definition                          |
| ------------------------ | ----------------------------------- |
| `order_id`               | Unique order identifier             |
| `item_count`             | Number of item records in the order |
| `distinct_product_count` | Number of different products        |
| `seller_count`           | Number of different sellers         |
| `item_price_total`       | Total product price                 |
| `freight_total`          | Total freight value                 |
| `gross_item_value`       | Product price plus freight          |

The view contains 98,666 orders.

### `analytics.v_payments_agg`

Grain:

```text
One row per order with a payment record
```

This view aggregates the `olist.payments` table.

| Field                  | Definition                       |
| ---------------------- | -------------------------------- |
| `order_id`             | Unique order identifier          |
| `payment_record_count` | Number of payment records        |
| `payment_type_count`   | Number of payment methods used   |
| `payment_value_total`  | Total amount paid                |
| `maximum_installments` | Maximum number of instalments    |
| `payment_types`        | Combined list of payment methods |
| `uses_credit_card`     | Whether a credit card was used   |
| `uses_voucher`         | Whether a voucher was used       |

The view contains 99,440 orders.

### `analytics.v_reviews_agg`

Grain:

```text
One row per order with a review
```

This view aggregates the `olist.reviews` table.

| Field                  | Definition                       |
| ---------------------- | -------------------------------- |
| `order_id`             | Unique order identifier          |
| `review_record_count`  | Number of review records         |
| `average_review_score` | Average review score             |
| `minimum_review_score` | Lowest review score              |
| `maximum_review_score` | Highest review score             |
| `first_review_date`    | Earliest review creation date    |
| `latest_review_answer` | Latest review response timestamp |
| `has_written_comment`  | Whether a written comment exists |

The view contains 98,673 orders.

## Core Order-Level View

### `analytics.v_order_summary`

Grain:

```text
One row per order
```

The view contains 99,441 rows and 99,441 distinct order IDs.

It is the primary source for:

* Order-volume analysis
* Customer analysis
* Revenue analysis
* Payment analysis
* Review analysis
* Delivery-performance analysis
* Monthly and quarterly KPI reporting

### Customer Fields

The view contains:

* `customer_id`
* `customer_unique_id`
* `customer_zip_code_prefix`
* `customer_city`
* `customer_state`

The `customer_unique_id` field should be used when counting real customers or measuring repeat purchases.

### Date Fields

The view contains:

* `order_purchase_timestamp`
* `purchase_date`
* `purchase_month`
* `purchase_year`
* `purchase_quarter`
* `order_approved_at`
* `order_delivered_carrier_date`
* `order_delivered_customer_date`
* `order_estimated_delivery_date`

The derived date fields make monthly, quarterly and yearly analysis easier.

### Order-Value Fields

| Field                 | Definition                           |
| --------------------- | ------------------------------------ |
| `item_price_total`    | Total product price within the order |
| `freight_total`       | Total freight charged for the order  |
| `gross_item_value`    | Product price plus freight           |
| `payment_value_total` | Total recorded payment               |
| `payment_difference`  | Payment total minus gross item value |

The payment difference is calculated as:

```text
payment_value_total - gross_item_value
```

A payment difference should not automatically be treated as a data error. It may reflect vouchers, payment adjustments or other transaction behaviour and should be investigated during analysis.

### Delivery Fields

| Field                     | Definition                                                |
| ------------------------- | --------------------------------------------------------- |
| `approval_hours`          | Hours between purchase and approval                       |
| `carrier_handling_days`   | Calendar days between purchase and carrier handover       |
| `delivery_days`           | Calendar days between purchase and customer delivery      |
| `estimated_delivery_days` | Calendar days between purchase and estimated delivery     |
| `delivery_delay_days`     | Actual delivery date minus estimated delivery date        |
| `is_late_delivery`        | Whether the actual delivery date was later than estimated |
| `is_delivered`            | Whether a customer delivery timestamp exists              |
| `is_canceled`             | Whether the order status is `canceled`                    |

Interpretation of `delivery_delay_days`:

|          Value | Meaning                         |
| -------------: | ------------------------------- |
| Greater than 0 | Delivered late                  |
|     Equal to 0 | Delivered on the estimated date |
|    Less than 0 | Delivered early                 |
|        Missing | No completed delivery timestamp |

### Record-Availability Fields

The view contains:

* `has_item_record`
* `has_payment_record`
* `has_review_record`

These fields distinguish a true zero from a missing related record.

The source data contains:

| Condition                      | Orders |
| ------------------------------ | -----: |
| Orders without item records    |    775 |
| Orders without payment records |      1 |
| Orders without review records  |    768 |

These orders are retained through left joins rather than removed.

### Data-Quality Fields

The view retains the cleaning-stage quality flags:

* `has_timestamp_anomaly`
* `has_status_date_mismatch`
* `is_valid_delivery_record`

Delivery-performance analysis should normally filter to:

```sql
WHERE is_valid_delivery_record
```

## Core Item-Level View

### `analytics.v_order_item_detail`

Grain:

```text
One row per order item
```

The view contains 112,650 rows and 112,650 unique combinations of:

```text
order_id + order_item_id
```

It is the primary source for:

* Product-category analysis
* Seller analysis
* Item-price analysis
* Freight analysis
* Customer and seller regional comparisons
* Shipping-performance analysis

### Item and Product Fields

The view contains:

* `order_id`
* `order_item_id`
* `product_id`
* `product_category_name`
* `product_category_name_english`
* `price`
* `freight_value`
* `gross_item_value`

The item-level gross value is calculated as:

```text
price + freight_value
```

### Seller Fields

The view contains:

* `seller_id`
* `seller_zip_code_prefix`
* `seller_city`
* `seller_state`

These fields support seller-level and geographic analysis.

### Shipping Fields

The view contains:

* `shipping_limit_date`
* `shipped_after_shipping_limit`
* `delivery_days`
* `delivery_delay_days`
* `is_late_delivery`

The `shipped_after_shipping_limit` field compares the carrier handover timestamp with the item shipping deadline.

## Join Strategy

All supporting tables are aggregated before being joined to the order table.

The order-level model follows this logic:

```text
orders
  + one-row-per-order item summary
  + one-row-per-order payment summary
  + one-row-per-order review summary
  + customer information
  = one row per order
```

Left joins are used so that orders without items, payments or reviews remain in the analytical model.

## Safe Usage Rules

### Order analysis

Use:

```text
analytics.v_order_summary
```

for:

* Counting orders
* Counting customers
* Summing order-level payments
* Calculating average order value
* Measuring review performance
* Measuring delivery performance

### Product and seller analysis

Use:

```text
analytics.v_order_item_detail
```

for:

* Product-category revenue
* Seller revenue
* Item quantities
* Product prices
* Freight values
* Seller shipping performance

### Avoiding duplicate totals

Do not join the raw `order_items`, `payments` and `reviews` tables directly and then sum their values.

Do not count rows in the item-level view as orders. Use:

```sql
COUNT(DISTINCT order_id)
```

when an order count must be calculated from the item-level view.

## Example Queries

### Monthly order performance

```sql
SELECT
    purchase_month,
    COUNT(*) AS order_count,
    COUNT(
        DISTINCT customer_unique_id
    ) AS customer_count,
    SUM(payment_value_total)
        AS total_payment_value
FROM analytics.v_order_summary
GROUP BY purchase_month
ORDER BY purchase_month;
```

### Product-category performance

```sql
SELECT
    product_category_name_english,
    COUNT(*) AS item_count,
    SUM(price) AS product_revenue,
    SUM(freight_value) AS freight_value
FROM analytics.v_order_item_detail
GROUP BY product_category_name_english
ORDER BY product_revenue DESC;
```

### Late-delivery rate

```sql
SELECT
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE is_late_delivery
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_rate_pct
FROM analytics.v_order_summary
WHERE is_valid_delivery_record;
```

## Validation

The analytical model is validated through:

```text
sql/06_validate_analytics_views.sql
```

The validation contains 22 checks covering:

* Order-level row count
* Order-level key uniqueness
* Item-level row count
* Item-level composite-key uniqueness
* Supporting-view row counts
* Item-count reconciliation
* Review-count reconciliation
* Product-price reconciliation
* Freight reconciliation
* Gross-item-value reconciliation
* Payment-value reconciliation
* Missing customer information
* Missing product information
* Missing seller information
* Delivery-day validity
* Late-delivery flag consistency
* Expected missing related records

All checks must return:

```text
PASS
```

The validation results are exported to:

```text
reports/analytics_model_validation.csv
```

## Project Files

| File                                     | Purpose                                                |
| ---------------------------------------- | ------------------------------------------------------ |
| `sql/05_create_analytics_views.sql`      | Creates the analytics schema and five analytical views |
| `sql/06_validate_analytics_views.sql`    | Runs the analytical-model validation                   |
| `reports/analytics_model_validation.csv` | Stores the validation results                          |
| `docs/analytics_data_model.md`           | Documents the analytical model and usage rules         |
