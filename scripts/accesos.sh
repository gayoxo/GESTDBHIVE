#!/usr/bin/env bash
# Muestra las direcciones, usuarios y contrasenas del entorno (leidos de .env).
# ATENCION: imprime contrasenas en el terminal; no compartir la salida.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] || { echo 'No existe .env (cp .env.example .env y rellenarlo).'; exit 1; }
set -a; source <(tr -d '\r' < .env); set +a

cat <<EOF

===================== ACCESOS GESDB (valores de .env) =====================

 WEB (abrir en el navegador)
  Hue (HiveQL)     http://localhost:8084   usuario: ${HUE_ADMIN_USER:-admin}
                                           clave:   ${HUE_ADMIN_PASSWORD}
  pgAdmin          http://localhost:8082   usuario: ${PGADMIN_EMAIL}
                                           clave:   ${PGADMIN_PASSWORD}
     servidor ya registrado "GESDB > Olist (postgres-data)"; al abrirlo pide:
                                           clave de olist: ${DATA_POSTGRES_PASSWORD}
  phpMyAdmin       http://localhost:8083   usuario: olist
                                           clave:   ${MARIADB_USER_PASSWORD}
                                           (root:   ${MARIADB_ROOT_PASSWORD})
  File Browser     http://localhost:8085   usuario: ${FILEBROWSER_ADMIN_USER:-admin}
                                           clave:   ${FILEBROWSER_ADMIN_PASSWORD}

 CONEXIONES DESDE EL EQUIPO (DBeaver, VS Code...)
  PostgreSQL datos localhost:5433  BD olist  usuario olist  clave ${DATA_POSTGRES_PASSWORD}
  MariaDB          localhost:3307  BD olist  usuario olist  clave ${MARIADB_USER_PASSWORD}
  HiveServer2      jdbc:hive2://localhost:10000  usuario hive (sin clave)

 USUARIO DE SOLO LECTURA QUE USA HIVE (tablas JDBC de Bronze)
  ${OLIST_READER_USER} / ${OLIST_READER_PASSWORD}

 Estos datos salen de .env: para cambiarlos, editar .env.
===========================================================================
EOF
