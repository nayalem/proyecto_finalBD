import importlib.util
import sqlite3
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk

from app_paths import DB_PATH, TXT_SEED_PATH, ruta_sqls
from script_creacion import BaseDatos
from script_generar_datos_voluntariado_txt import ORDEN_TABLAS, escribir_tabla, generar_datos
from script_importar_datos_voluntariado_txt import importar


class MenuInicio:
    def __init__(self, root):
        self.root = root
        self.root.title("Inicio - Sistema de Voluntariado")
        self.root.geometry("980x560")
        self.root.minsize(860, 500)

        self._configurar_estilos()
        self._crear_layout()

    def _configurar_estilos(self):
        style = ttk.Style()
        if "clam" in style.theme_names():
            style.theme_use("clam")
        style.configure("Title.TLabel", font=("Segoe UI", 22, "bold"))
        style.configure("Subtitle.TLabel", font=("Segoe UI", 10), foreground="#4a5568")
        style.configure("CardTitle.TLabel", font=("Segoe UI", 13, "bold"))
        style.configure("CardText.TLabel", font=("Segoe UI", 10), foreground="#4a5568")
        style.configure("Status.TLabel", font=("Segoe UI", 9), foreground="#1f5f3b")
        style.configure("Main.TButton", font=("Segoe UI", 14, "bold"), padding=(18, 14))
        style.configure("Side.TButton", font=("Segoe UI", 10, "bold"), padding=(12, 9))

    def _crear_layout(self):
        contenedor = ttk.Frame(self.root, padding=22)
        contenedor.pack(fill="both", expand=True)
        contenedor.columnconfigure(0, weight=3)
        contenedor.columnconfigure(1, weight=2)
        contenedor.rowconfigure(1, weight=1)

        ttk.Label(contenedor, text="Sistema de Voluntariado Comunitario", style="Title.TLabel").grid(
            row=0, column=0, columnspan=2, sticky="w"
        )
        ttk.Label(
            contenedor,
            text="Menu de inicio del proyecto: abre el aplicativo o ejecuta utilidades de base de datos.",
            style="Subtitle.TLabel",
        ).grid(row=0, column=0, columnspan=2, sticky="sw", pady=(38, 0))

        principal = ttk.LabelFrame(contenedor, text="C. Aplicativo principal", padding=18)
        principal.grid(row=1, column=0, sticky="nsew", pady=(22, 0), padx=(0, 14))
        principal.columnconfigure(0, weight=1)
        principal.rowconfigure(2, weight=1)

        ttk.Label(
            principal,
            text="Abrir sistema de gestion",
            style="CardTitle.TLabel",
        ).grid(row=0, column=0, sticky="w")
        ttk.Label(
            principal,
            text=(
                "Esta es la entrada principal del aplicativo. Desde aqui se consultan reportes, "
                "se visualizan tablas y vistas, se administra inventario y se mantiene la informacion."
            ),
            style="CardText.TLabel",
            wraplength=520,
        ).grid(row=1, column=0, sticky="ew", pady=(8, 20))
        ttk.Button(
            principal,
            text="Iniciar aplicativo",
            style="Main.TButton",
            command=self.abrir_aplicativo,
        ).grid(row=2, column=0, sticky="nsew", pady=(8, 0))

        lateral = ttk.Frame(contenedor)
        lateral.grid(row=1, column=1, sticky="nsew", pady=(22, 0))
        lateral.columnconfigure(0, weight=1)
        lateral.rowconfigure(0, weight=1)
        lateral.rowconfigure(1, weight=1)

        self._crear_tarjeta_utilidad(
            lateral,
            fila=0,
            titulo="A. Crear database",
            texto=(
                "Ejecuta los scripts SQL del esquema: tablas, indices, vistas y triggers. "
                "Util para preparar una base nueva."
            ),
            boton="Crear estructura",
            comando=self.crear_database,
        )
        self._crear_tarjeta_utilidad(
            lateral,
            fila=1,
            titulo="B. Datos ficticios",
            texto=(
                "Genera el archivo TXT de datos coherentes, lo importa a voluntariado.db "
                "y muestra conteos por tabla."
            ),
            boton="Generar e insertar",
            comando=self.generar_insertar_datos,
        )

        self.lbl_estado = ttk.Label(contenedor, text="Listo.", style="Status.TLabel")
        self.lbl_estado.grid(row=2, column=0, columnspan=2, sticky="ew", pady=(16, 0))

    def _crear_tarjeta_utilidad(self, parent, fila, titulo, texto, boton, comando):
        tarjeta = ttk.LabelFrame(parent, text=titulo, padding=14)
        tarjeta.grid(row=fila, column=0, sticky="nsew", pady=(0, 12) if fila == 0 else 0)
        tarjeta.columnconfigure(0, weight=1)
        tarjeta.rowconfigure(1, weight=1)

        ttk.Label(tarjeta, text=texto, style="CardText.TLabel", wraplength=330).grid(
            row=0, column=0, sticky="ew"
        )
        ttk.Button(tarjeta, text=boton, style="Side.TButton", command=comando).grid(
            row=1, column=0, sticky="ew", pady=(18, 0)
        )

    def abrir_aplicativo(self):
        for widget in self.root.winfo_children():
            widget.destroy()

        ruta_c = Path(__file__).resolve().parent / "C.inicializacion_aplicativo.py"
        if ruta_c.exists():
            spec = importlib.util.spec_from_file_location("inicializacion_aplicativo_c", ruta_c)
            modulo_c = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(modulo_c)
            modulo_c.iniciar_aplicativo(self.root)
            return

        from script_interfaz_voluntariado import App

        App(self.root)

    def crear_database(self):
        if not messagebox.askyesno(
            "Crear estructura",
            "Deseas ejecutar A.creacion_tablas.py? Si las tablas ya existen, SQLite puede mostrar avisos.",
        ):
            return
        self._crear_database()

    def generar_insertar_datos(self):
        if not messagebox.askyesno(
            "Datos ficticios",
            "Deseas generar e insertar datos ficticios? Se vaciaran las tablas antes de importar para evitar duplicados.",
        ):
            return
        try:
            if not DB_PATH.exists():
                self._crear_database(mostrar_mensaje=False)
            self.lbl_estado.config(text="Generando e insertando datos ficticios...")
            self.root.update_idletasks()

            ruta_b = Path(__file__).resolve().parent / "B.creacion_insercion_datos_aleatorios.py"
            if ruta_b.exists():
                spec = importlib.util.spec_from_file_location("datos_aleatorios_b", ruta_b)
                modulo_b = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(modulo_b)
                salida = modulo_b.ejecutar_flujo(vaciar=True)
            else:
                salida = self._generar_insertar_datos_directo()

            self.lbl_estado.config(text="Datos ficticios generados e importados.")
            messagebox.showinfo("Proceso terminado", salida)
        except Exception as error:
            self.lbl_estado.config(text="Error al generar o insertar datos ficticios.")
            messagebox.showerror("Error", str(error))

    def _crear_database(self, mostrar_mensaje=True):
        try:
            self.lbl_estado.config(text="Creando estructura de base de datos...")
            self.root.update_idletasks()

            ruta_a = Path(__file__).resolve().parent / "A.creacion_tablas.py"
            if ruta_a.exists():
                spec = importlib.util.spec_from_file_location("creacion_tablas_a", ruta_a)
                modulo_a = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(modulo_a)
                salida = modulo_a.crear_database()
            else:
                salida = self._crear_database_directo()

            self.lbl_estado.config(text="Estructura de base de datos creada o actualizada.")
            if mostrar_mensaje:
                messagebox.showinfo("Proceso terminado", salida)
        except Exception as error:
            self.lbl_estado.config(text="Error al crear la estructura.")
            messagebox.showerror("Error", str(error))
            raise

    def _crear_database_directo(self):
        bd = BaseDatos()
        sql_dir = ruta_sqls()
        scripts = [
            sql_dir / "database.sql",
            sql_dir / "indices.sql",
            sql_dir / "vistas_reportes.sql",
            sql_dir / "triggers.sql",
        ]
        faltantes = [str(ruta) for ruta in scripts if not ruta.exists()]
        if faltantes:
            raise FileNotFoundError("No se encontraron archivos SQL:\n" + "\n".join(faltantes))
        try:
            bd.inicializar(scripts)
        finally:
            bd.cerrar()
        return f"Estructura creada en {DB_PATH}"

    def _generar_insertar_datos_directo(self):
        datos = generar_datos()
        with TXT_SEED_PATH.open("w", encoding="utf-8", newline="") as archivo:
            archivo.write("# VOLUNTARIADO_SEED_TXT v1\n")
            archivo.write("# SEPARADOR=| NULL=\\N\n")
            archivo.write("# Cada bloque declara tabla, columnas y filas en orden de insercion.\n\n")
            for tabla, columnas in ORDEN_TABLAS:
                escribir_tabla(archivo, tabla, columnas, datos[tabla])

        total_generado = sum(len(datos[tabla]) for tabla, _ in ORDEN_TABLAS)
        total_importado = importar(TXT_SEED_PATH, DB_PATH, vaciar=True)
        mensajes = [
            f"OK: generado {TXT_SEED_PATH} con {total_generado} filas.",
            f"OK: importadas {total_importado} filas en {DB_PATH}.",
            "Conteo final por tabla:",
        ]
        conn = sqlite3.connect(DB_PATH)
        try:
            for tabla, _ in ORDEN_TABLAS:
                total = conn.execute(f'SELECT COUNT(*) FROM "{tabla}"').fetchone()[0]
                mensajes.append(f"- {tabla}: {total}")
        finally:
            conn.close()
        return "\n".join(mensajes)


if __name__ == "__main__":
    root = tk.Tk()
    MenuInicio(root)
    root.mainloop()
