# GESDB 2.0 — Data Warehouse con Apache Hive (Olist)

Práctica de integración de fuentes heterogéneas y construcción de un Data Warehouse con Apache Hive 4, siguiendo una arquitectura por capas **Bronze → Silver → Gold**.

> **Guía de la práctica paso a paso**: [docs/DESARROLLO.md](docs/DESARROLLO.md). Explica cada fase con diagramas, resultados esperados y las consultas finales resueltas. Este README es la referencia técnica rápida.

Se usa el dataset público [Brazilian E-Commerce by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce): unos 100.000 pedidos reales anonimizados (2016–2018), repartidos entre tres sistemas de origen:

| Fuente | Tecnología | Tablas |
|---|---|---|
| Sistema de clientes | MariaDB | `customers`, `sellers` |
| Sistema de pedidos | PostgreSQL | `orders`, `order_items` |
| Ficheros | CSV y JSON | productos, categorías, pagos, reseñas |

El modelo de datos del dataset está en [docs/diagramas/00_olist_modelo_datos.svg](docs/diagramas/00_olist_modelo_datos.svg) (fuente PlantUML en el `.puml` del mismo nombre).

```text
MariaDB ─┐
PostgreSQL ─┼──► Hive BRONZE ──► Hive SILVER ──► Hive GOLD ──► Consultas (Hue)
CSV / JSON ─┘    (externas,       (Parquet,        (estrella,
                  sin copiar)      limpio)          particionado)
```

## Servicios

| Servicio | URL | Uso | Credenciales (`.env`) |
|---|---|---|---|
| Hue | <http://localhost:8084> | Editor HiveQL | `HUE_ADMIN_USER` / `HUE_ADMIN_PASSWORD` |
| pgAdmin | <http://localhost:8082> | PostgreSQL de datos (servidor ya registrado) | `PGADMIN_EMAIL` / `PGADMIN_PASSWORD` |
| phpMyAdmin | <http://localhost:8083> | MariaDB | `olist` / `MARIADB_USER_PASSWORD` |
| File Browser | <http://localhost:8085> | Ficheros de `datasets/` | `FILEBROWSER_ADMIN_USER` / `FILEBROWSER_ADMIN_PASSWORD` |
| HiveServer2 | `localhost:10000` (JDBC), <http://localhost:10002> (web) | Motor Hive | — |

**Para ver todas las direcciones, usuarios y contraseñas** de tu entorno: `bash scripts/accesos.sh`. También se muestran al final del preflight.

Todos los puertos se publican solo en `127.0.0.1`. Hay además tres bases de datos internas que no se tocan: el PostgreSQL del Metastore, el PostgreSQL de Hue y el Metastore de Hive (`:9083`).

## Estructura del proyecto

```text
GESDB-2.0/
├── docker-compose.yml        # toda la infraestructura
├── .env                      # secretos y rutas (NO se sube a Git)
├── .env.example              # plantilla de .env
├── config/hue/hue.ini        # Hue -> HiveServer2 (sin secretos)
├── drivers/                  # JDBC de PostgreSQL y MariaDB para Hive (incluidos)
├── datasets/
│   ├── olist/                # los 9 CSV originales de Kaggle (incluidos, ver su README)
│   └── landing/              # (generado) una carpeta por tabla para Hive
├── sql/
│   ├── fuentes/              # creación y carga de MariaDB y PostgreSQL
│   └── hive/                 # 00_databases, 01_bronze, 02_silver, 03_gold, 04_consultas
├── scripts/                  # preflight, 01_preparar_landing, 02_cargar_fuentes, 03_hive
├── filebrowser/              # configuración de File Browser (su BD se genera)
└── warehouse/                # (generado) datos de Hive en Parquet
```

Lo marcado como *(generado)* y el fichero `.env` están en `.gitignore`: el proyecto se entrega vacío y cada alumno lo genera al seguir estos pasos.

---

## Paso 0. Requisitos

- Docker Desktop (en Windows con backend WSL2) y unos 8 GB de RAM libres.
- Un terminal **bash con acceso a Docker**. Todos los comandos se ejecutan desde la carpeta `GESDB-2.0`.
- Libres los puertos 8082–8085, 3307, 5433, 9083, 10000 y 10002.

