#!/usr/bin/env bash
# Fase 2: crea y carga las fuentes operacionales (MariaDB y PostgreSQL)
# y el usuario de solo lectura que utilizara Hive. Se puede repetir.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/_comun.sh && comprobar_entorno
export MSYS_NO_PATHCONV=1  # Git Bash en Windows: no reescribir rutas del contenedor

set -a; source <(tr -d '\r' < .env); set +a
: "${OLIST_READER_USER:?Falta OLIST_READER_USER en .env}"
: "${OLIST_READER_PASSWORD:?Falta OLIST_READER_PASSWORD en .env}"

echo '== MariaDB: customers, sellers'
docker exec -i gesdb-mariadb-data sh -c \
  'mariadb --local-infile=1 -uolist -p"$MARIADB_PASSWORD" olist' < sql/fuentes/mariadb_olist.sql

echo "== MariaDB: usuario de solo lectura ${OLIST_READER_USER}"
docker exec -i -e R_USER="$OLIST_READER_USER" -e R_PASS="$OLIST_READER_PASSWORD" gesdb-mariadb-data sh -c \
  'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" <<SQL
CREATE USER IF NOT EXISTS "$R_USER"@"%" IDENTIFIED BY "$R_PASS";
ALTER USER "$R_USER"@"%" IDENTIFIED BY "$R_PASS";
GRANT SELECT ON olist.* TO "$R_USER"@"%";
SQL'

echo '== PostgreSQL: orders, order_items y usuario de solo lectura'
docker exec gesdb-postgres-data psql -q -U olist -d olist \
  -v reader_user="$OLIST_READER_USER" -v reader_password="$OLIST_READER_PASSWORD" \
  -f /sql/postgres_olist.sql
