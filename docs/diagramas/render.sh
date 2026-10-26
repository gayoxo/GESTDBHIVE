#!/usr/bin/env bash
# Regenera los .svg de docs/diagramas a partir de los .puml
# (PlantUML en Docker, sin servidor). Uso: bash docs/diagramas/render.sh
set -euo pipefail
cd "$(dirname "$0")"
export MSYS_NO_PATHCONV=1   # Git Bash en Windows: no reescribir rutas del contenedor
DIR="$(pwd -W 2>/dev/null || pwd)"
docker run --rm -v "$DIR:/data" plantuml/plantuml:1.2024.7 -tsvg -failfast2 "/data/*.puml"
echo "SVG regenerados en docs/diagramas/"