> **Windows: usar Git Bash, no PowerShell.** En PowerShell, `bash` abre el bash de **WSL** (Linux), que normalmente no tiene Docker: el preflight falla con "se esta ejecutando el bash de WSL". Opciones:
>
> - **VS Code** (recomendado): abrir la carpeta del proyecto y *Terminal → Nuevo terminal*. El proyecto trae `.vscode/settings.json`, que abre **Git Bash** por defecto.
> - **Desde PowerShell**: `& "C:\Program Files\Git\bin\bash.exe" scripts/preflight.sh`
> - Abrir **Git Bash** desde el menú Inicio y hacer `cd` a la carpeta.

Los drivers JDBC ([drivers/README.md](drivers/README.md)) y los 9 CSV de Olist ([datasets/olist/README.md](datasets/olist/README.md)) ya vienen incluidos en el proyecto.

## Paso 1. Configurar `.env`

```bash
cp .env.example .env
```

Editar `.env` y sustituir todos los `CAMBIAR`:

| Variable | Para qué sirve |
|---|---|
| `METASTORE_PASSWORD` | PostgreSQL interno del Metastore |
| `DATA_POSTGRES_PASSWORD` | Usuario `olist` del PostgreSQL de datos |
| `HUE_POSTGRES_PASSWORD` | PostgreSQL interno de Hue |
| `MARIADB_ROOT_PASSWORD`, `MARIADB_USER_PASSWORD` | MariaDB: `root` y usuario `olist` |
| `OLIST_READER_USER`, `OLIST_READER_PASSWORD` | Usuario de **solo lectura** con el que Hive lee MariaDB y PostgreSQL |
| `PGADMIN_EMAIL`, `PGADMIN_PASSWORD` | Acceso a pgAdmin |
| `HUE_SECRET_KEY` | Clave interna de Hue (cadena aleatoria larga) |
| `HUE_ADMIN_USER`, `HUE_ADMIN_PASSWORD` | Acceso a Hue (el administrador se crea solo al arrancar) |
| `FILEBROWSER_ADMIN_USER`, `FILEBROWSER_ADMIN_PASSWORD` | Acceso a File Browser (mínimo **12** caracteres) |

