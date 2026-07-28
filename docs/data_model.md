# Olist Data Model

## 1. Dataset Grain

| Table | Grain | Primary key |
|---|---|---|
| customers | One order-specific customer record | customer_id |
| orders | One customer order | order_id |
| order_items | One item sequence within an order | order_id + order_item_id |
| payments | One payment sequence within an order | order_id + payment_sequential |
| reviews | One review and order combination | review_id + order_id |
| products | One product | product_id |
| sellers | One seller | seller_id |
| category_translation | One product category translation | product_category_name |
| geolocation | One geographical observation | No unique primary key |

## 2. Main Relationships

- `orders.customer_id` → `customers.customer_id`
- `order_items.order_id` → `orders.order_id`
- `order_items.product_id` → `products.product_id`
- `order_items.seller_id` → `sellers.seller_id`
- `payments.order_id` → `orders.order_id`
- `reviews.order_id` → `orders.order_id`
- `products.product_category_name` → `category_translation.product_category_name`

## 3. Key Findings

- The customers table contains 99,441 `customer_id` values but only 96,096 `customer_unique_id` values.
- `customer_id` identifies an order-specific customer record.
- `customer_unique_id` identifies the same real customer across different orders.
- Customer retention and repeat-purchase analysis must therefore use `customer_unique_id`.
- `review_id` is not unique by itself.
- The combination of `review_id` and `order_id` is unique.
- Geolocation ZIP-code prefixes are highly duplicated and cannot be used as a primary key.

## 4. Data Quality Findings

- 610 products have a missing product category.
- 13 products belong to two categories that are missing from the English translation table:
  - `portateis_cozinha_e_preparadores_de_alimentos`: 10 products
  - `pc_gamer`: 3 products
- Missing categories will later be labelled as `unknown`.
- Untranslated categories will be retained rather than deleted.

## 5. Join Rules

1. Aggregate order items to order level before joining them to orders.
2. Aggregate payments to order level before joining them to orders.
3. Aggregate reviews to order level before joining them to orders.
4. Aggregate geolocation data to one row per ZIP-code prefix before joining.
5. Use left joins when adding category translations.
6. Validate row counts before and after every join to prevent accidental row duplication.
