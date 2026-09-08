# Customer Growth and Retention Analysis

## Overview

This analysis evaluates customer acquisition, repeat purchasing, monthly growth, cohort retention and customer value using the Olist ecommerce dataset.

The analysis uses `customer_unique_id` to represent a real customer. This is necessary because `customer_id` is an order-level identifier and the same person may receive a different `customer_id` for different orders.

## Data Sources

The analysis is based on the following analytical views:

| View                                    | Purpose                                            |
| --------------------------------------- | -------------------------------------------------- |
| `analytics.v_customer_summary`          | One row per unique customer                        |
| `analytics.v_customer_monthly_activity` | One row per customer per active month              |
| `analytics.v_monthly_customer_metrics`  | Monthly acquisition and returning-customer metrics |
| `analytics.v_customer_cohort_retention` | Cohort retention by month since first order        |
| `analytics.v_customer_rfm`              | Customer-level RFM metrics and segments            |
| `analytics.v_customer_segment_summary`  | Aggregated customer-segment performance            |

## Customer KPI Summary

| Metric                                       |        Result |
| -------------------------------------------- | ------------: |
| Total unique customers                       |        96,096 |
| Customers with a completed purchase          |        93,357 |
| Customers without a completed purchase       |         2,739 |
| Customers with more than one order           |         2,997 |
| All-order repeat-customer rate               |         3.12% |
| Customers with more than one completed order |         2,801 |
| Completed-order repeat-customer rate         |         3.00% |
| Completed orders                             |        96,477 |
| Completed payment value                      | 15,422,461.77 |
| Average completed order value                |        159.86 |
| Average completed customer value             |        165.20 |
| Average completed orders per customer        |          1.03 |
| RFM reference date                           |    2018-08-30 |

Customers without completed purchases represent approximately 2.85% of all identified customers.

The average completed customer placed only 1.03 completed orders. This is consistent with the low completed-order repeat-customer rate of 3.00%.

## Main Finding: Growth Depends Heavily on Acquisition

The customer base is dominated by one-time purchasers.

A total of 93,099 customers placed only one recorded order, while only 2,997 customers placed more than one order. This means that approximately 96.88% of customers did not make a second recorded purchase.

Monthly activity shows the same pattern. In the busiest months, most active customers were new rather than returning customers.

| Month   | Active customers | New customers | Returning customers | Orders | Payment value |
| ------- | ---------------: | ------------: | ------------------: | -----: | ------------: |
| 2017-11 |            7,430 |         7,304 |                 126 |  7,544 |  1,194,882.80 |
| 2018-01 |            7,166 |         7,025 |                 141 |  7,269 |  1,115,004.18 |
| 2018-03 |            7,115 |         6,965 |                 150 |  7,211 |  1,159,652.12 |
| 2018-04 |            6,882 |         6,711 |                 171 |  6,939 |  1,160,785.48 |
| 2018-05 |            6,814 |         6,622 |                 192 |  6,873 |  1,153,982.15 |

November 2017 was the largest month by active customers and recorded 62.90% growth from the previous calendar month. The timing is consistent with a major seasonal or promotional effect, although campaign data would be required to identify the cause.

Returning customers represented approximately 1.70% of active customers in November 2017. This increased to approximately 2.82% in May 2018, but returning customers still formed a small part of monthly activity.

## Cohort Retention

Customers were assigned to cohorts based on the month of their first order.

Month 0 represents the acquisition month. Month 1 represents the following calendar month, and so on.

Weighted retention measures the number of active customers divided by the combined original cohort size.

| Month since first order | Weighted retention |
| ----------------------: | -----------------: |
|                       0 |            100.00% |
|                       1 |              0.48% |
|                       2 |              0.30% |
|                       3 |              0.22% |
|                       6 |              0.19% |
|                      12 |              0.13% |

Only 461 of 96,095 customers eligible for Month 1 observation purchased again in the following month, producing weighted Month 1 retention of 0.48%.

Retention fell to 0.30% in Month 2 and 0.22% in Month 3. Month 12 weighted retention was 0.13%.

These results provide strong evidence that recorded repeat purchasing is very limited. Customer growth in this dataset was therefore driven mainly by continuous acquisition rather than recurring customer activity.

## RFM Method

RFM analysis evaluates customers using:

* **Recency:** days since the most recent completed purchase
* **Frequency:** number of completed orders
* **Monetary value:** total payment value from completed orders

Only delivered orders with payment records were used for RFM purchase metrics. Customers without a completed purchase were retained in a separate segment.

Recency scores use business-based time ranges:

| Recency            | Score |
| ------------------ | ----: |
| 0–30 days          |     5 |
| 31–90 days         |     4 |
| 91–180 days        |     3 |
| 181–365 days       |     2 |
| More than 365 days |     1 |

Frequency scores are based on the number of completed orders and are capped at five. Monetary scores are assigned using payment-value quintiles.

## Customer Segments

