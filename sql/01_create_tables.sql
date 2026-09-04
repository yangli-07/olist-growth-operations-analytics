BEGIN;

CREATE SCHEMA IF NOT EXISTS olist;

CREATE TABLE IF NOT EXISTS olist.category_translation (
    product_category_name TEXT PRIMARY KEY,
    product_category_name_english TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS olist.customers (
    customer_id VARCHAR(32) PRIMARY KEY,
    customer_unique_id VARCHAR(32) NOT NULL,
    customer_zip_code_prefix VARCHAR(5) NOT NULL,
    customer_city TEXT NOT NULL,
    customer_state VARCHAR(2) NOT NULL,
    CHECK (
        customer_zip_code_prefix ~ '^[0-9]{5}$'
    )
);

CREATE TABLE IF NOT EXISTS olist.geolocation (
    geolocation_zip_code_prefix VARCHAR(5) PRIMARY KEY,
    geolocation_lat DOUBLE PRECISION NOT NULL,
    geolocation_lng DOUBLE PRECISION NOT NULL,
    geolocation_city TEXT NOT NULL,
    geolocation_state VARCHAR(2) NOT NULL,
    geolocation_observation_count INTEGER NOT NULL,
    CHECK (
        geolocation_zip_code_prefix ~ '^[0-9]{5}$'
    ),
    CHECK (
        geolocation_lat BETWEEN -90 AND 90
    ),
    CHECK (
        geolocation_lng BETWEEN -180 AND 180
    ),
    CHECK (
        geolocation_observation_count > 0
    )
);

CREATE TABLE IF NOT EXISTS olist.order_items (
    order_id VARCHAR(32) NOT NULL,
    order_item_id INTEGER NOT NULL,
    product_id VARCHAR(32) NOT NULL,
    seller_id VARCHAR(32) NOT NULL,
    shipping_limit_date TIMESTAMP NOT NULL,
    price NUMERIC(12, 2) NOT NULL,
    freight_value NUMERIC(12, 2) NOT NULL,
    PRIMARY KEY (
        order_id,
        order_item_id
    ),
    CHECK (price >= 0),
    CHECK (freight_value >= 0)
);

CREATE TABLE IF NOT EXISTS olist.orders (
    order_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    order_status TEXT NOT NULL,
    order_purchase_timestamp TIMESTAMP NOT NULL,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP NOT NULL,
    has_timestamp_anomaly BOOLEAN NOT NULL,
    has_status_date_mismatch BOOLEAN NOT NULL,
    is_valid_delivery_record BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS olist.payments (
    order_id VARCHAR(32) NOT NULL,
    payment_sequential INTEGER NOT NULL,
    payment_type TEXT NOT NULL,
    payment_installments INTEGER NOT NULL,
    payment_value NUMERIC(12, 2) NOT NULL,
    PRIMARY KEY (
        order_id,
        payment_sequential
    ),
    CHECK (payment_installments >= 1),
    CHECK (payment_value >= 0)
);

CREATE TABLE IF NOT EXISTS olist.products (
    product_id VARCHAR(32) PRIMARY KEY,
    product_category_name TEXT NOT NULL,
    product_name_lenght NUMERIC,
    product_description_lenght NUMERIC,
    product_photos_qty NUMERIC,
    product_weight_g NUMERIC,
    product_length_cm NUMERIC,
    product_height_cm NUMERIC,
    product_width_cm NUMERIC,
    product_category_name_english TEXT NOT NULL,
    CHECK (
        product_weight_g IS NULL
        OR product_weight_g > 0
    )
);

CREATE TABLE IF NOT EXISTS olist.reviews (
    review_id VARCHAR(32) NOT NULL,
    order_id VARCHAR(32) NOT NULL,
    review_score SMALLINT NOT NULL,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP NOT NULL,
    review_answer_timestamp TIMESTAMP NOT NULL,
    PRIMARY KEY (
        review_id,
        order_id
    ),
    CHECK (review_score BETWEEN 1 AND 5)
);

CREATE TABLE IF NOT EXISTS olist.sellers (
    seller_id VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(5) NOT NULL,
    seller_city TEXT NOT NULL,
    seller_state VARCHAR(2) NOT NULL,
    CHECK (
        seller_zip_code_prefix ~ '^[0-9]{5}$'
    )
);

COMMIT;