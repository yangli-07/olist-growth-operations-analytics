\set ON_ERROR_STOP on

BEGIN;

-- Foreign-key constraints

ALTER TABLE olist.orders
ADD CONSTRAINT fk_orders_customer
FOREIGN KEY (customer_id)
REFERENCES olist.customers (customer_id);

ALTER TABLE olist.order_items
ADD CONSTRAINT fk_order_items_order
FOREIGN KEY (order_id)
REFERENCES olist.orders (order_id);

ALTER TABLE olist.order_items
ADD CONSTRAINT fk_order_items_product
FOREIGN KEY (product_id)
REFERENCES olist.products (product_id);

ALTER TABLE olist.order_items
ADD CONSTRAINT fk_order_items_seller
FOREIGN KEY (seller_id)
REFERENCES olist.sellers (seller_id);

ALTER TABLE olist.payments
ADD CONSTRAINT fk_payments_order
FOREIGN KEY (order_id)
REFERENCES olist.orders (order_id);

ALTER TABLE olist.reviews
ADD CONSTRAINT fk_reviews_order
FOREIGN KEY (order_id)
REFERENCES olist.orders (order_id);

ALTER TABLE olist.products
ADD CONSTRAINT fk_products_category_translation
FOREIGN KEY (product_category_name)
REFERENCES olist.category_translation (
    product_category_name
);

-- Indexes for joins and common analytical filters

CREATE INDEX IF NOT EXISTS
idx_customers_customer_unique_id
ON olist.customers (customer_unique_id);

CREATE INDEX IF NOT EXISTS
idx_customers_zip_code_prefix
ON olist.customers (customer_zip_code_prefix);

CREATE INDEX IF NOT EXISTS
idx_sellers_zip_code_prefix
ON olist.sellers (seller_zip_code_prefix);

CREATE INDEX IF NOT EXISTS
idx_orders_customer_id
ON olist.orders (customer_id);

CREATE INDEX IF NOT EXISTS
idx_orders_purchase_timestamp
ON olist.orders (order_purchase_timestamp);

CREATE INDEX IF NOT EXISTS
idx_order_items_product_id
ON olist.order_items (product_id);

CREATE INDEX IF NOT EXISTS
idx_order_items_seller_id
ON olist.order_items (seller_id);

CREATE INDEX IF NOT EXISTS
idx_reviews_order_id
ON olist.reviews (order_id);

CREATE INDEX IF NOT EXISTS
idx_products_category_english
ON olist.products (
    product_category_name_english
);

COMMIT;

ANALYZE olist.category_translation;
ANALYZE olist.customers;
ANALYZE olist.geolocation;
ANALYZE olist.order_items;
ANALYZE olist.orders;
ANALYZE olist.payments;
ANALYZE olist.products;
ANALYZE olist.reviews;
ANALYZE olist.sellers;

-- Display the foreign keys created above

SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS referenced_table,
    ccu.column_name AS referenced_column
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.constraint_schema = kcu.constraint_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON tc.constraint_name = ccu.constraint_name
    AND tc.constraint_schema = ccu.constraint_schema
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'olist'
ORDER BY
    tc.table_name,
    kcu.column_name;