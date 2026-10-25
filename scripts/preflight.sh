#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo '== Compose version =='; docker compose version
echo '== Existing conflicting containers =='; docker ps -a --format '{{.Names}}' | grep -E '^(hive4-|hue$|hue-postgres$|metastore$|hiveserver2$|pgadmin-hive4$)' || true
echo '== Required files =='
for f in drivers/postgresql-42.7.4.jar drivers/mariadb-java-client-3.4.1.jar config/hue/hue.ini; do
  if [[ -f "$f" ]]; then echo "OK $f"; else echo "MISSING $f"; fi
done
echo '== Compose validation =='
docker compose --env-file .env config --quiet
echo 'Preflight finished. No containers changed.'
