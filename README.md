# GESDB 2.0 — despliegue limpio (Hive 4 + Hue + fuentes Olist)

Este paquete es una **configuración nueva**, no una migración. No requiere los cuatro `EXISTING_*_VOLUME` anteriores. Utiliza **volúmenes Docker nuevos** con el proyecto `gesdb` y un warehouse local compartido. **No se ha probado el arranque en el servidor del usuario**.

## Servicios

| Web | URL desde el host Docker | Datos |
|---|---|---|
| Hue | http://localhost:8084 | HiveServer2 |
| pgAdmin | http://localhost:8082 | PostgreSQL empresarial `hive4-postgres2:5432` (BD `olist`, usuario `olist`) |
| phpMyAdmin | http://localhost:8083 | MariaDB `hive4-mariadb:3306` (BD `olist`, usuario `olist`) |
| File Browser | http://localhost:8085 | Archivos de `datasets/` |

PostgreSQL interno Metastore y PostgreSQL interno Hue tienen sus propios volúmenes. PostgreSQL de datos mantiene el nombre de servicio `hive4-postgres2` por continuidad, pero se inicializa desde cero. La base de datos de Hue NO es la de datos empresariales.

## 1. Preparación

1. Descomprimir el ZIP en una carpeta nueva (no sobre el proyecto antiguo).
2. `cp .env.example .env`; introducir contraseñas propias, sin subir `.env` a Git. Si ya definiste secretos, cópialos localmente: **no se han incluido en este ZIP**.
3. Copiar los dos drivers JDBC existentes a `drivers/postgresql-42.7.4.jar` y `drivers/mariadb-java-client-3.4.1.jar`. No se distribuyen JAR ajenos.
4. `mkdir -p warehouse datasets/olist filebrowser/database filebrowser/config`; garantizar permisos de escritura para File Browser (`id -u`, `id -g` y variables FILEBROWSER_UID/GID). En Linux, el usuario del contenedor Hive debe poder escribir en `warehouse`.
5. Comprobar que los puertos 8082, 8083, 8084, 8085, 5433, 3307, 10000, 10002 y 9083 no están ocupados. **Si el stack antiguo sigue funcionando, hay conflictos de puertos**: detener solo sus contenedores, sin borrar volúmenes (`docker compose down` sin `-v` desde el directorio antiguo), o usar otros puertos.
6. Ejecutar `bash scripts/preflight.sh`. No imprime las contraseñas, pero `docker compose config` sin `--quiet` sí podría hacerlo.

## 2. Arranque

```bash
docker compose --env-file .env up -d
docker compose --env-file .env ps
docker compose --env-file .env logs --tail=100 metastore hiveserver2 hue
```

El Metastore puede tardar en inicializar su esquema y HiveServer2 puede arrancar antes de estar listo. Si Hue falla inicialmente, revisar los logs y reiniciarlo una vez HiveServer2 esté operativo. Verificar Hue con `SHOW DATABASES;` y `sql/00_databases.hql`.

## 3. Bases de datos y gestores

- pgAdmin: registrar servidor `hive4-postgres2`, puerto `5432`, usuario `olist`, BD `olist` y contraseña `DATA_POSTGRES_PASSWORD`.
- phpMyAdmin: servidor ya preconfigurado `hive4-mariadb`, usuario `olist` y contraseña `MARIADB_USER_PASSWORD`.
- File Browser: gestionar `datasets/olist/`. Consultar los logs de la imagen para el proceso de creación/obtención de credenciales iniciales; cambiar inmediatamente la contraseña administrativa. El servicio web no crea tablas Hive por sí mismo.
- Hue: el archivo `config/hue/hue.ini` configura HiveServer2 y la BD de Hue. La interpolación de variables `${...}` en `hue.ini` depende de la versión de Hue; si falla la conexión, comprobar los logs y la configuración efectiva. El montaje del archivo completo sustituye la configuración de la imagen.

## 4. Dataset

Olist: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

Distribución propuesta: MariaDB (`customers`, `sellers`), PostgreSQL (`orders`, `order_items`), CSV (`products`, `reviews` y tablas complementarias). La importación y las tablas externas JDBC serán la siguiente fase. En Hive, `JdbcStorageHandler` sirve para consultas federadas y CTAS para materializar tablas en el warehouse. Las tablas CSV requieren un SerDe apropiado cuando hay comillas o comas internas.

## 5. Precauciones

- **Nunca** ejecutes `docker compose down -v` si quieres conservar las bases creadas con este proyecto. Los volúmenes nuevos son `gesdb_metastore_data`, `gesdb_postgres_data`, `gesdb_hue_data`, `gesdb_mariadb_data`, `gesdb_pgadmin_data`.
- Los puertos web se enlazan solo a `127.0.0.1`. Para servidor remoto usa túneles SSH o un proxy autenticado.
- Las imágenes de Hue, pgAdmin, phpMyAdmin y File Browser tienen etiquetas móviles; fijar versiones/digests tras comprobar el primer arranque. Hive está fijado en 4.0.1.
- Esta variante mantiene almacenamiento local para una demostración docente de un solo nodo. No es un clúster HDFS. Hive puede requerir configuración adicional del motor de ejecución y permisos de directorio para ciertas operaciones CTAS.
- El fichero `hive-site.xml` anterior no se monta porque contenía nombres de hosts contradictorios; la conexión Metastore se configura por `SERVICE_OPTS` en ambos servicios.
- La configuración de File Browser depende de la versión de imagen; si el contenedor requiere un fichero `settings.json` o una inicialización explícita, revisar sus logs antes de continuar.
