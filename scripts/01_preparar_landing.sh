#!/usr/bin/env bash
# Fase 1: organiza los CSV de Kaggle en datasets/landing/<tabla>/ para Hive.
# Usa un contenedor Python efimero: no hace falta Python en el equipo.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/_comun.sh && comprobar_entorno

ROOT="$(pwd -W 2>/dev/null || pwd)"
MSYS_NO_PATHCONV=1 docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$ROOT/datasets:/datasets" \
  -v "$ROOT/scripts/preparar_landing.py:/app/preparar_landing.py:ro" \
  python:3.12-slim python -I /app/preparar_landing.py /datasets/olist /datasets/landing
