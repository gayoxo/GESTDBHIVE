-- =====================================================================
-- GOLD: modelo en estrella orientado a preguntas de negocio
--   fact_ventas (grano: articulo vendido), particionada por anio/mes
--   dim_cliente, dim_vendedor, dim_producto, dim_tiempo
--   + un agregado listo para cuadros de mando
-- =====================================================================
CREATE DATABASE IF NOT EXISTS gold;
USE gold;

-- ---------- Dimensiones ----------------------------------------------
DROP TABLE IF EXISTS dim_cliente;
CREATE TABLE dim_cliente STORED AS PARQUET AS
SELECT customer_id, customer_unique_id, codigo_postal, ciudad, estado
FROM silver.clientes;

DROP TABLE IF EXISTS dim_vendedor;
CREATE TABLE dim_vendedor STORED AS PARQUET AS
SELECT seller_id, codigo_postal, ciudad, estado
FROM silver.vendedores;

DROP TABLE IF EXISTS dim_producto;
CREATE TABLE dim_producto STORED AS PARQUET AS
SELECT product_id, categoria, categoria_en, num_fotos, peso_g, largo_cm, alto_cm, ancho_cm
FROM silver.productos;

-- Un dia por fila, solo los dias con compras.
DROP TABLE IF EXISTS dim_tiempo;
CREATE TABLE dim_tiempo STORED AS PARQUET AS
SELECT
    fecha,
    YEAR(fecha)                                   AS anio,
    QUARTER(fecha)                                AS trimestre,
    MONTH(fecha)                                  AS mes,
    DATE_FORMAT(fecha, 'yyyy-MM')                 AS anio_mes,
    DAY(fecha)                                    AS dia,
    DAYOFWEEK(fecha)                              AS dia_semana,   -- 1 = domingo
    DAYOFWEEK(fecha) IN (1, 7)                    AS fin_de_semana
FROM (SELECT DISTINCT fecha_compra AS fecha FROM silver.pedidos) d;

-- ---------- Hechos ---------------------------------------------------
-- Particionar por anio/mes permite que Hive lea solo los directorios
-- del periodo consultado (partition pruning).
DROP TABLE IF EXISTS fact_ventas;
CREATE TABLE fact_ventas (
    order_id        STRING,
    order_item_id   INT,
    customer_id     STRING,
    seller_id       STRING,
    product_id      STRING,
    fecha_compra    DATE,
    precio          DECIMAL(12,2),
    transporte      DECIMAL(12,2),
    importe_total   DECIMAL(12,2),
    dias_entrega    INT,
    con_retraso     BOOLEAN,
    puntuacion      INT
)
PARTITIONED BY (anio INT, mes INT)
STORED AS PARQUET;

SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;

INSERT OVERWRITE TABLE fact_ventas PARTITION (anio, mes)
SELECT
    order_id,
    order_item_id,
    customer_id,
    seller_id,
    product_id,
    fecha_compra,
    precio,
    transporte,
    precio + transporte,
    dias_entrega,
    con_retraso,
    puntuacion,
    YEAR(fecha_compra),
    MONTH(fecha_compra)
FROM silver.ventas;

-- ---------- Agregado para cuadros de mando ---------------------------
-- Grano: estado del cliente x categoria x mes.
DROP TABLE IF EXISTS ventas_mensuales;
CREATE TABLE ventas_mensuales STORED AS PARQUET AS
SELECT
    c.estado                    AS estado_cliente,
    p.categoria_en              AS categoria,
    t.anio,
    t.mes,
    COUNT(*)                    AS articulos_vendidos,
    COUNT(DISTINCT f.order_id)  AS pedidos,
    SUM(f.precio)               AS ingresos,
    ROUND(AVG(f.puntuacion), 2) AS puntuacion_media
FROM fact_ventas f
JOIN dim_cliente  c ON c.customer_id = f.customer_id
JOIN dim_producto p ON p.product_id  = f.product_id
JOIN dim_tiempo   t ON t.fecha       = f.fecha_compra
GROUP BY c.estado, p.categoria_en, t.anio, t.mes;

-- ---------- Comprobacion ---------------------------------------------
SHOW PARTITIONS fact_ventas;

SELECT 'fact_ventas' AS tabla, COUNT(*) AS filas FROM fact_ventas
UNION ALL SELECT 'dim_cliente',      COUNT(*) FROM dim_cliente
UNION ALL SELECT 'dim_vendedor',     COUNT(*) FROM dim_vendedor
UNION ALL SELECT 'dim_producto',     COUNT(*) FROM dim_producto
UNION ALL SELECT 'dim_tiempo',       COUNT(*) FROM dim_tiempo
UNION ALL SELECT 'ventas_mensuales', COUNT(*) FROM ventas_mensuales;
