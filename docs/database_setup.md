# PostgreSQL Database Setup

## Overview

The cleaned Olist datasets are stored in a PostgreSQL database named `olist_analytics`.

All project tables are organised inside the `olist` schema. The database can be reproduced using the SQL scripts stored in the `sql/` directory.

## Requirements

* PostgreSQL 18
* Nine cleaned CSV files in `data/processed/`
* A local PostgreSQL database named `olist_analytics`

## Build Process

Run the following commands from the project root:

```bash
createdb olist_analytics
```

Create the database tables:

```bash
psql -d olist_analytics \
  -f sql/01_create_tables.sql
```

Import the cleaned datasets:

```bash
psql -d olist_analytics \
  -f sql/02_load_data.sql
```

Add foreign keys and indexes:

```bash
psql -d olist_analytics \
  -f sql/03_constraints_indexes.sql
```

Run the final database validation:

```bash
psql -d olist_analytics \
  -f sql/04_validate_database.sql
```

## Database Tables

| Table                  | Grain                                   | Primary key                      |
| ---------------------- | --------------------------------------- | -------------------------------- |
| `category_translation` | One row per Portuguese category         | `product_category_name`          |
| `customers`            | One row per order-level customer record | `customer_id`                    |
| `geolocation`          | One row per ZIP-code prefix             | `geolocation_zip_code_prefix`    |
| `order_items`          | One row per item within an order        | `order_id`, `order_item_id`      |
| `orders`               | One row per order                       | `order_id`                       |
| `payments`             | One row per payment sequence            | `order_id`, `payment_sequential` |
| `products`             | One row per product                     | `product_id`                     |
| `reviews`              | One row per review-order combination    | `review_id`, `order_id`          |
| `sellers`              | One row per seller                      | `seller_id`                      |

## Imported Row Counts

| Table                  |    Rows |
| ---------------------- | ------: |
| `category_translation` |      74 |
| `customers`            |  99,441 |
| `geolocation`          |  19,015 |
| `order_items`          | 112,650 |
| `orders`               |  99,441 |
| `payments`             | 103,886 |
| `products`             |  32,951 |
| `reviews`              |  99,224 |
| `sellers`              |   3,095 |

## Primary Keys

Primary keys ensure that each business record can be uniquely identified.

Composite primary keys are used where one field alone is not unique:

* `order_items`: `order_id` and `order_item_id`
* `payments`: `order_id` and `payment_sequential`
* `reviews`: `review_id` and `order_id`

## Foreign Keys

Seven foreign-key relationships enforce referential integrity:

* `orders.customer_id` references `customers.customer_id`
* `order_items.order_id` references `orders.order_id`
* `order_items.product_id` references `products.product_id`
* `order_items.seller_id` references `sellers.seller_id`
* `payments.order_id` references `orders.order_id`
* `reviews.order_id` references `orders.order_id`
* `products.product_category_name` references `category_translation.product_category_name`

Customer and seller ZIP-code prefixes are not foreign keys to the `geolocation` table. Some valid customer and seller ZIP codes do not have matching geolocation records. These business records are retained and can be handled using left joins during analysis.

## Indexes

Indexes were created for fields frequently used in joins, filters and analytical queries:

* Customer unique ID
* Customer ZIP-code prefix
* Seller ZIP-code prefix
* Order customer ID
* Order purchase timestamp
* Order-item product ID
* Order-item seller ID
* Review order ID
* English product category

PostgreSQL also creates indexes automatically for primary keys.

## Data Types

The main database types were selected according to the meaning of each field:

* IDs are stored as `VARCHAR`
* ZIP-code prefixes are stored as five-character strings
* Dates and times are stored as `TIMESTAMP`
* Monetary values are stored as `NUMERIC`
* Coordinates are stored as `DOUBLE PRECISION`
* Quality flags are stored as `BOOLEAN`
* Review scores are stored as `SMALLINT`

ZIP codes are stored as strings because they are identifiers rather than quantities and may begin with zero.

## Data-Quality Constraints

The database includes checks that ensure:

* ZIP-code prefixes contain five digits
* Latitude values are between −90 and 90
* Longitude values are between −180 and 180
* Product prices and freight values are not negative
* Payment values are not negative
* Payment instalments are at least one
* Non-missing product weights are positive
* Review scores are between one and five
* Geolocation observation counts are positive

## Design Decisions

### Separate schema

All project tables are stored in the `olist` schema. This keeps them separate from PostgreSQL system objects and other projects.

### Client-side CSV import

The cleaned files are imported using the PostgreSQL `\copy` command. This reads files from the user’s computer and does not require server-level file permissions.

### Transactional import

All nine datasets are loaded inside one transaction. If an import fails, the transaction is rolled back so the database is not left partially populated.

### Constraints after import

Foreign keys and indexes are added after the CSV files have been loaded. This makes bulk loading more efficient and produces clearer errors when relationships are invalid.

### Source field names

The source spellings `product_name_lenght` and `product_description_lenght` are retained so that the PostgreSQL schema remains consistent with the cleaned CSV headers.

### Local data storage

The processed CSV files remain local and are excluded from GitHub. The SQL scripts, documentation and validation reports are included in the repository.

## Validation

The final validation contains 22 automated checks covering:

* Table row counts
* Foreign-key relationships
* Missing parent records
* Payment instalments
* Product weights
* English category coverage
* Geolocation coordinates
* Foreign-key count
* Custom index count

Every validation check must return:

```text
PASS
```

The exported validation report is stored at:

```text
reports/database_validation.csv
```

## SQL Files

| File                             | Purpose                                     |
| -------------------------------- | ------------------------------------------- |
| `sql/01_create_tables.sql`       | Creates the schema and nine database tables |
| `sql/02_load_data.sql`           | Imports the nine cleaned CSV files          |
| `sql/03_constraints_indexes.sql` | Adds foreign keys and analytical indexes    |
| `sql/04_validate_database.sql`   | Runs final database validation checks       |
