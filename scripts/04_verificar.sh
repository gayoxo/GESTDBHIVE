#!/usr/bin/env bash
# Comprueba que cada capa tiene las filas esperadas y que las webs responden.
# No modifica nada. Devuelve 0 si todo es correcto.
set -uo pipefail
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1  # Git Bash en Windows: no reescribir rutas del contenedor
set -a; source <(tr -d '\r' < .env); set +a
docker info >/dev/null 2>&1 || { echo 'Docker no esta en marcha: arrancar Docker Desktop.'; exit 1; }

fallos=0
comprobar() {  # nombre, esperado, obtenido
  if [ "$3" = "$2" ]; then
    printf 'OK     %-32s %s\n' "$1" "$3"
  else
    printf 'FALLO  %-32s esperado %s, obtenido %s\n' "$1" "$2" "${3:-<sin respuesta>}"
    fallos=$((fallos + 1))
  fi
}

echo '== Fuentes operacionales'
for t in customers:99441 sellers:3095; do
  n=$(docker exec gesdb-mariadb-data sh -c "mariadb -N -uolist -p\"\$MARIADB_PASSWORD\" olist -e 'SELECT COUNT(*) FROM ${t%%:*}'" 2>/dev/null | tr -d '\r')
  comprobar "MariaDB ${t%%:*}" "${t##*:}" "$n"
done
for t in orders:99441 order_items:112650; do
  n=$(docker exec gesdb-postgres-data psql -tA -U olist -d olist -c "SELECT COUNT(*) FROM ${t%%:*}" 2>/dev/null | tr -d '\r')
  comprobar "PostgreSQL ${t%%:*}" "${t##*:}" "$n"
done

echo '== Hive'
declare -A esperado=(
  [bronze.clientes]=99441 [bronze.vendedores]=3095 [bronze.pedidos]=99441 [bronze.articulos]=112650
  [bronze.productos]=32951 [bronze.categorias]=71 [bronze.pagos]=103886 [bronze.resenas]=99224
  [silver.clientes]=99441 [silver.vendedores]=3095 [silver.productos]=32951 [silver.pedidos]=99441
  [silver.articulos]=112650 [silver.pagos_pedido]=99440 [silver.resenas]=98673 [silver.ventas]=110197
  [gold.fact_ventas]=110197 [gold.dim_cliente]=99441 [gold.dim_vendedor]=3095
  [gold.dim_producto]=32951 [gold.dim_tiempo]=634 [gold.ventas_mensuales]=11672
)
# Una sentencia por tabla en una sola sesion de beeline: un UNION ALL de
# muchas tablas supera el limite fijo de contadores de Tez (120) y falla.
consulta="SELECT 'gold.fact_ventas particiones', COUNT(DISTINCT anio, mes) FROM gold.fact_ventas;"
for t in "${!esperado[@]}"; do
  consulta+=" SELECT '$t', COUNT(*) FROM $t;"
done
salida=$(docker exec gesdb-hiveserver2 beeline -u jdbc:hive2://localhost:10000 -n hive \
  --silent=true --showHeader=false --outputformat=csv2 -e "$consulta" 2>/dev/null | tr -d '\r')
esperado['gold.fact_ventas particiones']=23
while IFS= read -r t; do
  n=$(printf '%s\n' "$salida" | awk -F, -v t="$t" '$1 == t {print $2}')
  comprobar "$t" "${esperado[$t]}" "$n"
done < <(printf '%s\n' "${!esperado[@]}" | sort)

echo '== Interfaces web'
codigo() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
comprobar 'Hue :8084'          302 "$(codigo http://127.0.0.1:8084/)"
comprobar 'pgAdmin :8082'      200 "$(codigo -L http://127.0.0.1:8082/)"
comprobar 'phpMyAdmin :8083'   200 "$(codigo http://127.0.0.1:8083/)"
comprobar 'File Browser login' 200 "$(codigo -X POST http://127.0.0.1:8085/api/login \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$FILEBROWSER_ADMIN_USER\",\"password\":\"$FILEBROWSER_ADMIN_PASSWORD\"}")"

echo
if [ $fallos -eq 0 ]; then
  echo 'Verificacion correcta: todas las capas y servicios responden como se espera.'
else
  echo "Verificacion con $fallos fallo(s)."
  exit 1
fi
