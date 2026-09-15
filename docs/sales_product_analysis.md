# Sales, Product and Category Performance Analysis

## Objective

This analysis examines completed sales, monthly performance, product-category contribution and product-level revenue concentration in the Olist marketplace dataset.

The analysis was created using PostgreSQL views and reproducible SQL scripts. It focuses on orders that were successfully delivered and contain a payment record.

## Completed-Purchase Definition

A completed purchase satisfies both conditions:

- `order_status = 'delivered'`
- `payment_value_total IS NOT NULL`

This definition excludes canceled, unavailable and incomplete orders. It also excludes delivered orders without a corresponding payment record.

## Metric Definitions

| Metric | Definition |
|---|---|
| Completed order count | Number of delivered orders with a payment record |
| Completed customer count | Number of distinct real customers with a completed purchase |
| Item count | Number of order-item records associated with completed purchases |
| Item price total | Sum of product prices, excluding freight |
| Freight total | Sum of freight charges |
| Item and freight total | Product prices plus freight charges |
| Payment value total | Total amount recorded in the payments table |
| Average order value | Payment value divided by completed orders |
| Average items per order | Item count divided by completed orders |
| Freight share | Freight divided by product price plus freight |
| Payment difference | Payment value minus product price and freight |

`payment_value_total` represents customer payments and should not be interpreted as company profit. The dataset does not contain product costs, marketplace commissions, refunds or operating expenses.

## Data Model and Grain

Three reusable analytical views were created:

| View | Grain |
|---|---|
| `analytics.v_monthly_sales` | One row per calendar month |
| `analytics.v_category_performance` | One row per English product category |
| `analytics.v_product_performance` | One row per product |

Order-level payment values are calculated from `analytics.v_order_summary`.

Product and category performance is calculated at the order-item grain. The item table is joined to the order-level view only after the order-level payment data has been aggregated. This prevents payment values from being duplicated across multiple products.

## Overall Sales Performance

| KPI | Result |
|---|---:|
| Completed orders | 96,477 |
| Completed-purchase customers | 93,357 |
| Items sold | 110,194 |
| Product value | 13,221,363.14 |
| Freight value | 2,198,267.15 |
| Product plus freight value | 15,419,630.29 |
| Customer payment value | 15,422,461.77 |
| Average order value | 159.86 |
| Average items per order | 1.14 |
| Freight share | 14.26% |
| Payment reconciliation difference | 2,831.48 |
| First completed purchase | 2016-10-03 |
| Last completed purchase | 2018-08-29 |

The payment reconciliation difference represents approximately 0.02% of total customer payments. This indicates that order-item and payment totals are closely aligned, although they should not be assumed to be identical.

## Monthly Sales Analysis

The monthly sales view includes every calendar month between the first and last completed purchase.

The view calculates:

- completed orders;
- active customers;
- items sold;
- product value;
- freight value;
- customer payment value;
- average order value;
- freight share;
- payment reconciliation difference;
- month-over-month payment growth.

November 2016 contains no completed sales and is retained as a zero-activity month. Including a complete calendar prevents December 2016 from being incorrectly compared with October 2016 as if they were consecutive months.

Month-over-month growth is calculated as:

```text
Current-month payment value
minus previous-month payment value
divided by previous-month payment value
```

Growth is left missing when the previous month has zero sales because a meaningful percentage change cannot be calculated from a zero denominator.

## Category Performance

The dataset contains 74 English product categories among completed purchases.

The ten highest-value categories are:

| Rank | Category | Orders | Items | Product value | Revenue share | Freight share |
|---:|---|---:|---:|---:|---:|---:|
| 1 | `health_beauty` | 8,646 | 9,462 | 1,232,996.75 | 9.33% | 12.67% |
| 2 | `watches_gifts` | 5,495 | 5,859 | 1,166,176.98 | 8.82% | 7.76% |
| 3 | `bed_bath_table` | 9,272 | 10,953 | 1,023,434.76 | 7.74% | 16.47% |
| 4 | `sports_leisure` | 7,530 | 8,431 | 954,852.55 | 7.22% | 14.61% |
| 5 | `computers_accessories` | 6,530 | 7,644 | 888,724.61 | 6.72% | 13.94% |
| 6 | `furniture_decor` | 6,307 | 8,160 | 711,927.69 | 5.38% | 19.13% |
| 7 | `housewares` | 5,743 | 6,795 | 615,628.69 | 4.66% | 18.82% |
| 8 | `cool_stuff` | 3,559 | 3,718 | 610,204.10 | 4.62% | 11.78% |
| 9 | `auto` | 3,810 | 4,140 | 578,966.65 | 4.38% | 13.52% |
| 10 | `toys` | 3,804 | 4,030 | 471,286.48 | 3.56% | 13.85% |

