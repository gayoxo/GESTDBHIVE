# Drivers JDBC

Hive los usa para leer las fuentes (tablas externas `JdbcStorageHandler`) y el Metastore para su base de datos PostgreSQL. `docker-compose.yml` los monta en `/opt/hive/lib`.

| Fichero | Origen (Maven Central) | Licencia |
|---|---|---|
| `postgresql-42.7.4.jar` | <https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.4/> | BSD-2-Clause |
| `mariadb-java-client-3.4.1.jar` | <https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/3.4.1/> | LGPL-2.1 |

Ambos ficheros coinciden con el SHA-1 publicado en Maven Central (comprobado el 25/10/2026).
