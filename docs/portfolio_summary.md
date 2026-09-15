# Portfolio and CV Summary

## Project Title

**Olist Growth and Operations Analytics**

## Portfolio Link

* [Interactive Tableau Dashboard](https://public.tableau.com/views/OlistGrowthandOperationsAnalytics/OperationsandSellers)
* [Project Documentation](../README.md)

## One-Line Description

An end-to-end e-commerce analytics project using Python, PostgreSQL, SQL, Jupyter, and Tableau to analyse customer growth, retention, sales performance, delivery quality, and seller risk.

## CV Project Entry

**Olist Growth and Operations Analytics | Python, PostgreSQL, SQL, Tableau**

* Built an end-to-end analytics workflow for a Brazilian e-commerce dataset, including data-quality checks, a relational PostgreSQL model, 16 SQL scripts, reusable analytical views, and 41 validated reporting outputs.
* Analysed 96,477 completed orders and R$15.42 million in payment value, identifying low repeat-purchase behaviour, leading product categories, revenue concentration, and state-level delivery differences.
* Developed four Tableau dashboards and a rule-based seller-risk framework, showing that late deliveries had a 2.27 average review score and a 62.41% low-review rate, compared with 4.29 and 9.22% for on-time or early deliveries.

## Short CV Version

* Analysed 96,477 Olist orders using Python, PostgreSQL, SQL, and Tableau, creating validated analytical views and four interactive dashboards covering growth, retention, sales, delivery, and seller risk.
* Identified a strong relationship between late delivery and poor reviews and segmented 795 sellers into operational risk groups to support prioritised intervention.

## LinkedIn Project Description

Developed an end-to-end analytics portfolio project using the Brazilian Olist e-commerce dataset. I used Python for data auditing and visual analysis, PostgreSQL and SQL for relational modelling and reusable business views, and Tableau Public for four interactive dashboards.

The analysis covered 96,477 completed orders and R$15.42 million in customer payments. Key findings included limited repeat-purchase behaviour, strong revenue contributions from health and beauty and watches and gifts, substantial differences in delivery performance across states, and a strong association between late delivery and poor customer reviews.

I also created a rule-based seller-risk framework that classified 795 eligible sellers into Stable, Monitor, High Risk, and High-Value At Risk groups.

## Interview Explanation

I developed this project to demonstrate a complete analytics workflow rather than producing only a single notebook or dashboard.

I began by auditing the raw Olist files in Python, checking data types, missing values, duplicate keys, date fields, geographic coverage, and category translations. I then designed and loaded a relational PostgreSQL database with constraints and indexes.

After validating the database, I created reusable SQL views for completed orders, customer activity, cohort retention, RFM segmentation, sales performance, delivery operations, and seller performance. I reconciled the reporting views back to the underlying order totals to avoid duplicate analytical grains.

The final analysis covered 96,477 completed orders and R$15.42 million in payment value. One of the clearest findings was that late deliveries had an average review score of 2.27 and a 62.41% low-review rate, compared with 4.29 and 9.22% for on-time or early deliveries.

I presented the findings through Python visualisations and four Tableau dashboards covering executive KPIs, customer analytics, sales and products, and operations and sellers.

## Key Technical Decisions

### Why PostgreSQL?

PostgreSQL provided a reproducible relational structure, explicit constraints, reusable views, and SQL functionality such as common table expressions and window functions.

### How was double counting prevented?

Each analytical view was assigned a defined reporting grain. Order-level, customer-level, seller-level, category-level, and monthly outputs were validated separately, and reconstructed totals were compared with trusted completed-order totals.

### Why exclude most 2016 activity from trend comparisons?

The available 2016 observations represent an incomplete initial period. The main comparison window therefore runs from January 2017 to August 2018.

### Is the delivery-review relationship causal?

No. The project identifies a strong association between delivery timing and review outcomes, but the observational dataset does not establish causality.

### How was seller risk defined?

Eligible sellers were classified using operational indicators such as late-delivery rate, shipping-limit breaches, low-review rate, and commercial value. The resulting segments support prioritisation but would require further validation before production deployment.

## Skills Demonstrated

* Python data validation and exploratory analysis
* pandas data manipulation
* PostgreSQL database design
* SQL joins, CTEs, views, aggregations, and window functions
* Reporting-grain definition and reconciliation
* Customer cohort and RFM analysis
* Sales, product, delivery, and seller-performance analysis
* Tableau dashboard design
* Data storytelling and business recommendations
* Git and GitHub version control
