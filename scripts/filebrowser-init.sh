#!/bin/sh
# Crea o actualiza el administrador de File Browser con ADMIN_USER / ADMIN_PASSWORD
set -eu
DB=/database/filebrowser.db
CFG=/config/settings.json

if [ ! -f "$DB" ]; then
  filebrowser -c "$CFG" -d "$DB" config init
fi

if filebrowser -d "$DB" users find "$ADMIN_USER" >/dev/null 2>&1; then
  filebrowser -d "$DB" users update "$ADMIN_USER" --password "$ADMIN_PASSWORD" --perm.admin
  echo "Usuario '$ADMIN_USER' actualizado"
else
  filebrowser -d "$DB" users add "$ADMIN_USER" "$ADMIN_PASSWORD" --perm.admin
  echo "Usuario '$ADMIN_USER' creado"
fi
