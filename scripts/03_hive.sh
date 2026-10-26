#!/usr/bin/env bash
# Fase 3: ejecuta los scripts HiveQL de sql/hive con beeline.
#   bash scripts/03_hive.sh                  -> todos, en orden
#   bash scripts/03_hive.sh 02_silver.hql    -> solo los indicados
# Las credenciales JDBC se pasan como hivevar desde .env.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/_comun.sh && comprobar_entorno
export MSYS_NO_PATHCONV=1  # Git Bash en Windows: no reescribir rutas del contenedor

set -a; source <(tr -d '\r' < .env); set +a

if [ $# -eq 0 ]; then
  set -- $(cd sql/hive && ls [0-9]*.hql)
fi

for fichero in "$@"; do
  echo "===== $fichero"
  # user.home=/tmp: la imagen no tiene /home/hive (beeline guarda ahi su historial).
  # Se filtran los avisos SLF4J y las lineas en blanco del modo silencioso;
  # los errores de beeline se siguen mostrando y paran el script (pipefail).
  docker exec -e HADOOP_CLIENT_OPTS=-Duser.home=/tmp gesdb-hiveserver2 beeline -u jdbc:hive2://localhost:10000 -n hive \
    --silent=true --showHeader=true --outputformat=table \
    --hivevar reader_user="$OLIST_READER_USER" \
    --hivevar reader_password="$OLIST_READER_PASSWORD" \
    -f "/opt/gesdb/sql/hive/$(basename "$fichero")" 2>&1 \
    | { grep -v -e '^SLF4J:' -e '^[[:space:]]*$' || true; }
done
