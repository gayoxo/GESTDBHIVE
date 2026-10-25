#!/usr/bin/env bash
# Fase 3: ejecuta los scripts HiveQL de sql/hive con beeline.
#   bash scripts/03_hive.sh                  -> todos, en orden
#   bash scripts/03_hive.sh 02_silver.hql    -> solo los indicados
# Las credenciales JDBC se pasan como hivevar desde .env.
set -euo pipefail
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1  # Git Bash en Windows: no reescribir rutas del contenedor

set -a; source <(tr -d '\r' < .env); set +a

if [ $# -eq 0 ]; then
  set -- $(cd sql/hive && ls [0-9]*.hql)
fi

for fichero in "$@"; do
  echo "===== $fichero"
  docker exec gesdb-hiveserver2 beeline -u jdbc:hive2://localhost:10000 -n hive \
    --silent=true --showHeader=true --outputformat=table \
    --hivevar reader_user="$OLIST_READER_USER" \
    --hivevar reader_password="$OLIST_READER_PASSWORD" \
    -f "/opt/gesdb/sql/hive/$(basename "$fichero")"
done
