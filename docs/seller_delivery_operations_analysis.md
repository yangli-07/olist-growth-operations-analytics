# Seller, Delivery, and Operations Performance Analysis

## 1. Analysis Objective

This analysis evaluates the operational performance of the Olist marketplace, focusing on:

- Overall delivery performance
- The relationship between delivery delays and customer reviews
- Monthly and regional delivery patterns
- Seller-level revenue and operational performance
- Identification of high-value and high-risk sellers
- Validation of analytical outputs against the source data

The analysis uses completed orders and valid delivery records to ensure that delivery metrics are calculated from reliable timestamps.

---

## 2. Analytical Views

### `analytics.v_seller_order_performance`

**Grain:** One row per order–seller combination.

This view contains seller-level order activity, including:

- Seller location
- Customer location
- Item count
- Item price
- Freight value
- Delivery duration
- Delivery delay
- Shipping-limit breach status
- Review score

The order–seller grain prevents duplicate seller metrics when an order contains multiple items from the same seller.

### `analytics.v_seller_performance`

**Grain:** One row per seller.

This view summarizes:

- Completed order count
- Customer count
- Item count
- Item revenue
- Freight value
- Late-delivery rate
- Shipping-limit breach rate
- Average review score
- Low-review rate
- Seller revenue rank

### `analytics.v_monthly_delivery_performance`

**Grain:** One row per calendar month.

This view measures monthly:

- Completed orders
- Valid delivery records
- Late deliveries
- Average delivery time
- Average delay
- Average review score
- Low-review rate

### `analytics.v_state_delivery_performance`

**Grain:** One row per customer state.

This view measures regional:

- Completed orders
- Customer count
- Freight share
- Late-delivery rate
- Average delivery time
- Average review score
- Low-review rate

### `analytics.v_operations_kpis`

**Grain:** One row for the complete analysis period.

This view provides the principal operations KPIs used in this report.

### `analytics.v_delivery_review_impact`

**Grain:** One row per delivery-status group.

Orders are classified as:

- `Late`
- `On Time or Early`

The view compares customer-review outcomes between these groups.

### `analytics.v_seller_risk`

**Grain:** One row per eligible seller.

Only sellers with at least 20 valid deliveries and 20 reviewed orders are included in the risk analysis. This reduces the influence of very small sample sizes.

---

## 3. Overall Operations KPIs

| Metric | Result |
|---|---:|
| Completed orders | 96,477 |
| Valid delivery orders | 95,096 |
| Late-delivery orders | 6,509 |
| Late-delivery rate | 6.84% |
| Average delivery time | 12.56 days |
| Average estimated delivery time | 24.38 days |
| Average carrier-handling time | 3.24 days |
| Average delivery delay | -11.83 days |
| Average delay when late | 10.62 days |
| Reviewed orders | 95,831 |
| Average review score | 4.16 |
| Low-review orders | 12,236 |
| Low-review rate | 12.77% |
| Seller–order combinations | 97,818 |
| Shipping-limit breaches | 8,775 |
| Shipping-limit breach rate | 8.97% |
| Same-state seller–order combinations | 35,186 |
| Same-state delivery rate | 35.97% |

A negative average delivery delay means that orders were generally delivered before their estimated delivery date. Across all valid delivery records, orders arrived approximately 11.83 days earlier than estimated on average.

However, the overall average hides a smaller group of seriously delayed orders. When an order was late, it arrived approximately 10.62 days after its estimated delivery date on average.

---

## 4. Delivery Performance and Customer Reviews

| Delivery status | Orders | Reviewed orders | Average delivery days | Average delay days | Average review score | Low-review rate | Written-comment rate |
|---|---:|---:|---:|---:|---:|---:|---:|
| Late | 6,509 | 6,356 | 33.91 | 10.62 | 2.27 | 62.41% | 58.90% |
| On Time or Early | 88,587 | 88,101 | 10.99 | -13.48 | 4.29 | 9.22% | 39.34% |