| Segment               | Customers | Customer share | Monetary value | Average customer value |
| --------------------- | --------: | -------------: | -------------: | ---------------------: |
| Hibernating           |    33,363 |         34.72% |   2,417,915.65 |                  72.47 |
| High Value at Risk    |    21,677 |         22.56% |   6,538,599.45 |                 301.64 |
| Need Attention        |    19,521 |         20.31% |   3,304,202.49 |                 169.26 |
| Promising             |    11,365 |         11.83% |   1,898,661.33 |                 167.06 |
| New Customers         |     6,414 |          6.67% |   1,000,651.11 |                 156.01 |
| No Completed Purchase |     2,739 |          2.85% |           0.00 |                   0.00 |
| Potential Loyalists   |       552 |          0.57% |     160,449.92 |                 290.67 |
| At Risk               |       340 |          0.35% |      33,598.37 |                  98.82 |
| Loyal Customers       |        70 |          0.07% |      32,287.56 |                 461.25 |
| Champions             |        55 |          0.06% |      36,095.89 |                 656.29 |

### High Value at Risk

The High Value at Risk segment contains 21,677 customers, representing 22.56% of the customer base.

These customers generated 6,538,599.45 in completed payment value, approximately 42.40% of total completed payment value. Their average customer value was 301.64, but their average recency was approximately 337 days.

This segment represents the largest retention opportunity because it combines high historical value with long inactivity.

### Hibernating Customers

Hibernating is the largest segment, containing 33,363 customers or 34.72% of the customer base.

However, average customer value was only 72.47. A broad reactivation campaign for this entire segment may therefore be less efficient than prioritising higher-value inactive customers.

### Recent Customers

The Promising, New Customer and Potential Loyalist segments together contain approximately 19.08% of the customer base.

Potential Loyalists are particularly important despite representing only 0.57% of customers. They had an average customer value of 290.67 and two completed purchases, suggesting stronger potential for conversion into loyal customers.

### Champions and Loyal Customers

Only 55 customers were classified as Champions and 70 as Loyal Customers.

Their average customer values were high, but the groups were extremely small. This reflects the low purchase frequency across the overall dataset.

## Business Recommendations

### 1. Prioritise the second purchase

The largest customer-lifecycle weakness occurs immediately after acquisition. Month 1 retention was only 0.48%.

The business should test post-purchase activity designed to encourage a second order, such as:

* Personalised product recommendations
* Complementary-product suggestions
* Time-limited second-purchase offers
* Replenishment reminders for suitable categories
* Post-delivery communication triggered after successful fulfilment

The effectiveness of each intervention should be measured with controlled experiments.

### 2. Reactivate high-value customers selectively

High Value at Risk customers generated approximately 42.40% of completed payment value.

Reactivation activity should prioritise these customers before the broader Hibernating segment. Offers can be differentiated according to past category, value and recency.

### 3. Develop Potential Loyalists

Potential Loyalists have already demonstrated repeat behaviour and relatively high average value.

This group should receive targeted cross-selling, category recommendations and loyalty incentives intended to produce a third completed purchase.

### 4. Protect recent high-potential customers

New, Promising and Potential Loyalist customers should be monitored during their first 30 to 90 days.

The objective should be to move them toward a second completed order before their recency score declines.

### 5. Reduce dependence on continuous acquisition

Peak customer months were driven mainly by new customers. Acquisition may continue to support growth, but relying almost entirely on new customers can create high replacement pressure.

Future reporting should monitor both:

* New-customer volume
* Returning-customer rate

A month should not be evaluated as successful solely because total customer activity increased.

## Limitations

* The dataset covers a fixed historical period, so recent cohorts do not have a complete 12-month observation window.
* The beginning and end of the dataset may contain partial months.
* No marketing-channel, campaign-cost or website-traffic data is available.
* Seasonal and promotional causes cannot be confirmed from order data alone.
* RFM thresholds are analytical rules and should be reviewed against commercial objectives.
* The analysis observes activity within the Olist dataset only and cannot identify purchases made outside the platform.
* Payment records do not provide complete explanations for discounts, vouchers, refunds or other adjustments.
* The results show association and behavioural patterns, not causal effects.

## Output Files

| File                                        | Purpose                                            |
| ------------------------------------------- | -------------------------------------------------- |
| `reports/customer_kpi_summary.csv`          | Overall customer KPIs                              |
| `reports/monthly_customer_metrics.csv`      | Monthly acquisition and returning-customer metrics |
| `reports/monthly_customer_growth.csv`       | Continuous monthly growth series                   |
| `reports/customer_cohort_retention.csv`     | Detailed cohort retention                          |
| `reports/cohort_retention_matrix_12m.csv`   | Twelve-month retention matrix                      |
| `reports/cohort_retention_benchmark.csv`    | Weighted retention benchmarks                      |
| `reports/customer_segment_summary.csv`      | RFM segment results                                |
| `reports/customer_analytics_validation.csv` | Customer-model validation checks                   |

## SQL Files

| File                                       | Purpose                                 |
| ------------------------------------------ | --------------------------------------- |
| `sql/07_create_customer_views.sql`         | Creates the customer summary            |
| `sql/08_create_monthly_customer_views.sql` | Creates monthly customer metrics        |
| `sql/09_create_cohort_views.sql`           | Creates cohort-retention views          |
| `sql/10_create_rfm_views.sql`              | Creates RFM and customer-segment views  |
| `sql/11_export_customer_reports.sql`       | Validates and exports customer reports  |
| `sql/12_customer_business_analysis.sql`    | Creates customer KPIs and trend reports |
