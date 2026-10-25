-- Fuente operacional 2 (PostgreSQL): pedidos y lineas de pedido de Olist.
-- Se ejecuta con psql como usuario olist (propietario de la BD) y recibe
-- las variables reader_user y reader_password para el usuario de Hive.
\set ON_ERROR_STOP on

CREATE TABLE IF NOT EXISTS orders (
    order_id                      VARCHAR(32) PRIMARY KEY,
    customer_id                   VARCHAR(32) NOT NULL,
    order_status                  VARCHAR(20) NOT NULL,
    order_purchase_timestamp      TIMESTAMP,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
    order_id            VARCHAR(32)   NOT NULL REFERENCES orders (order_id),
    order_item_id       INTEGER       NOT NULL,
    product_id          VARCHAR(32)   NOT NULL,
    seller_id           VARCHAR(32)   NOT NULL,
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(12,2) NOT NULL,
    freight_value       NUMERIC(12,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);

TRUNCATE TABLE order_items, orders;
COPY orders      FROM '/datasets/olist/olist_orders_dataset.csv'      WITH (FORMAT csv, HEADER true);
COPY order_items FROM '/datasets/olist/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true);

-- Usuario de solo lectura con el que Hive consulta esta fuente
SELECT format('CREATE ROLE %I LOGIN', :'reader_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'reader_user') \gexec
ALTER ROLE :"reader_user" WITH LOGIN PASSWORD :'reader_password';
GRANT CONNECT ON DATABASE olist TO :"reader_user";
GRANT USAGE ON SCHEMA public TO :"reader_user";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO :"reader_user";

SELECT 'orders' AS tabla, COUNT(*) AS filas FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items;