Delivery performance has a strong relationship with customer satisfaction.

Late orders received an average review score of only 2.27, compared with 4.29 for orders delivered on time or early.

The low-review rate increased from 9.22% for on-time orders to 62.41% for late orders. This represents an increase of 53.19 percentage points.

Customers experiencing late deliveries were also more likely to write comments. The written-comment rate was 58.90% for late deliveries, compared with 39.34% for on-time deliveries. This suggests that negative delivery experiences are more likely to generate detailed customer feedback.

These results establish delivery delays as one of the strongest operational indicators of customer dissatisfaction in the dataset. The analysis demonstrates association, although it does not by itself prove causation.

---

## 5. Monthly Delivery Performance

Delivery performance varies substantially between months.

Examples from the monthly analysis include:

| Month | Completed orders | Late-delivery rate | Average delivery days | Average review score | Low-review rate |
|---|---:|---:|---:|---:|---:|
| 2018-02 | 6,555 | 14.15% | 16.88 | 3.88 | 19.26% |
| 2018-06 | 6,099 | 1.17% | 9.19 | 4.31 | 9.99% |
| 2018-07 | 6,159 | 3.61% | 9.10 | 4.32 | 9.66% |
| 2018-08 | 6,351 | 6.24% | 7.67 | 4.31 | 9.54% |

February 2018 had a relatively high late-delivery rate of 14.15%, an average delivery time of 16.88 days, and an average review score of 3.88.

By comparison, June and July 2018 had much lower late-delivery rates and average review scores above 4.30.

Monthly operational monitoring can therefore help identify periods in which logistics performance is placing customer satisfaction at risk.

---

## 6. Regional Delivery Performance

Delivery performance also differs substantially across customer states.

Selected examples include:

| Customer state | Completed orders | Freight share | Late-delivery rate | Average delivery days | Average review score | Low-review rate |
|---|---:|---:|---:|---:|---:|---:|
| AL | 397 | 16.26% | 21.12% | 24.34 | 3.85 | 21.07% |
| MA | 717 | 20.83% | 17.73% | 21.60 | 3.83 | 19.94% |
| SE | 335 | 19.51% | 15.32% | 21.53 | 3.91 | 18.86% |
| SP | 40,500 | 12.17% | 4.54% | 8.74 | 4.25 | 10.64% |

São Paulo (`SP`) combines the largest order volume with comparatively strong delivery performance. Its late-delivery rate was 4.54%, and its average delivery time was 8.74 days.

In contrast, states such as Alagoas (`AL`), Maranhão (`MA`), and Sergipe (`SE`) experienced longer delivery times, higher late-delivery rates, and lower customer-review scores.

The results indicate that operational performance is geographically uneven. Regions with high freight costs and long delivery times may require improved carrier coverage, regional fulfilment capacity, or more conservative delivery estimates.

---

## 7. Seller Risk Segmentation

Eligible sellers were evaluated using three operational indicators:

- Late-delivery rate
- Shipping-limit breach rate
- Low-review rate

Each indicator was divided into quartiles. The three quartile scores were added together to create an operational risk score.

High-value sellers were defined as sellers ranked within the top 100 by item revenue.

### Segment Summary

| Seller segment | Seller count | High-value seller count | Average late-delivery rate | Average low-review rate | Item revenue |
|---|---:|---:|---:|---:|---:|
| Monitor | 300 | 49 | 6.96% | 13.34% | 4,940,700.56 |
| Stable | 307 | 26 | 2.90% | 7.45% | 3,051,505.95 |
| High-Value At Risk | 24 | 24 | 11.15% | 19.80% | 1,597,147.23 |
| High Risk | 164 | 0 | 11.82% | 20.59% | 1,274,371.18 |

The 24 high-value sellers classified as `High-Value At Risk` are the highest operational priority. They represent commercially important sellers with relatively high late-delivery, shipping-limit breach, or low-review rates.

