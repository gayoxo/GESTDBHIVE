#!/usr/bin/env bash
# Comprobaciones previas al primer arranque. No modifica ningun contenedor.
set -euo pipefail
cd "$(dirname "$0")/.."
fallos=0
ok()    { echo "OK      $1"; }
falta() { echo "FALTA   $1"; fallos=$((fallos + 1)); }

echo '== Docker'
docker compose version

echo '== Configuracion'
if [[ -f .env ]]; then
  ok ".env"
  if grep -q 'CAMBIAR' .env; then falta ".env todavia contiene valores CAMBIAR"; fi
else
  falta ".env (cp .env.example .env y rellenarlo)"
fi

echo '== Ficheros necesarios'
for f in drivers/postgresql-42.7.4.jar drivers/mariadb-java-client-3.4.1.jar config/hue/hue.ini \
         filebrowser/config/settings.json \
         datasets/olist/olist_customers_dataset.csv datasets/olist/olist_sellers_dataset.csv \
         datasets/olist/olist_orders_dataset.csv datasets/olist/olist_order_items_dataset.csv \
         datasets/olist/olist_products_dataset.csv datasets/olist/olist_order_payments_dataset.csv \
         datasets/olist/olist_order_reviews_dataset.csv datasets/olist/product_category_name_translation.csv; do
  if [[ -f "$f" ]]; then ok "$f"; else falta "$f"; fi
done

echo '== Sintaxis de docker-compose.yml'
docker compose config --quiet && ok "docker-compose.yml"

if [[ $fallos -gt 0 ]]; then
  echo "Preflight con $fallos problema(s). Corregir antes de 'docker compose up -d'."
  exit 1
fi
echo 'Preflight correcto. No se ha modificado ningun contenedor.'
