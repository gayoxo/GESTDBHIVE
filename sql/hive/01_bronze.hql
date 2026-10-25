-- =====================================================================
-- BRONZE: las fuentes tal cual, sin copiar datos (schema-on-read)
--   * MariaDB y PostgreSQL -> tablas externas JDBC (consulta federada)
--   * Ficheros CSV / JSON  -> tablas externas sobre datasets/landing
-- Todas las columnas de ficheros se leen como STRING: los tipos se
-- deciden en Silver.
-- Variables: ${hivevar:reader_user} y ${hivevar:reader_password}
-- (las pasa scripts/03_hive.sh desde .env)
-- =====================================================================
CREATE DATABASE IF NOT EXISTS bronze;
USE bronze;

-- ---------- MariaDB (clientes y vendedores) --------------------------
DROP TABLE IF EXISTS clientes;
CREATE EXTERNAL TABLE clientes (
    customer_id              STRING,
    customer_unique_id       STRING,
    customer_zip_code_prefix STRING,
    customer_city            STRING,
    customer_state           STRING
)
STORED BY 'org.apache.hive.storage.jdbc.JdbcStorageHandler'
TBLPROPERTIES (
    "hive.sql.database.type" = "MYSQL",
    "hive.sql.jdbc.driver"   = "org.mariadb.jdbc.Driver",
    "hive.sql.jdbc.url"      = "jdbc:mariadb://hive4-mariadb:3306/olist",
    "hive.sql.dbcp.username" = "${hivevar:reader_user}",
    "hive.sql.dbcp.password" = "${hivevar:reader_password}",
    "hive.sql.table"         = "customers"
);

DROP TABLE IF EXISTS vendedores;
CREATE EXTERNAL TABLE vendedores (
    seller_id              STRING,
    seller_zip_code_prefix STRING,
    seller_city            STRING,
    seller_state           STRING
)
STORED BY 'org.apache.hive.storage.jdbc.JdbcStorageHandler'
TBLPROPERTIES (
    "hive.sql.database.type" = "MYSQL",
    "hive.sql.jdbc.driver"   = "org.mariadb.jdbc.Driver",
    "hive.sql.jdbc.url"      = "jdbc:mariadb://hive4-mariadb:3306/olist",
    "hive.sql.dbcp.username" = "${hivevar:reader_user}",
    "hive.sql.dbcp.password" = "${hivevar:reader_password}",
    "hive.sql.table"         = "sellers"
);

-- ---------- PostgreSQL (pedidos y lineas de pedido) ------------------
DROP TABLE IF EXISTS pedidos;
CREATE EXTERNAL TABLE pedidos (
    order_id                      STRING,
    customer_id                   STRING,
    order_status                  STRING,
    order_purchase_timestamp      TIMESTAMP,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
)
STORED BY 'org.apache.hive.storage.jdbc.JdbcStorageHandler'
TBLPROPERTIES (
    "hive.sql.database.type" = "POSTGRES",
    "hive.sql.jdbc.driver"   = "org.postgresql.Driver",
    "hive.sql.jdbc.url"      = "jdbc:postgresql://hive4-postgres2:5432/olist",
    "hive.sql.dbcp.username" = "${hivevar:reader_user}",
    "hive.sql.dbcp.password" = "${hivevar:reader_password}",
    "hive.sql.table"         = "orders"
);

DROP TABLE IF EXISTS articulos;
CREATE EXTERNAL TABLE articulos (
    order_id            STRING,
    order_item_id       INT,
    product_id          STRING,
    seller_id           STRING,
    shipping_limit_date TIMESTAMP,
    price               DECIMAL(12,2),
    freight_value       DECIMAL(12,2)
)
STORED BY 'org.apache.hive.storage.jdbc.JdbcStorageHandler'
TBLPROPERTIES (
    "hive.sql.database.type" = "POSTGRES",
    "hive.sql.jdbc.driver"   = "org.postgresql.Driver",
    "hive.sql.jdbc.url"      = "jdbc:postgresql://hive4-postgres2:5432/olist",
    "hive.sql.dbcp.username" = "${hivevar:reader_user}",
    "hive.sql.dbcp.password" = "${hivevar:reader_password}",
    "hive.sql.table"         = "order_items"
);

-- ---------- Ficheros CSV (productos, categorias, pagos) --------------
DROP TABLE IF EXISTS productos;
CREATE EXTERNAL TABLE productos (
    product_id                 STRING,
    product_category_name      STRING,
    product_name_lenght        STRING,
    product_description_lenght STRING,
    product_photos_qty         STRING,
    product_weight_g           STRING,
    product_length_cm          STRING,
    product_height_cm          STRING,
    product_width_cm           STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ("separatorChar" = ",", "quoteChar" = "\"")
STORED AS TEXTFILE
LOCATION 'file:///datasets/landing/productos'
TBLPROPERTIES ("skip.header.line.count" = "1");

DROP TABLE IF EXISTS categorias;
CREATE EXTERNAL TABLE categorias (
    product_category_name         STRING,
    product_category_name_english STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ("separatorChar" = ",", "quoteChar" = "\"")
STORED AS TEXTFILE
LOCATION 'file:///datasets/landing/categorias'
TBLPROPERTIES ("skip.header.line.count" = "1");

DROP TABLE IF EXISTS pagos;
CREATE EXTERNAL TABLE pagos (
    order_id             STRING,
    payment_sequential   STRING,
    payment_type         STRING,
    payment_installments STRING,
    payment_value        STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ("separatorChar" = ",", "quoteChar" = "\"")
STORED AS TEXTFILE
LOCATION 'file:///datasets/landing/pagos'
TBLPROPERTIES ("skip.header.line.count" = "1");

-- ---------- Fichero JSON Lines (resenas) -----------------------------
DROP TABLE IF EXISTS resenas;
CREATE EXTERNAL TABLE resenas (
    review_id               STRING,
    order_id                STRING,
    review_score            STRING,
    review_comment_title    STRING,
    review_comment_message  STRING,
    review_creation_date    STRING,
    review_answer_timestamp STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.JsonSerDe'
STORED AS TEXTFILE
LOCATION 'file:///datasets/landing/resenas';

-- ---------- Comprobacion: filas visibles desde Hive ------------------
SELECT 'clientes (MariaDB)' AS tabla, COUNT(*) AS filas FROM clientes
UNION ALL SELECT 'vendedores (MariaDB)',    COUNT(*) FROM vendedores
UNION ALL SELECT 'pedidos (PostgreSQL)',    COUNT(*) FROM pedidos
UNION ALL SELECT 'articulos (PostgreSQL)',  COUNT(*) FROM articulos
UNION ALL SELECT 'productos (CSV)',         COUNT(*) FROM productos
UNION ALL SELECT 'categorias (CSV)',        COUNT(*) FROM categorias
UNION ALL SELECT 'pagos (CSV)',             COUNT(*) FROM pagos
UNION ALL SELECT 'resenas (JSON)',          COUNT(*) FROM resenas;
