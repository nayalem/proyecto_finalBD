import argparse
import csv
import sqlite3
from pathlib import Path

from app_paths import DB_PATH, TXT_SEED_PATH


NULL_TOKEN = r"\N"
SEPARADOR = "|"

ORDEN_BORRADO = [
    "comprobante",
    "gasto",
    "detalle_movimiento",
    "inventario",
    "participacion",
    "partida_presupuestal",
    "movimiento",
    "donacion",
    "actividad",
    "presupuesto",
    "proyecto",
    "almacen",
    "recurso",
    "proveedor",
    "voluntario",
    "donante",
    "organizacion",
]


def convertir(valor):
    return None if valor == NULL_TOKEN else valor


def leer_bloques(ruta_txt):
    tabla = None
    columnas = None
    filas = []

    with open(ruta_txt, "r", encoding="utf-8", newline="") as archivo:
        for linea in archivo:
            linea = linea.rstrip("\n")
            if not linea or linea.startswith("#"):
                continue

            if linea.startswith("@TABLE "):
                tabla = linea.split(" ", 1)[1].strip()
                columnas = None
                filas = []
                continue

            if linea.startswith("@COLUMNS "):
                columnas = linea.split(" ", 1)[1].split(SEPARADOR)
                continue

            if linea == "@END":
                if not tabla or not columnas:
                    raise ValueError("Bloque incompleto en el archivo TXT")
                yield tabla, columnas, filas
                tabla = None
                columnas = None
                filas = []
                continue

            if tabla and columnas:
                fila = next(csv.reader([linea], delimiter=SEPARADOR))
                if len(fila) != len(columnas):
                    raise ValueError(
                        f"La tabla {tabla} esperaba {len(columnas)} columnas y recibio {len(fila)}"
                    )
                filas.append([convertir(valor) for valor in fila])


def vaciar_tablas(conn):
    conn.execute("PRAGMA foreign_keys = OFF")
    for tabla in ORDEN_BORRADO:
        conn.execute(f'DELETE FROM "{tabla}"')
    conn.execute("DELETE FROM sqlite_sequence")
    conn.commit()
    conn.execute("PRAGMA foreign_keys = ON")


def importar(ruta_txt, ruta_db, vaciar=False):
    conn = sqlite3.connect(ruta_db)
    conn.execute("PRAGMA foreign_keys = ON")

    try:
        if vaciar:
            vaciar_tablas(conn)

        total = 0
        for tabla, columnas, filas in leer_bloques(ruta_txt):
            if not filas:
                continue
            columnas_sql = ", ".join(f'"{columna}"' for columna in columnas)
            placeholders = ", ".join("?" for _ in columnas)
            sql = f'INSERT INTO "{tabla}" ({columnas_sql}) VALUES ({placeholders})'
            conn.executemany(sql, filas)
            total += len(filas)

        conn.commit()
        return total
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def main():
    parser = argparse.ArgumentParser(description="Importa el TXT generado hacia una base SQLite")
    parser.add_argument("--txt", default=TXT_SEED_PATH)
    parser.add_argument("--db", default=DB_PATH)
    parser.add_argument("--vaciar", action="store_true", help="Borra las tablas antes de importar")
    args = parser.parse_args()

    total = importar(Path(args.txt), Path(args.db), args.vaciar)
    print(f"OK: importadas {total} filas en {args.db}")


if __name__ == "__main__":
    main()
