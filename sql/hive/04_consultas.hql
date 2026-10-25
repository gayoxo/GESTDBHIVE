-- =====================================================================
-- CONSULTAS DE NEGOCIO sobre el modelo Gold (y algunas comparativas)
-- Pensadas para ejecutarse una a una en Hue.
-- =====================================================================

-- 1. La pregunta que justifica todo el ejercicio:
--    que categorias generan mas ingresos en cada estado y mes (2018).
--    Necesita clientes (MariaDB), pedidos y articulos (PostgreSQL)
--    y productos (CSV) ya integrados.
SELECT
    c.estado         AS estado_cliente,
    p.categoria_en   AS categoria,
    f.anio,
    f.mes,
    COUNT(*)         AS articulos_vendidos,
    SUM(f.precio)    AS ingresos
FROM gold.fact_ventas f
JOIN gold.dim_cliente  c ON c.customer_id = f.customer_id
JOIN gold.dim_producto p ON p.product_id  = f.product_id
WHERE f.anio = 2018
GROUP BY c.estado, p.categoria_en, f.anio, f.mes
ORDER BY ingresos DESC
LIMIT 20;

-- 2. Top 10 categorias: ingresos, ticket medio y satisfaccion.
SELECT
    p.categoria_en                  AS categoria,
    COUNT(DISTINCT f.order_id)      AS pedidos,
    SUM(f.precio)                   AS ingresos,
    ROUND(AVG(f.precio), 2)         AS precio_medio,
    ROUND(AVG(f.puntuacion), 2)     AS puntuacion_media
FROM gold.fact_ventas f
JOIN gold.dim_producto p ON p.product_id = f.product_id
GROUP BY p.categoria_en
ORDER BY ingresos DESC
LIMIT 10;

-- 3. Logistica: el retraso en la entrega hunde la valoracion.
SELECT
    CASE WHEN con_retraso THEN 'con retraso' ELSE 'a tiempo' END AS entrega,
    COUNT(*)                        AS articulos,
    ROUND(AVG(dias_entrega), 1)     AS dias_medios,
    ROUND(AVG(puntuacion), 2)       AS puntuacion_media
FROM gold.fact_ventas
GROUP BY CASE WHEN con_retraso THEN 'con retraso' ELSE 'a tiempo' END;

-- 4. Rutas: ventas entre estados (vendedor -> cliente).
SELECT
    v.estado        AS estado_vendedor,
    c.estado        AS estado_cliente,
    COUNT(*)        AS articulos,
    ROUND(AVG(f.dias_entrega), 1) AS dias_medios
FROM gold.fact_ventas f
JOIN gold.dim_vendedor v ON v.seller_id   = f.seller_id
JOIN gold.dim_cliente  c ON c.customer_id = f.customer_id
GROUP BY v.estado, c.estado
ORDER BY articulos DESC
LIMIT 10;

-- 5. Evolucion mensual de la facturacion (usa la dimension tiempo).
SELECT t.anio_mes, SUM(f.importe_total) AS facturacion, COUNT(DISTINCT f.order_id) AS pedidos
FROM gold.fact_ventas f
JOIN gold.dim_tiempo t ON t.fecha = f.fecha_compra
GROUP BY t.anio_mes
ORDER BY t.anio_mes;

-- 6. Clave de negocio: customer_id NO es la persona. Cuantos clientes
--    reales (customer_unique_id) repiten compra?
SELECT
    pedidos_por_cliente,
    COUNT(*) AS clientes
FROM (
    SELECT c.customer_unique_id, COUNT(DISTINCT f.order_id) AS pedidos_por_cliente
    FROM gold.fact_ventas f
    JOIN gold.dim_cliente c ON c.customer_id = f.customer_id
    GROUP BY c.customer_unique_id
) x
GROUP BY pedidos_por_cliente
ORDER BY pedidos_por_cliente;

-- 7. TRAMPA DE GRANULARIDAD: unir articulos (grano linea) con pagos
--    (grano pago) multiplica filas y falsea los importes.
SELECT 'MAL: articulos x pagos sin agregar' AS calculo,
       SUM(CAST(pg.payment_value AS DECIMAL(12,2))) AS importe
FROM silver.articulos a
JOIN bronze.pagos pg ON pg.order_id = a.order_id
UNION ALL
SELECT 'BIEN: pagos agregados por pedido',
       SUM(importe_pagado)
FROM silver.pagos_pedido;

-- 8. Particionado: Hive solo lee la particion anio=2018/mes=5.
--    Buscar en el plan "partition" / numero de particiones leidas.
EXPLAIN DEPENDENCY
SELECT SUM(precio) FROM gold.fact_ventas WHERE anio = 2018 AND mes = 5;

SELECT SUM(precio) AS ingresos_mayo_2018
FROM gold.fact_ventas
WHERE anio = 2018 AND mes = 5;

-- 9. Federacion: consulta directa a PostgreSQL desde Hive. El filtro se
--    empuja a la fuente (ver hive.sql.query en el plan).
EXPLAIN
SELECT order_status, COUNT(*) FROM bronze.pedidos
WHERE order_purchase_timestamp >= '2018-01-01'
GROUP BY order_status;

SELECT order_status, COUNT(*) AS pedidos
FROM bronze.pedidos
WHERE order_purchase_timestamp >= '2018-01-01'
GROUP BY order_status;
