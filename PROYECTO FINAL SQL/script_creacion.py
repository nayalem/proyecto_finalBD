import sqlite3

from app_paths import DB_PATH


class BaseDatos:

    def __init__(self):
        self.db_path = DB_PATH

        self.conexion = sqlite3.connect(self.db_path)
        self.conexion.row_factory = sqlite3.Row
        self.cursor = self.conexion.cursor()

    def ejecutar_script(self, archivo_sql):

        try:
            with open(archivo_sql, "r", encoding="utf-8") as archivo:
                script = archivo.read()

            self.cursor.executescript(script)
            self.conexion.commit()

            print(f"OK: ejecutado {archivo_sql}")

        except Exception as e:
            print(f"ERROR en {archivo_sql}:")
            print(e)

    def inicializar(self, scripts: list[str]):
        for s in scripts:
            self.ejecutar_script(s)

    def cerrar(self):
        self.cursor.close()
        self.conexion.close()
