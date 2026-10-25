"""Prepara la fuente de ficheros que Hive lee como tablas externas.

datasets/olist/    -> CSV originales de Kaggle (no se modifican)
datasets/landing/  -> una carpeta por tabla (Hive lee directorios, no ficheros)

Las resenas tienen saltos de linea dentro de los comentarios, que un CSV de
texto en Hive no soporta: se publican como JSON Lines (un objeto por linea).
"""
import csv
import json
import shutil
import sys
from pathlib import Path

origen = Path(sys.argv[1])
destino = Path(sys.argv[2])

CSV_TAL_CUAL = {
    "productos": "olist_products_dataset.csv",
    "pagos": "olist_order_payments_dataset.csv",
    "categorias": "product_category_name_translation.csv",
}

for tabla, fichero in CSV_TAL_CUAL.items():
    carpeta = destino / tabla
    carpeta.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(origen / fichero, carpeta / fichero)
    print(f"{tabla:<11} <- {fichero}")

carpeta = destino / "resenas"
carpeta.mkdir(parents=True, exist_ok=True)
total = 0
with open(origen / "olist_order_reviews_dataset.csv", encoding="utf-8-sig", newline="") as f_in, \
        open(carpeta / "olist_order_reviews.jsonl", "w", encoding="utf-8", newline="\n") as f_out:
    for fila in csv.DictReader(f_in):
        # Campo vacio en el CSV -> null en JSON
        registro = {k: (v if v != "" else None) for k, v in fila.items()}
        f_out.write(json.dumps(registro, ensure_ascii=False) + "\n")
        total += 1
print(f"resenas     <- olist_order_reviews_dataset.csv ({total} registros, JSON Lines)")
