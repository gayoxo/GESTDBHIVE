#!/usr/bin/env bash
# Prueba de despliegue limpio: BORRA todo lo generado por el proyecto y repite
# la practica completa desde cero, terminando con scripts/04_verificar.sh.
#   bash scripts/test_despliegue_limpio.sh --borrar-todo
set -euo pipefail
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1  # Git Bash en Windows: no reescribir rutas del contenedor

if [ "${1:-}" != "--borrar-todo" ]; then
  echo 'Uso: bash scripts/test_despliegue_limpio.sh --borrar-todo'
  echo 'ATENCION: elimina los volumenes del proyecto (Metastore, Hue, MariaDB, PostgreSQL, pgAdmin),'
  echo 'el warehouse de Hive, datasets/landing y la base de datos de File Browser.'
  exit 2
fi

inicio=$(date +%s)
paso() { echo; echo "##### $1  [$(( $(date +%s) - inicio ))s]"; }

paso '1/8 Bajar contenedores y volumenes'
docker compose down -v --remove-orphans

paso '2/8 Borrar datos generados'
rm -rf warehouse/*.db datasets/landing filebrowser/database/filebrowser.db

paso '3/8 Preflight'
bash scripts/preflight.sh

paso '4/8 Arrancar la infraestructura'
docker compose up -d

paso '5/8 Esperar a HiveServer2'
for i in $(seq 1 60); do
  if docker exec gesdb-hiveserver2 beeline -u jdbc:hive2://localhost:10000 -n hive \
       --silent=true -e 'SELECT 1;' >/dev/null 2>&1; then
    echo "HiveServer2 listo"; break
  fi
  if [ "$i" -eq 60 ]; then echo 'HiveServer2 no responde tras 10 minutos'; exit 1; fi
  sleep 10
done

paso '6/8 Preparar ficheros (landing)'
bash scripts/01_preparar_landing.sh

paso '7/8 Cargar fuentes operacionales'
bash scripts/02_cargar_fuentes.sh

paso '8/8 Hive: Bronze, Silver y Gold'
bash scripts/03_hive.sh 00_databases.hql 01_bronze.hql 02_silver.hql 03_gold.hql

paso 'Verificacion'
bash scripts/04_verificar.sh

echo
echo "Despliegue limpio correcto en $(( $(date +%s) - inicio )) segundos."
