#!/usr/bin/env bash
# Comprobaciones previas al primer arranque. No modifica ningun contenedor.
# Al final muestra los accesos (URL, usuarios y contrasenas de .env).
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/_comun.sh
fallos=0
ok()    { echo "OK      $1"; }
falta() { echo "FALTA   $1"; fallos=$((fallos + 1)); }

echo '== Docker'
comprobar_entorno
ok "docker en marcha ($(docker compose version --short 2>/dev/null || echo compose))"

echo '== Configuracion (.env)'
if [[ -f .env ]]; then
  ok ".env"
  if grep -q 'CAMBIAR' .env; then falta ".env todavia contiene valores CAMBIAR"; fi
  # Todas las variables de la plantilla deben existir en .env
  for var in $(grep -E '^[A-Z_]+=' .env.example | cut -d= -f1); do
    grep -qE "^${var}=." .env || falta ".env no define $var (ver .env.example)"
  done
else
  falta ".env (cp .env.example .env y rellenarlo)"
fi

echo '== Ficheros necesarios'
for f in drivers/postgresql-42.7.4.jar drivers/mariadb-java-client-3.4.1.jar \
         config/hue/hue.ini config/hue/hue-start.sh config/pgadmin/servers.json \
         filebrowser/config/settings.json \
         datasets/olist/olist_customers_dataset.csv datasets/olist/olist_sellers_dataset.csv \
         datasets/olist/olist_orders_dataset.csv datasets/olist/olist_order_items_dataset.csv \
         datasets/olist/olist_products_dataset.csv datasets/olist/olist_order_payments_dataset.csv \
         datasets/olist/olist_order_reviews_dataset.csv datasets/olist/product_category_name_translation.csv; do
  if [[ -f "$f" ]]; then ok "$f"; else falta "$f"; fi
done

echo '== Finales de linea (los scripts se ejecutan en Linux)'
# (se cuenta con tr: el grep de Git Bash no detecta '\r' de forma fiable)
crlf=''
for f in scripts/*.sh config/hue/hue-start.sh config/hue/hue.ini sql/hive/*.hql sql/fuentes/*.sql; do
  [[ $(tr -cd '\r' < "$f" | wc -c) -gt 0 ]] && crlf+=" $f"
done
if [[ -n "$crlf" ]]; then
  falta "ficheros con CRLF (clonar de nuevo o 'git add --renormalize .'): $(echo $crlf)"
else
  ok "scripts y configuracion en LF"
fi

echo '== Sintaxis de docker-compose.yml'
if docker compose config --quiet; then ok "docker-compose.yml"; else falta "docker-compose.yml"; fi

if [[ $fallos -gt 0 ]]; then
  echo
  echo "Preflight con $fallos problema(s). Corregir antes de 'docker compose up -d'."
  exit 1
fi
echo
echo 'Preflight correcto. No se ha modificado ningun contenedor.'
bash scripts/accesos.sh