`health_beauty` produces the highest product value, while `bed_bath_table` has the largest order and item volume among the ten leading categories.

`furniture_decor` and `housewares` have comparatively high freight shares. These categories may require closer investigation of product dimensions, seller locations and delivery distance.

## Product Revenue Concentration

Product concentration was measured by ranking products according to product value and calculating cumulative contribution.

| Revenue threshold | Products required | Total products | Product share required |
|---:|---:|---:|---:|
| 50% | 1,818 | 32,216 | 5.64% |
| 80% | 8,349 | 32,216 | 25.92% |
| 90% | 14,235 | 32,216 | 44.19% |
| 95% | 19,403 | 32,216 | 60.23% |

The highest-value 5.64% of products generate half of total product value.

However, reaching 80% requires 25.92% of products. Therefore, the catalogue is concentrated but does not follow an exact 80/20 pattern. A substantial long tail of products continues to contribute meaningful value.

The ten highest-value individual products account for only approximately 3.35% of total product value. Category performance is therefore more concentrated than individual-product performance.

## Key Findings

1. Completed purchases generated 15.42 million in customer payments.

2. Customers purchased an average of 1.14 items per completed order, indicating relatively small shopping baskets.

3. Freight represents 14.26% of product-plus-freight value and is therefore an important operational component.

4. `health_beauty`, `watches_gifts` and `bed_bath_table` are the three highest-value categories.

5. Furniture and household-related categories have relatively high freight shares.

6. Product performance follows a long-tail structure. A small group of products makes a large contribution, but thousands of products are required to reach 80% of product value.

7. The item and payment datasets reconcile closely, with a difference of approximately 0.02% of total payments.

## Business Recommendations

### Protect high-value categories

Inventory availability, seller coverage and delivery performance should be monitored closely for the highest-value categories, particularly:

- `health_beauty`;
- `watches_gifts`;
- `bed_bath_table`;
- `sports_leisure`;
- `computers_accessories`.

### Investigate freight-intensive categories

Categories such as `furniture_decor` and `housewares` may benefit from:

- regional inventory placement;
- closer seller-customer distance;
- improved packaging;
- freight-pricing review;
- minimum-order or bundle strategies.

### Increase basket size

The average of 1.14 items per order suggests an opportunity to test:

- product bundles;
- complementary-product recommendations;
- free-freight thresholds;
- category-specific cross-selling.

### Manage the long-tail catalogue

The company should avoid evaluating products only by individual sales ranking. Product decisions should also consider:

- category contribution;
- customer demand;
- seller coverage;
- freight requirements;
- product availability;
- strategic catalogue variety.

## Validation

Eight final validation checks were completed:

- monthly order counts reconcile with completed orders;
- monthly payments reconcile with completed-order payments;
- category product value reconciles with source data;
- category freight reconciles with source data;
- product value reconciles with source data;
- product freight reconciles with source data;
- category grain is unique;
- product grain is unique.

All validation checks passed.

## Output Files

The analysis produces:

- `reports/overall_sales_kpis.csv`
- `reports/monthly_sales_metrics.csv`
- `reports/category_performance.csv`
- `reports/top_products.csv`
- `reports/product_revenue_concentration.csv`
- `reports/sales_analysis_validation.csv`

The SQL implementation is stored in:

- `sql/13_create_sales_views.sql`
- `sql/14_sales_business_analysis.sql`

## Limitations

- The dataset does not contain product costs or marketplace commission rates.
- Payment value should not be interpreted as net revenue or profit.
- Refund and chargeback information is unavailable.
- Freight value represents the amount recorded in the order-item dataset and not necessarily the marketplace's actual logistics cost.
- The available sales period ends in August 2018 for completed purchases.
- The analysis is observational and does not establish that any category or operational factor causes sales performance.