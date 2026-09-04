\set ON_ERROR_STOP on

BEGIN;

\copy olist.category_translation FROM 'data/processed/category_translation_clean.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy olist.customers FROM 'data/processed/customers_clean.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy olist.geolocation FROM 'data/processed/geolocation_clean.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy olist.order_items FROM 'data/processed/order_items_clean.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy olist.orders FROM 'data/processed/orders_clean.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy olist.payments FROM 'data/processed/payments_clean.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy olist.products FROM 'data/processed/products_clean.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy olist.reviews FROM 'data/processed/reviews_clean.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

\copy olist.sellers FROM 'data/processed/sellers_clean.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

COMMIT;

SELECT
    'category_translation' AS table_name,
    COUNT(*) AS row_count
FROM olist.category_translation

UNION ALL

SELECT 'customers', COUNT(*)
FROM olist.customers

UNION ALL

SELECT 'geolocation', COUNT(*)
FROM olist.geolocation

UNION ALL

SELECT 'order_items', COUNT(*)
FROM olist.order_items

UNION ALL

SELECT 'orders', COUNT(*)
FROM olist.orders

UNION ALL

SELECT 'payments', COUNT(*)
FROM olist.payments

UNION ALL

SELECT 'products', COUNT(*)
FROM olist.products

UNION ALL

SELECT 'reviews', COUNT(*)
FROM olist.reviews

UNION ALL

SELECT 'sellers', COUNT(*)
FROM olist.sellers

ORDER BY table_name;