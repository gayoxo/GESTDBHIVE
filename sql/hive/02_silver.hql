-- =====================================================================
-- SILVER: datos tipados, limpios e integrados, materializados en Hive
-- (Parquet). Aqui ocurre la "T" del ELT: todo con HiveQL.
-- Cada tabla deja explicita su granularidad (que representa una fila).
-- =====================================================================
CREATE DATABASE IF NOT EXISTS silver;
USE silver;

-- Cliente "de pedido": Olist genera un customer_id por pedido; la persona
-- real es customer_unique_id. Grano: un customer_id.
DROP TABLE IF EXISTS clientes;
CREATE TABLE clientes STORED AS PARQUET AS
SELECT
    customer_id,
    customer_unique_id,
    LPAD(customer_zip_code_prefix, 5, '0')    AS codigo_postal,
    UPPER(TRIM(customer_city))                AS ciudad,
    UPPER(TRIM(customer_state))               AS estado
FROM bronze.clientes;

-- Algunas ciudades vienen como "novo hamburgo, rio grande do sul, brasil":
-- nos quedamos con la parte anterior a la primera coma. Grano: un vendedor.
DROP TABLE IF EXISTS vendedores;
CREATE TABLE vendedores STORED AS PARQUET AS
SELECT
    seller_id,
    LPAD(seller_zip_code_prefix, 5, '0')      AS codigo_postal,
    UPPER(TRIM(SPLIT(seller_city, ',')[0]))   AS ciudad,
    UPPER(TRIM(seller_state))                 AS estado
FROM bronze.vendedores;

-- CSV: los vacios llegan como '' (no NULL) y todo es STRING.
-- Se traduce la categoria; si no hay traduccion se conserva la original.
-- Grano: un producto.
DROP TABLE IF EXISTS productos;
CREATE TABLE productos STORED AS PARQUET AS
SELECT
    p.product_id,
    COALESCE(NULLIF(p.product_category_name, ''), 'sin_categoria')        AS categoria,
    COALESCE(c.product_category_name_english,
             NULLIF(p.product_category_name, ''), 'unknown')              AS categoria_en,
    CAST(NULLIF(p.product_photos_qty, '') AS INT)                         AS num_fotos,
    CAST(NULLIF(p.product_weight_g,   '') AS INT)                         AS peso_g,
    CAST(NULLIF(p.product_length_cm,  '') AS INT)                         AS largo_cm,
    CAST(NULLIF(p.product_height_cm,  '') AS INT)                         AS alto_cm,
    CAST(NULLIF(p.product_width_cm,   '') AS INT)                         AS ancho_cm
FROM bronze.productos p
LEFT JOIN bronze.categorias c
    ON p.product_category_name = c.product_category_name;

-- Grano: un pedido. Se derivan metricas de entrega.
DROP TABLE IF EXISTS pedidos;
CREATE TABLE pedidos STORED AS PARQUET AS
SELECT
    order_id,
    customer_id,
    order_status                                   AS estado,
    order_purchase_timestamp                       AS fecha_hora_compra,
    TO_DATE(order_purchase_timestamp)              AS fecha_compra,
    order_approved_at                              AS fecha_aprobacion,
    order_delivered_carrier_date                   AS fecha_envio,
    order_delivered_customer_date                  AS fecha_entrega,
    TO_DATE(order_estimated_delivery_date)         AS fecha_entrega_estimada,
    DATEDIFF(order_delivered_customer_date, order_purchase_timestamp) AS dias_entrega,
    CASE
        WHEN order_delivered_customer_date IS NULL THEN NULL
        WHEN TO_DATE(order_delivered_customer_date) > TO_DATE(order_estimated_delivery_date) THEN TRUE
        ELSE FALSE
    END                                            AS con_retraso
FROM bronze.pedidos;

-- Grano: una linea de pedido (articulo vendido).
DROP TABLE IF EXISTS articulos;
CREATE TABLE articulos STORED AS PARQUET AS
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date AS fecha_limite_envio,
    price               AS precio,
    freight_value       AS transporte
FROM bronze.articulos;

-- Un pedido puede tener varios pagos (tarjeta + cupon...). Se agregan a
-- grano pedido para poder unirlos con otras tablas sin duplicar importes.
DROP TABLE IF EXISTS pagos_pedido;
CREATE TABLE pagos_pedido STORED AS PARQUET AS
SELECT
    order_id,
    COUNT(*)                                                    AS num_pagos,
    SUM(CAST(payment_value AS DECIMAL(12,2)))                   AS importe_pagado,
    MAX(CAST(payment_installments AS INT))                      AS max_cuotas,
    CONCAT_WS(',', SORT_ARRAY(COLLECT_SET(payment_type)))       AS medios_pago
FROM bronze.pagos
GROUP BY order_id;

-- Hay pedidos con varias resenas: se conserva la ultima respondida.
-- Los comentarios traen saltos de linea: se sustituyen por espacios.
-- Grano: un pedido.
DROP TABLE IF EXISTS resenas;
CREATE TABLE resenas STORED AS PARQUET AS
SELECT
    order_id,
    review_id,
    puntuacion,
    titulo,
    comentario,
    fecha_resena
FROM (
    SELECT
        order_id,
        review_id,
        CAST(review_score AS INT)                                        AS puntuacion,
        TRIM(review_comment_title)                                       AS titulo,
        TRIM(REGEXP_REPLACE(review_comment_message, '[\\r\\n]+', ' '))   AS comentario,
        CAST(review_creation_date AS TIMESTAMP)                          AS fecha_resena,
        ROW_NUMBER() OVER (PARTITION BY order_id
                           ORDER BY CAST(review_answer_timestamp AS TIMESTAMP) DESC) AS rn
    FROM bronze.resenas
) r
WHERE rn = 1;

-- Tabla integrada: cruza las tres fuentes. Grano: un articulo vendido
-- en un pedido entregado.
DROP TABLE IF EXISTS ventas;
CREATE TABLE ventas STORED AS PARQUET AS
SELECT
    a.order_id,
    a.order_item_id,
    p.customer_id,
    c.customer_unique_id,
    c.estado          AS estado_cliente,
    c.ciudad          AS ciudad_cliente,
    a.seller_id,
    v.estado          AS estado_vendedor,
    a.product_id,
    pr.categoria,
    pr.categoria_en,
    p.fecha_compra,
    p.dias_entrega,
    p.con_retraso,
    a.precio,
    a.transporte,
    r.puntuacion
FROM pedidos p
JOIN articulos a        ON a.order_id    = p.order_id
JOIN clientes c         ON c.customer_id = p.customer_id
JOIN vendedores v       ON v.seller_id   = a.seller_id
LEFT JOIN productos pr  ON pr.product_id = a.product_id
LEFT JOIN resenas r     ON r.order_id    = p.order_id
WHERE p.estado = 'delivered';

-- ---------- Comprobacion ---------------------------------------------
SELECT 'clientes' AS tabla, COUNT(*) AS filas FROM clientes
UNION ALL SELECT 'vendedores',   COUNT(*) FROM vendedores
UNION ALL SELECT 'productos',    COUNT(*) FROM productos
UNION ALL SELECT 'pedidos',      COUNT(*) FROM pedidos
UNION ALL SELECT 'articulos',    COUNT(*) FROM articulos
UNION ALL SELECT 'pagos_pedido', COUNT(*) FROM pagos_pedido
UNION ALL SELECT 'resenas',      COUNT(*) FROM resenas
UNION ALL SELECT 'ventas',       COUNT(*) FROM ventas;
