-- Fuente operacional 1 (MariaDB): clientes y vendedores de Olist.
-- Se ejecuta con el cliente mariadb --local-infile=1 dentro del contenedor.
USE olist;

CREATE TABLE IF NOT EXISTS customers (
    customer_id              VARCHAR(32)  PRIMARY KEY,
    customer_unique_id       VARCHAR(32)  NOT NULL,
    customer_zip_code_prefix VARCHAR(10),
    customer_city            VARCHAR(100),
    customer_state           CHAR(2)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sellers (
    seller_id              VARCHAR(32)  PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10),
    seller_city            VARCHAR(100),
    seller_state           CHAR(2)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

TRUNCATE TABLE customers;
LOAD DATA LOCAL INFILE '/datasets/olist/olist_customers_dataset.csv'
    INTO TABLE customers CHARACTER SET utf8mb4
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES;

TRUNCATE TABLE sellers;
LOAD DATA LOCAL INFILE '/datasets/olist/olist_sellers_dataset.csv'
    INTO TABLE sellers CHARACTER SET utf8mb4
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES;

SELECT 'customers' AS tabla, COUNT(*) AS filas FROM customers
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers;