> Las contraseñas de las bases de datos se fijan **la primera vez** que se crean sus volúmenes. Cambiarlas después en `.env` no cambia la base de datos: hay que empezar de cero (ver [Empezar de cero](#empezar-de-cero)). Las de Hue (administrador), File Browser y la del usuario lector sí se pueden cambiar en cualquier momento; se vuelven a aplicar con `docker compose up -d` o, la del lector, con el paso 4.

## Paso 2. Levantar la infraestructura

```bash
bash scripts/preflight.sh     # comprueba Docker, .env, ficheros y finales de línea; muestra los accesos
docker compose up -d
docker compose ps
```

Si el preflight indica algún `FALTA` o `ERROR`, el propio mensaje explica cómo corregirlo. Si termina bien, imprime la tabla de accesos (URL, usuario y contraseña de cada web).

Deben aparecer 10 contenedores en marcha (`gesdb-*`). El servicio `gesdb-filebrowser-init` aparece como `Exited (0)`, que es lo correcto: solo prepara el usuario de File Browser y termina.

El primer arranque del Metastore crea su esquema y tarda **1–2 minutos**. HiveServer2 está listo cuando responde:

```bash
docker exec gesdb-hiveserver2 beeline -u jdbc:hive2://localhost:10000 -n hive -e "SHOW DATABASES;"
```

Comprobaciones rápidas:

1. Abrir Hue (<http://localhost:8084>) con `HUE_ADMIN_USER` / `HUE_ADMIN_PASSWORD`. El servidor web de Hue tarda unos segundos más que el contenedor en estar listo.
2. En el editor **Hive** de Hue, ejecutar `SHOW DATABASES;`. Debe aparecer `default`.

## Paso 3. Preparar los ficheros (`landing`)

```bash
bash scripts/01_preparar_landing.sh
```

Crea `datasets/landing/` con una carpeta por tabla, porque Hive lee **carpetas**, no ficheros sueltos. Los CSV originales de `datasets/olist/` no se modifican.

| Carpeta | Contenido |
|---|---|
| `landing/productos/` | CSV de productos |
| `landing/categorias/` | CSV de traducción de categorías |
| `landing/pagos/` | CSV de pagos |
| `landing/resenas/` | Reseñas convertidas a **JSON Lines** (sus comentarios contienen saltos de línea, que un CSV de texto en Hive no soporta) |

Se ejecuta en un contenedor Python efímero: no hace falta Python en el equipo.

## Paso 4. Cargar las fuentes operacionales

```bash
bash scripts/02_cargar_fuentes.sh
```

Salida esperada:

```text
customers 99441 · sellers 3095            (MariaDB)
orders 99441 · order_items 112650         (PostgreSQL)
```

El script crea las tablas, carga los CSV (`LOAD DATA` en MariaDB y `COPY` en PostgreSQL) y crea en ambas el usuario de solo lectura `OLIST_READER_USER`. Se puede repetir: vacía y recarga las tablas. Los datos se pueden revisar en phpMyAdmin y pgAdmin.

En pgAdmin el servidor ya aparece registrado como **GESDB → Olist (postgres-data)**. Al abrirlo pide la contraseña de `olist` (`DATA_POSTGRES_PASSWORD`); se puede marcar *Save password*. Si no aparece es porque el volumen de pgAdmin se creó antes de esta configuración: ver [Solución de problemas](#solución-de-problemas).

## Paso 5. Hive: Bronze, Silver y Gold

Se puede ejecutar todo de una vez:

```bash
bash scripts/03_hive.sh
```

O capa a capa, que es lo recomendable en clase:

```bash
bash scripts/03_hive.sh 00_databases.hql   # bases bronze, silver y gold
bash scripts/03_hive.sh 01_bronze.hql      # ~1,5 min
bash scripts/03_hive.sh 02_silver.hql      # ~2 min
bash scripts/03_hive.sh 03_gold.hql        # ~4 min
bash scripts/03_hive.sh 04_consultas.hql   # ~1,5 min
```

El script lanza `beeline` dentro de HiveServer2 y le pasa las credenciales del usuario lector desde `.env` (`--hivevar`). Por eso los ficheros `.hql` no contienen contraseñas. Al final de cada ejecución aparece `No such file or directory`: es inofensivo, porque beeline intenta guardar su historial en un directorio que no existe en el contenedor.

### 5.1 Bronze: las fuentes, tal cual

Tablas **externas** que no copian datos: Hive lee directamente de cada sistema (*schema-on-read*).

| Tabla | Origen | Mecanismo | Filas |
|---|---|---|---|
| `bronze.clientes` | MariaDB `customers` | JdbcStorageHandler | 99.441 |
| `bronze.vendedores` | MariaDB `sellers` | JdbcStorageHandler | 3.095 |
| `bronze.pedidos` | PostgreSQL `orders` | JdbcStorageHandler | 99.441 |
| `bronze.articulos` | PostgreSQL `order_items` | JdbcStorageHandler | 112.650 |
| `bronze.productos` | `landing/productos` | OpenCSVSerde | 32.951 |
| `bronze.categorias` | `landing/categorias` | OpenCSVSerde | 71 |
| `bronze.pagos` | `landing/pagos` | OpenCSVSerde | 103.886 |
| `bronze.resenas` | `landing/resenas` | JsonSerDe | 99.224 |

### 5.2 Silver: limpio, tipado e integrado

Tablas **materializadas en Parquet** dentro de `warehouse/silver.db`: tipos correctos, nulos tratados, ciudades normalizadas, reseñas deduplicadas y pagos agregados por pedido.

| Tabla | Grano (qué es una fila) | Filas |
|---|---|---|
| `silver.clientes` | un `customer_id` | 99.441 |
| `silver.vendedores` | un vendedor | 3.095 |
| `silver.productos` | un producto (con categoría en inglés) | 32.951 |
| `silver.pedidos` | un pedido (con días de entrega y retraso) | 99.441 |
| `silver.articulos` | una línea de pedido | 112.650 |
| `silver.pagos_pedido` | un pedido | 99.440 |
| `silver.resenas` | un pedido (última reseña) | 98.673 |
| `silver.ventas` | un artículo de un pedido **entregado** | 110.197 |

### 5.3 Gold: modelo en estrella

| Tabla | Tipo | Filas |
|---|---|---|
| `gold.fact_ventas` | Hechos, particionada por `anio`/`mes` (23 particiones) | 110.197 |
| `gold.dim_cliente` | Dimensión | 99.441 |
| `gold.dim_vendedor` | Dimensión | 3.095 |
| `gold.dim_producto` | Dimensión | 32.951 |
| `gold.dim_tiempo` | Dimensión (un día por fila) | 634 |
| `gold.ventas_mensuales` | Agregado estado × categoría × mes | 11.672 |

### 5.4 Consultas de negocio

[sql/hive/04_consultas.hql](sql/hive/04_consultas.hql) contiene 9 consultas pensadas para ejecutarse **una a una en Hue**: ingresos por estado, categoría y mes, efecto del retraso en la valoración, la trampa de granularidad, el *partition pruning* y la consulta federada a PostgreSQL.

## Paso 6. Verificar

```bash
bash scripts/04_verificar.sh
```

Comprueba, sin modificar nada, que las fuentes y las 22 tablas de Hive tienen las filas esperadas, que `fact_ventas` tiene sus 23 particiones y que las cuatro webs responden. Termina con `Verificacion correcta` o indica qué tabla o servicio falla.

---

## Operación diaria

```bash
docker compose stop        # parar sin perder nada
docker compose start       # volver a arrancar
docker compose logs --tail=100 hiveserver2 hue
```

### Empezar de cero

Borra **todas** las bases de datos y metadatos del proyecto:

```bash
docker compose down -v                  # contenedores + volúmenes (Metastore, Hue, MariaDB, PostgreSQL, pgAdmin)
rm -rf warehouse/*.db datasets/landing filebrowser/database/filebrowser.db   # todo lo generado
docker compose up -d                    # y repetir desde el paso 2
```

`datasets/olist/`, `drivers/` y `.env` no se tocan.

## Solución de problemas

| Síntoma | Causa y solución |
|---|---|
| Hue no abre y en el log aparece `password authentication failed for user "hue"` | La BD de Hue se creó con otra contraseña. `HUE_POSTGRES_PASSWORD` debe ser la del primer arranque, o empezar de cero. |
| File Browser no acepta la contraseña | Debe tener ≥ 12 caracteres. Revisar `docker compose logs filebrowser-init`. |
| `beeline` no conecta justo después de arrancar | HiveServer2 todavía arranca. Esperar 1–2 minutos. |
| `ERROR: se esta ejecutando el bash de WSL` | Se ha lanzado `bash scripts/...` desde PowerShell. Usar Git Bash (ver [Paso 0](#paso-0-requisitos)). |
| `FALTA ficheros con CRLF` | El clon convirtió los finales de línea. Volver a clonar el repositorio (incluye `.gitattributes`). |
| `FALTA .env no define ...` | Falta una variable nueva de `.env.example` en tu `.env`: copiarla y darle valor. |
| pgAdmin no muestra el servidor "Olist (postgres-data)" | El volumen de pgAdmin es anterior a `servers.json`. Ejecutar `MSYS_NO_PATHCONV=1 docker exec gesdb-pgadmin /venv/bin/python3 /pgadmin4/setup.py load-servers /pgadmin4/servers.json --user TU_PGADMIN_EMAIL` |
| En Git Bash aparecen rutas como `C:/Program Files/Git/...` | Conversión automática de rutas de Git Bash. Los scripts ya exportan `MSYS_NO_PATHCONV=1`; para comandos manuales, hacer lo mismo. |
| `02_cargar_fuentes.sh` carga 0 filas | Los CSV no están en `datasets/olist/` o se han modificado (finales de línea). Descargar de nuevo. |

## Notas de seguridad

- `.env` contiene todos los secretos y está en `.gitignore`. Ningún otro fichero del proyecto los contiene.
- Hive guarda la contraseña del usuario lector en el Metastore (visible con `SHOW CREATE TABLE` en las tablas JDBC). Por eso es un usuario **de solo lectura**.
- File Browser dejó de mantenerse en septiembre de 2026 (archivado, sin parches de seguridad). Usarlo solo en local.
- Las imágenes de Hue, pgAdmin, phpMyAdmin y File Browser usan `latest`: conviene fijar versiones una vez validado el entorno. Hive está fijado en 4.0.1.
