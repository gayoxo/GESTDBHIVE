# Dataset Olist: procedencia

Datos públicos del comercio electrónico brasileño **Olist** que usa la práctica. Los CSV de esta carpeta son los originales descargados, **sin modificar**.

| | |
|---|---|
| Nombre | Brazilian E-Commerce Public Dataset by Olist |
| Autor | Olist (<https://olist.com>), cuenta de Kaggle `olistbr` |
| Fuente | <https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce> |
| Licencia | CC BY-NC-SA 4.0 (atribución, no comercial, compartir igual), según la página de Kaggle |
| Contenido | ~100.000 pedidos reales anonimizados de 2016 a 2018 |
| Descargado | 25/10/2026 |

Cita sugerida:

> Olist. *Brazilian E-Commerce Public Dataset by Olist* [Data set]. Kaggle. <https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce>

## Ficheros

| Fichero | Registros | Bytes | SHA-256 (inicio) | Uso en la práctica |
|---|---|---|---|---|
| `olist_customers_dataset.csv` | 99.441 | 9.033.957 | `983a422239e1712d` | MariaDB `customers` |
| `olist_sellers_dataset.csv` | 3.095 | 174.703 | `1f643d2b950373b8` | MariaDB `sellers` |
| `olist_orders_dataset.csv` | 99.441 | 17.654.914 | `8df58ef3d2d7e994` | PostgreSQL `orders` |
| `olist_order_items_dataset.csv` | 112.650 | 15.438.671 | `0bc4d068c4fe38cb` | PostgreSQL `order_items` |
| `olist_products_dataset.csv` | 32.951 | 2.379.446 | `3e6569628a17fbc7` | Fichero: `bronze.productos` |
| `product_category_name_translation.csv` | 71 | 2.613 | `a81f0d1f27b27e72` | Fichero: `bronze.categorias` |
| `olist_order_payments_dataset.csv` | 103.886 | 5.777.138 | `4f713964f2815dbb` | Fichero: `bronze.pagos` |
| `olist_order_reviews_dataset.csv` | 99.224 | 14.451.670 | `012b61c7593e34f5` | Fichero JSON: `bronze.resenas` |
| `olist_geolocation_dataset.csv` | 1.000.163 | 61.273.883 | `b514f6fc991b9566` | Sin uso (ampliación) |

Para comprobar que un fichero no ha cambiado: `sha256sum <fichero>`.

## Notas

- Los registros no coinciden con las líneas en `olist_order_reviews_dataset.csv`: algunos comentarios contienen saltos de línea. Por eso la práctica convierte las reseñas a JSON Lines (`scripts/01_preparar_landing.sh`).
- `olist_order_reviews_dataset.csv` y `product_category_name_translation.csv` usan saltos de línea de Windows (CRLF); el resto, Unix (LF). La traducción incluye además un BOM UTF-8.
- Los nombres de columna `product_name_lenght` y `product_description_lenght` vienen así, con la errata, en el original.
- Si se vuelve a descargar de Kaggle, basta con descomprimir aquí los 9 CSV con los mismos nombres.