The `High Risk` segment contains 164 additional sellers with weak operational performance. Although they are not among the top 100 sellers by revenue, they may still create customer-service costs and damage marketplace trust.

The `Monitor` segment contains 300 sellers whose performance is not currently severe enough for the high-risk category but should be monitored for deterioration.

---

## 8. Recommended Actions

### Prioritize high-value sellers at risk

The 24 high-value at-risk sellers should receive individual operational reviews. Recommended checks include:

- Product preparation time
- Shipping-limit compliance
- Carrier handover processes
- Seller location and customer-distance patterns
- Product categories associated with delays
- Recent low-review comments

### Introduce seller performance thresholds

Seller monitoring should include clear thresholds for:

- Late-delivery rate
- Shipping-limit breach rate
- Low-review rate
- Minimum number of valid observations

Seller performance should be reviewed over a rolling time window so that recent improvements or deterioration can be detected.

### Investigate regional logistics constraints

States with long delivery times and high freight shares should be examined for:

- Limited carrier coverage
- Long transport distances
- Insufficient regional fulfilment capacity
- Unrealistic delivery estimates
- Concentration of underperforming sellers

### Connect operational and customer-service workflows

Because late deliveries are strongly associated with low review scores and written comments, delayed orders should trigger proactive proactive customer communication.

Possible actions include:

- Revised delivery notifications
- Automatic delay alerts
- Customer-service outreach
- Delivery-status transparency
- Compensation policies for severe delays

### Improve delivery-time forecasting

Orders were generally delivered earlier than estimated, but late orders missed their estimates by a substantial margin.

This suggests that delivery estimates may be conservative for normal orders but insufficiently sensitive to high-risk sellers, routes, or regions. A more targeted forecasting model could provide narrower and more reliable delivery windows.

---

## 9. Data Quality and Validation

The following validation checks were performed:

| Validation metric | Expected | Actual | Passed |
|---|---:|---:|:---:|
| Delivery-status orders | 95,096 | 95,096 | Yes |
| Monthly completed orders | 96,477 | 96,477 | Yes |
| Overall completed orders | 96,477 | 96,477 | Yes |
| Duplicate seller grains | 0 | 0 | Yes |
| Duplicate seller–order grains | 0 | 0 | Yes |
| State completed orders | 96,477 | 96,477 | Yes |

All six validation checks passed.

The seller-level and seller–order-level views also reconstructed:

- 110,194 order items
- 13,221,363.14 in item price
- 2,198,267.15 in freight value

These totals match the source analytical data.

---

## 10. Metric Interpretation Notes

### Completed orders versus valid delivery orders

There were 96,477 completed orders but only 95,096 valid delivery records.

Delivery-duration and late-delivery metrics use the 95,096 valid records because some completed orders contain missing or inconsistent delivery timestamps.

### Order grain versus seller–order grain

Marketplace orders may contain products from multiple sellers. Therefore:

- Overall delivery metrics use the order grain.
- Seller performance uses the order–seller grain.
- Seller–order counts must not be interpreted as unique marketplace orders.

### Shipping-limit breach

A shipping-limit breach means that at least one item associated with the seller–order combination was transferred after its expected shipping-limit date.

This is an operational warning indicator and is not identical to late customer delivery.

### Review relationship

The comparison between delivery status and review performance demonstrates a strong association. Other factors—such as product quality, communication, and order accuracy—may also influence review scores.

---

## 11. Report Outputs

The analysis generates the following CSV reports:

- `reports/overall_operations_kpis.csv`
- `reports/monthly_delivery_performance.csv`
- `reports/state_delivery_performance.csv`
- `reports/seller_performance.csv`
- `reports/priority_sellers.csv`
- `reports/delivery_review_impact.csv`
- `reports/operations_validation.csv`

These reports can be used for dashboard development, seller monitoring, regional analysis, and operational decision-making.
