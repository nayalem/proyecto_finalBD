"""
Flujo recomendado para poblar la base de datos de voluntariado.

Orden logico:
1. Generar un TXT con datos aleatorios pero coherentes.
2. Importar ese TXT hacia una base SQLite compatible con sqls/database.sql.
3. Verificar que las tablas principales quedaron con filas.

Este archivo no reemplaza a los otros dos scripts: solo los ordena y documenta.
Puedes mover el TXT e importador a otra carpeta si quieres alimentar otra copia
de la base, siempre que esa base tenga el mismo esquema.
"""

import argparse
import sqlite3
from pathlib import Path

from app_paths import DB_PATH, TXT_SEED_PATH
from script_generar_datos_voluntariado_txt import generar_datos, escribir_tabla, ORDEN_TABLAS
from script_importar_datos_voluntariado_txt import importar


TXT_DEFECTO = TXT_SEED_PATH
DB_DEFECTO = DB_PATH


def generar_txt(ruta_txt, seed=None):
    """
    Genera el archivo intermedio.

    El TXT queda ordenado por bloques:
    @TABLE nombre_tabla
    @COLUMNS columna1|columna2|...
    fila1
    fila2
    @END

    El valor \\N representa NULL. Ese formato evita depender de Excel y hace que
    otro script externo pueda leerlo con csv.reader usando "|" como separador.
    """
    import random

    if seed is not None:
        random.seed(seed)

    datos = generar_datos()
    with ruta_txt.open("w", encoding="utf-8", newline="") as archivo:
        archivo.write("# VOLUNTARIADO_SEED_TXT v1\n")
        archivo.write("# SEPARADOR=| NULL=\\N\n")
        archivo.write("# Cada bloque declara tabla, columnas y filas en orden de insercion.\n\n")
        for tabla, columnas in ORDEN_TABLAS:
            escribir_tabla(archivo, tabla, columnas, datos[tabla])

    return sum(len(datos[tabla]) for tabla, _ in ORDEN_TABLAS)


def verificar_db(ruta_db):
    """
    Lee conteos por tabla para confirmar que la importacion fue efectiva.
    """
    conn = sqlite3.connect(ruta_db)
    try:
        tablas = [tabla for tabla, _ in ORDEN_TABLAS]
        return {
            tabla: conn.execute(f'SELECT COUNT(*) FROM "{tabla}"').fetchone()[0]
            for tabla in tablas
        }
    finally:
        conn.close()


def main():
    parser = argparse.ArgumentParser(description="Genera TXT, importa datos y verifica voluntariado.db")
    parser.add_argument("--txt", default=TXT_DEFECTO, type=Path)
    parser.add_argument("--db", default=DB_DEFECTO, type=Path)
    parser.add_argument("--seed", type=int, default=None, help="Usa una semilla para resultados reproducibles")
    parser.add_argument("--no-generar", action="store_true", help="No regenera el TXT; usa el existente")
    parser.add_argument("--no-importar", action="store_true", help="Solo genera el TXT; no toca la DB")
    parser.add_argument("--vaciar", action="store_true", help="Borra las tablas antes de importar")
    args = parser.parse_args()

    if not args.no_generar:
        total_generado = generar_txt(args.txt, args.seed)
        print(f"OK: generado {args.txt} con {total_generado} filas.")

    if not args.no_importar:
        total_importado = importar(args.txt, args.db, vaciar=args.vaciar)
        print(f"OK: importadas {total_importado} filas en {args.db}.")

        print("\nConteo final por tabla:")
        for tabla, total in verificar_db(args.db).items():
            print(f"- {tabla}: {total}")


def ejecutar_flujo(vaciar=False, seed=None, generar=True, importar_datos=True):
    mensajes = []
    if generar:
        total_generado = generar_txt(TXT_DEFECTO, seed)
        mensajes.append(f"OK: generado {TXT_DEFECTO} con {total_generado} filas.")

    if importar_datos:
        total_importado = importar(TXT_DEFECTO, DB_DEFECTO, vaciar=vaciar)
        mensajes.append(f"OK: importadas {total_importado} filas en {DB_DEFECTO}.")
        mensajes.append("Conteo final por tabla:")
        for tabla, total in verificar_db(DB_DEFECTO).items():
            mensajes.append(f"- {tabla}: {total}")

    return "\n".join(mensajes)


if __name__ == "__main__":
    main()
