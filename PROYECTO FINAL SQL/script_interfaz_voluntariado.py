import tkinter as tk
from tkinter import messagebox, ttk

from script_funciones import (
    DB_PATH,
    InventarioService,
    MantenimientoTablas,
    SqliteExplorer,
    VoluntariadoDB,
    conectar,
    inicializar_componentes_sql,
)


class TablaResultado(ttk.Frame):
    def __init__(self, parent):
        super().__init__(parent)
        self.tree = ttk.Treeview(self, show="headings")
        self.scroll_y = ttk.Scrollbar(self, orient="vertical", command=self.tree.yview)
        self.scroll_x = ttk.Scrollbar(self, orient="horizontal", command=self.tree.xview)
        self.tree.configure(yscrollcommand=self.scroll_y.set, xscrollcommand=self.scroll_x.set)

        self.tree.grid(row=0, column=0, sticky="nsew")
        self.scroll_y.grid(row=0, column=1, sticky="ns")
        self.scroll_x.grid(row=1, column=0, sticky="ew")
        self.columnconfigure(0, weight=1)
        self.rowconfigure(0, weight=1)

    def mostrar(self, columnas, filas):
        self.tree.delete(*self.tree.get_children())
        self.tree["columns"] = columnas

        for columna in columnas:
            self.tree.heading(columna, text=columna)
            self.tree.column(columna, width=max(110, min(230, len(columna) * 12)), anchor="w")

        for fila in filas:
            valores = tuple("" if valor is None else valor for valor in fila)
            self.tree.insert("", "end", values=valores)

    def limpiar(self):
        self.mostrar([], [])


class App:
    def __init__(self, root):
        self.root = root
        self.root.title("Sistema de Voluntariado - SQLite")
        self.root.geometry("1180x760")
        self.root.minsize(980, 620)

        self.conn = conectar(DB_PATH)
        inicializar_componentes_sql(self.conn)
        self.db = VoluntariadoDB(self.conn)
        self.inventario = InventarioService(self.conn)
        self.explorer = SqliteExplorer(self.conn)
        self.mantenimiento = MantenimientoTablas(self.conn)
        self.mant_pk_original = {}
        self.mant_columnas = []

        self._configurar_estilos()
        self._crear_layout()
        self.root.protocol("WM_DELETE_WINDOW", self.cerrar)

    def _configurar_estilos(self):
        style = ttk.Style()
        if "clam" in style.theme_names():
            style.theme_use("clam")
        style.configure("Title.TLabel", font=("Segoe UI", 15, "bold"))
        style.configure("Hint.TLabel", foreground="#555")
        style.configure("Status.TLabel", foreground="#1f5f3b")
        style.configure("Danger.TLabel", foreground="#9b1c1c")

    def _crear_layout(self):
        header = ttk.Frame(self.root, padding=(14, 12, 14, 6))
        header.pack(fill="x")
        ttk.Label(header, text="Sistema de Voluntariado", style="Title.TLabel").pack(side="left")
        ttk.Label(header, text=f"Base: {DB_PATH}", style="Hint.TLabel").pack(side="right")

        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill="both", expand=True, padx=12, pady=(0, 12))

        self._tab_funciones()
        self._tab_explorar()
        self._tab_mantenimiento()
        self._tab_sql()
        self._tab_inventario()

    def _tab_funciones(self):
        tab = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(tab, text="Consultas rapidas")
        tab.columnconfigure(1, weight=1)
        tab.rowconfigure(6, weight=1)

        ttk.Label(tab, text="Funcion").grid(row=0, column=0, sticky="w", pady=4)
        self.cmb_funcion = ttk.Combobox(tab, state="readonly", width=42)
        self.cmb_funcion["values"] = [
            "Stock de recurso en almacen",
            "Total de donaciones por proyecto",
            "Total de gastos por proyecto",
            "Saldo presupuestal por proyecto",
            "Porcentaje de asistencia por voluntario",
            "Reporte resumen de proyectos",
            "Reporte financiero de proyectos",
            "Reporte participacion de voluntarios",
        ]
        self.cmb_funcion.current(0)
        self.cmb_funcion.grid(row=0, column=1, sticky="ew", padx=8, pady=4)
        self.cmb_funcion.bind("<<ComboboxSelected>>", self.cambiar_formulario)

        self.lbl_p1 = ttk.Label(tab, text="Parametro 1")
        self.lbl_p1.grid(row=1, column=0, sticky="w", pady=4)
        self.ent_p1 = ttk.Entry(tab)
        #self.ent_p1 = ttk.Combobox(tab)
        self.ent_p1.grid(row=1, column=1, sticky="ew", padx=8, pady=4)

        self.lbl_p2 = ttk.Label(tab, text="Parametro 2")
        self.lbl_p2.grid(row=2, column=0, sticky="w", pady=4)
        self.ent_p2 = ttk.Entry(tab)
        #self.ent_p2 = ttk.Combobox(tab)
        self.ent_p2.grid(row=2, column=1, sticky="ew", padx=8, pady=4)

        botones = ttk.Frame(tab)
        botones.grid(row=3, column=0, columnspan=2, sticky="ew", pady=8)
        ttk.Button(botones, text="Ejecutar", command=self.ejecutar_funcion).pack(side="left")
        ttk.Button(botones, text="Limpiar", command=self.limpiar_funcion).pack(side="left", padx=8)

        self.lbl_resultado = ttk.Label(tab, text="Resultado: -", style="Status.TLabel")
        self.lbl_resultado.grid(row=4, column=0, columnspan=2, sticky="w", pady=(4, 10))

        self.tabla_funciones = TablaResultado(tab)
        self.tabla_funciones.grid(row=6, column=0, columnspan=2, sticky="nsew")
        self.cambiar_formulario()

    def _tab_explorar(self):
        tab = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(tab, text="Tablas y vistas")
        tab.columnconfigure(1, weight=1)
        tab.rowconfigure(2, weight=1)

        ttk.Label(tab, text="Objeto").grid(row=0, column=0, sticky="w")
        self.cmb_objeto = ttk.Combobox(tab, state="readonly")
        self.cmb_objeto.grid(row=0, column=1, sticky="ew", padx=8)

        controles = ttk.Frame(tab)
        controles.grid(row=1, column=0, columnspan=2, sticky="ew", pady=8)
        ttk.Button(controles, text="Actualizar lista", command=self.cargar_objetos).pack(side="left")
        ttk.Button(controles, text="Ver datos", command=self.ver_objeto).pack(side="left", padx=8)
        ttk.Button(controles, text="Resumen tablas", command=self.ver_resumen_tablas).pack(side="left")
        ttk.Label(controles, text="Limite").pack(side="left", padx=(16, 4))
        self.limite_objeto = tk.IntVar(value=300)
        ttk.Spinbox(controles, from_=1, to=1000, width=6, textvariable=self.limite_objeto).pack(
            side="left"
        )

        self.tabla_explorar = TablaResultado(tab)
        self.tabla_explorar.grid(row=2, column=0, columnspan=2, sticky="nsew")
        self.cargar_objetos()

    def _tab_mantenimiento(self):
        tab = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(tab, text="Mantenimiento")
        tab.columnconfigure(0, weight=0)
        tab.columnconfigure(1, weight=1)
        tab.rowconfigure(2, weight=1)

        ttk.Label(tab, text="Tabla").grid(row=0, column=0, sticky="w")
        self.cmb_mant_tabla = ttk.Combobox(tab, state="readonly", width=32)
        self.cmb_mant_tabla.grid(row=0, column=1, sticky="ew", padx=8)
        self.cmb_mant_tabla.bind("<<ComboboxSelected>>", self.cambiar_tabla_mantenimiento)

        controles = ttk.Frame(tab)
        controles.grid(row=1, column=0, columnspan=2, sticky="ew", pady=8)
        ttk.Button(controles, text="Actualizar tabla", command=self.refrescar_mantenimiento).pack(side="left")
        ttk.Button(controles, text="Nuevo / limpiar", command=self.limpiar_mantenimiento).pack(
            side="left", padx=8
        )
        ttk.Button(controles, text="Insertar", command=self.insertar_mantenimiento).pack(side="left")
        ttk.Button(controles, text="Modificar", command=self.modificar_mantenimiento).pack(side="left", padx=8)
        ttk.Button(controles, text="Eliminar", command=self.eliminar_mantenimiento).pack(side="left")
        ttk.Label(controles, text="Limite").pack(side="left", padx=(16, 4))
        self.limite_mant = tk.IntVar(value=300)
        ttk.Spinbox(controles, from_=1, to=1000, width=6, textvariable=self.limite_mant).pack(side="left")

        panel_form = ttk.LabelFrame(tab, text="Datos del registro", padding=8)
        panel_form.grid(row=2, column=0, sticky="nsw", padx=(0, 10))
        panel_form.rowconfigure(0, weight=1)
        panel_form.columnconfigure(0, weight=1)

        self.mant_canvas = tk.Canvas(panel_form, width=390, highlightthickness=0)
        self.mant_scroll = ttk.Scrollbar(panel_form, orient="vertical", command=self.mant_canvas.yview)
        self.mant_campos_frame = ttk.Frame(self.mant_canvas)
        self.mant_campos_frame.bind(
            "<Configure>",
            lambda event: self.mant_canvas.configure(scrollregion=self.mant_canvas.bbox("all")),
        )
        self.mant_canvas.create_window((0, 0), window=self.mant_campos_frame, anchor="nw")
        self.mant_canvas.configure(yscrollcommand=self.mant_scroll.set)
        self.mant_canvas.grid(row=0, column=0, sticky="nsew")
        self.mant_scroll.grid(row=0, column=1, sticky="ns")

        panel_datos = ttk.Frame(tab)
        panel_datos.grid(row=2, column=1, sticky="nsew")
        panel_datos.rowconfigure(1, weight=1)
        panel_datos.columnconfigure(0, weight=1)
        self.lbl_mant_estado = ttk.Label(
            panel_datos,
            text="Selecciona una tabla para insertar, modificar o eliminar registros.",
            style="Hint.TLabel",
            wraplength=680,
        )
        self.lbl_mant_estado.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        self.tabla_mantenimiento = TablaResultado(panel_datos)
        self.tabla_mantenimiento.grid(row=1, column=0, sticky="nsew")
        self.tabla_mantenimiento.tree.bind("<<TreeviewSelect>>", self.seleccionar_fila_mantenimiento)

        self.cargar_tablas_mantenimiento()

    def _tab_sql(self):
        tab = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(tab, text="Editor SQLite")
        tab.columnconfigure(0, weight=1)
        tab.rowconfigure(4, weight=1)

        ttk.Label(
            tab,
            text="Escribe SQL y ejecutalo. Si SQLite devuelve filas, se mostraran abajo.",
            style="Hint.TLabel",
        ).grid(row=0, column=0, sticky="w")

        self.txt_sql = tk.Text(tab, height=8, wrap="none", font=("Consolas", 10))
        self.txt_sql.grid(row=1, column=0, sticky="ew", pady=8)
        self.txt_sql.insert(
            "1.0",
            "SELECT name, type FROM sqlite_master "
            "WHERE type IN ('table','view') ORDER BY type, name;",
        )

        botones = ttk.Frame(tab)
        botones.grid(row=2, column=0, sticky="ew")
        ttk.Button(botones, text="Ejecutar SQL", command=self.ejecutar_sql).pack(side="left")
        ttk.Button(botones, text="Limpiar editor", command=lambda: self.txt_sql.delete("1.0", tk.END)).pack(
            side="left", padx=8
        )
        ttk.Button(botones, text="Ejemplo reporte", command=self.cargar_ejemplo_sql).pack(side="left")
        #ttk.Button(botones, text="Ejemplo INSERT", command=self.cargar_ejemplo_insert).pack(side="left", padx=8)
        #ttk.Button(botones, text="Ejemplo DELETE", command=self.cargar_ejemplo_delete).pack(side="left")

        self.lbl_sql_estado = ttk.Label(tab, text="Listo", style="Status.TLabel")
        self.lbl_sql_estado.grid(row=3, column=0, sticky="w", pady=8)

        self.tabla_sql = TablaResultado(tab)
        self.tabla_sql.grid(row=4, column=0, sticky="nsew")

    def _tab_inventario(self):
        tab = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(tab, text="Inventario")
        tab.columnconfigure(1, weight=1)
        tab.rowconfigure(7, weight=1)

        campos = [
            ("ID almacen", "almacen"),
            ("ID recurso", "recurso"),
            ("Cantidad actual / movimiento", "cantidad"),
            ("Cantidad minima", "minima"),
            ("ID movimiento", "movimiento"),
            ("Revertir movimiento", "revertir"),
        ]
        self.inv_entries = {}
        for fila, (texto, clave) in enumerate(campos):
            ttk.Label(tab, text=texto).grid(row=fila, column=0, sticky="w", pady=4)
            if clave == "revertir":
                var = tk.BooleanVar(value=False)
                ttk.Checkbutton(tab, variable=var).grid(row=fila, column=1, sticky="w", padx=8)
                self.inv_entries[clave] = var
            else:
                entry = ttk.Entry(tab)
                entry.grid(row=fila, column=1, sticky="ew", padx=8, pady=4)
                self.inv_entries[clave] = entry

        botones = ttk.Frame(tab)
        botones.grid(row=6, column=0, columnspan=2, sticky="ew", pady=8)
        ttk.Button(botones, text="Registrar inventario inicial", command=self.registrar_inventario).pack(
            side="left"
        )
        ttk.Button(botones, text="Aplicar movimiento", command=self.aplicar_movimiento).pack(
            side="left", padx=8
        )
        ttk.Button(botones, text="Ver inventario", command=self.ver_inventario).pack(side="left")

        self.tabla_inventario = TablaResultado(tab)
        self.tabla_inventario.grid(row=7, column=0, columnspan=2, sticky="nsew")

    def cambiar_formulario(self, event=None):
        opcion = self.cmb_funcion.get()
        requiere_dos = opcion == "Stock de recurso en almacen"
        sin_parametros = opcion == "Reporte participacion de voluntarios"

        self.lbl_p1.config(
            text={
                "Stock de recurso en almacen": "ID almacen",
                "Total de donaciones por proyecto": "ID proyecto",
                "Total de gastos por proyecto": "ID proyecto",
                "Saldo presupuestal por proyecto": "ID proyecto",
                "Porcentaje de asistencia por voluntario": "ID voluntario",
                "Reporte resumen de proyectos": "ID proyecto opcional",
                "Reporte financiero de proyectos": "ID proyecto opcional",
                "Reporte participacion de voluntarios": "No usado",
            }.get(opcion, "Parametro")
        )
        self.lbl_p2.config(text="ID recurso" if requiere_dos else "No usado")
        #self.ent_p1["values"] = []
        #self.ent_p2["values"] = []
        self.ent_p1.config(state="disabled" if sin_parametros else "normal")

        self.ent_p2.config(state="normal" if requiere_dos else "disabled")#reemplazar con los # de abajo si no funcionase
        #

        #self.ent_p2.config(state="readonly" if requiere_dos else "disabled")

        #if requiere_dos:
        #    self.cargar_opciones_stock()
        #    self.ent_p1.config(state="readonly")
        #
        if sin_parametros:
            self.ent_p1.config(state="normal")
            self.ent_p1.delete(0, tk.END)
            self.ent_p1.config(state="disabled")
        if not requiere_dos:
            self.ent_p2.config(state="normal")
            self.ent_p2.delete(0, tk.END)
            self.ent_p2.config(state="disabled")

    """
    def cargar_opciones_stock(self):
        almacenes = self.conn.execute(

            #SELECT id_almacen, nombre
            #FROM almacen
            #ORDER BY id_almacen
           
        ).fetchall()
        recursos = self.conn.execute(

            #SELECT id_recurso, nombre
            #FROM recurso
            #ORDER BY id_recurso
   
        ).fetchall()
        self.ent_p1["values"] = [f"{fila['id_almacen']} - {fila['nombre']}" for fila in almacenes]
        self.ent_p2["values"] = [f"{fila['id_recurso']} - {fila['nombre']}" for fila in recursos]
        if almacenes and not self.ent_p1.get().strip():
            self.ent_p1.current(0)
        if recursos and not self.ent_p2.get().strip():
            self.ent_p2.current(0)

    
    def obtener_id(self, valor):
        valor = valor.strip()
        if " - " in valor:
            valor = valor.split(" - ", 1)[0]
        return int(valor)
    """

    def limpiar_funcion(self):
        self.ent_p1.config(state="normal")
        self.ent_p2.config(state="normal")
        self.ent_p1.delete(0, tk.END)
        self.ent_p2.delete(0, tk.END)
        self.lbl_resultado.config(text="Resultado: -", style="Status.TLabel")
        self.tabla_funciones.limpiar()
        self.cambiar_formulario()

    def ejecutar_funcion(self):
        try:
            op = self.cmb_funcion.get()
            p1 = self.ent_p1.get().strip()
            p2 = self.ent_p2.get().strip()
            self.tabla_funciones.limpiar()

            if op == "Stock de recurso en almacen":

                resultado = self.db.fn_stock_recurso_almacen(int(p1), int(p2))
                self.lbl_resultado.config(text=f"Resultado: {resultado}", style="Status.TLabel")

                """
                id_almacen = self.obtener_id(p1)
                id_recurso = self.obtener_id(p2)
                resultado = self.db.fn_stock_recurso_almacen(id_almacen, id_recurso)
                self.lbl_resultado.config(
                    text=f"Resultado: {resultado} unidad(es) en almacen {id_almacen}, recurso {id_recurso}",
                    style="Status.TLabel",
                )
                """
            elif op == "Total de donaciones por proyecto":
                resultado = self.db.fn_total_donaciones_proyecto(int(p1))
                #resultado = self.db.fn_total_donaciones_proyecto(self.obtener_id(p1))
                self.lbl_resultado.config(text=f"Resultado: S/ {resultado:.2f}", style="Status.TLabel")
            elif op == "Total de gastos por proyecto":
                resultado = self.db.fn_total_gastos_proyecto(int(p1))
                #resultado = self.db.fn_total_gastos_proyecto(self.obtener_id(p1))
                self.lbl_resultado.config(text=f"Resultado: S/ {resultado:.2f}", style="Status.TLabel")
            elif op == "Saldo presupuestal por proyecto":
                resultado = self.db.fn_saldo_presupuestal_proyecto(int(p1))
                #resultado = self.db.fn_saldo_presupuestal_proyecto(self.obtener_id(p1))
                self.lbl_resultado.config(text=f"Resultado: S/ {resultado:.2f}", style="Status.TLabel")
            elif op == "Porcentaje de asistencia por voluntario":
                resultado = self.db.fn_porcentaje_asistencia_voluntario(int(p1))
                #resultado = self.db.fn_porcentaje_asistencia_voluntario(self.obtener_id(p1))
                self.lbl_resultado.config(text=f"Resultado: {resultado}%", style="Status.TLabel")
            elif op == "Reporte resumen de proyectos":
                columnas, filas = self.db.reporte_resumen_proyecto(int(p1) if p1 else None)
                #columnas, filas = self.db.reporte_resumen_proyecto(self.obtener_id(p1) if p1 else None)
                self.tabla_funciones.mostrar(columnas, filas)
                self.lbl_resultado.config(text=f"Resultado: {len(filas)} fila(s)", style="Status.TLabel")
            elif op == "Reporte financiero de proyectos":
                columnas, filas = self.db.reporte_financiero_proyecto(int(p1) if p1 else None)
                #columnas, filas = self.db.reporte_financiero_proyecto(self.obtener_id(p1) if p1 else None)
                self.tabla_funciones.mostrar(columnas, filas)
                self.lbl_resultado.config(text=f"Resultado: {len(filas)} fila(s)", style="Status.TLabel")
            elif op == "Reporte participacion de voluntarios":
                columnas, filas = self.db.reporte_participacion_voluntarios()
                self.tabla_funciones.mostrar(columnas, filas)
                self.lbl_resultado.config(text=f"Resultado: {len(filas)} fila(s)", style="Status.TLabel")
        except Exception as error:
            self.lbl_resultado.config(text=f"Error: {error}", style="Danger.TLabel")
            messagebox.showerror("Error SQLite", str(error))

    def cargar_objetos(self):
        objetos = [f"{tipo}: {nombre}" for tipo, nombre in self.explorer.listar_objetos()]
        self.cmb_objeto["values"] = objetos
        if objetos:
            self.cmb_objeto.current(0)

    def ver_objeto(self):
        try:
            seleccionado = self.cmb_objeto.get()
            nombre = seleccionado.split(": ", 1)[1] if ": " in seleccionado else seleccionado
            columnas, filas = self.explorer.consultar_objeto(nombre, self.limite_objeto.get())
            self.tabla_explorar.mostrar(columnas, filas)
        except Exception as error:
            messagebox.showerror("Error SQLite", str(error))

    def ver_resumen_tablas(self):
        try:
            filas = []
            for tipo, nombre in self.explorer.listar_objetos("table"):
                total = self.conn.execute(f'SELECT COUNT(*) FROM "{nombre}"').fetchone()[0]
                filas.append((nombre, total))
            self.tabla_explorar.mostrar(["tabla", "filas"], filas)
        except Exception as error:
            messagebox.showerror("Error SQLite", str(error))

    def cargar_tablas_mantenimiento(self):
        tablas = self.mantenimiento.listar_tablas()
        self.cmb_mant_tabla["values"] = tablas
        if tablas:
            self.cmb_mant_tabla.current(0)
            self.cambiar_tabla_mantenimiento()

    def tabla_mantenimiento_actual(self):
        tabla = self.cmb_mant_tabla.get().strip()
        if not tabla:
            raise ValueError("Selecciona una tabla")
        return tabla

    def cambiar_tabla_mantenimiento(self, event=None):
        try:
            tabla = self.tabla_mantenimiento_actual()
            self.mant_columnas = self.mantenimiento.columnas(tabla)
            self.mant_pk_original = {}
            self._crear_campos_mantenimiento(tabla)
            self.refrescar_mantenimiento()
        except Exception as error:
            self.lbl_mant_estado.config(text=f"Error: {error}", style="Danger.TLabel")
            messagebox.showerror("Error SQLite", str(error))

    def _crear_campos_mantenimiento(self, tabla):
        for widget in self.mant_campos_frame.winfo_children():
            widget.destroy()
        self.mant_entries = {}
        fks = {fk["from"]: fk for fk in self.mantenimiento.claves_foraneas(tabla)}

        for fila, columna in enumerate(self.mant_columnas):
            nombre = columna["name"]
            marcas = []
            if columna["pk"]:
                marcas.append("PK")
            if columna["notnull"]:
                marcas.append("obligatorio")
            if nombre in fks:
                fk = fks[nombre]
                marcas.append(f"FK -> {fk['table']}.{fk['to']}")
            tipo = columna["type"] or "TEXT"
            texto = f"{nombre} ({tipo})"
            if marcas:
                texto += " - " + ", ".join(marcas)

            ttk.Label(self.mant_campos_frame, text=texto, wraplength=360).grid(
                row=fila * 2, column=0, sticky="w", pady=(5, 1)
            )
            entry = ttk.Entry(self.mant_campos_frame, width=46)
            entry.grid(row=fila * 2 + 1, column=0, sticky="ew", pady=(0, 3))
            self.mant_entries[nombre] = entry

        self.mant_campos_frame.columnconfigure(0, weight=1)

    def refrescar_mantenimiento(self):
        tabla = self.tabla_mantenimiento_actual()
        columnas, filas = self.mantenimiento.consultar(tabla, self.limite_mant.get())
        self.tabla_mantenimiento.mostrar(columnas, filas)
        self.lbl_mant_estado.config(
            text=f"{tabla}: {len(filas)} fila(s). Selecciona una fila para modificar o eliminar.",
            style="Status.TLabel",
        )

    def limpiar_mantenimiento(self):
        for entry in self.mant_entries.values():
            entry.delete(0, tk.END)
        self.mant_pk_original = {}
        self.tabla_mantenimiento.tree.selection_remove(self.tabla_mantenimiento.tree.selection())
        self.lbl_mant_estado.config(text="Formulario listo para insertar un registro nuevo.", style="Status.TLabel")

    def seleccionar_fila_mantenimiento(self, event=None):
        seleccion = self.tabla_mantenimiento.tree.selection()
        if not seleccion:
            return
        valores = self.tabla_mantenimiento.tree.item(seleccion[0], "values")
        columnas = list(self.tabla_mantenimiento.tree["columns"])
        fila = dict(zip(columnas, valores))

        for nombre, entry in self.mant_entries.items():
            entry.delete(0, tk.END)
            entry.insert(0, fila.get(nombre, ""))

        pk_cols = self.mantenimiento.claves_primarias(self.tabla_mantenimiento_actual())
        self.mant_pk_original = {pk: fila.get(pk) for pk in pk_cols}
        if pk_cols:
            texto_pk = ", ".join(f"{pk}={self.mant_pk_original[pk]}" for pk in pk_cols)
            self.lbl_mant_estado.config(text=f"Fila seleccionada ({texto_pk}).", style="Status.TLabel")

    def valores_mantenimiento(self):
        return {nombre: entry.get().strip() for nombre, entry in self.mant_entries.items()}

    def insertar_mantenimiento(self):
        try:
            tabla = self.tabla_mantenimiento_actual()
            self.mantenimiento.insertar(tabla, self.valores_mantenimiento())
            self.refrescar_mantenimiento()
            self.limpiar_mantenimiento()
            self.lbl_mant_estado.config(text="Registro insertado correctamente.", style="Status.TLabel")
        except Exception as error:
            self.lbl_mant_estado.config(text=f"Error: {error}", style="Danger.TLabel")
            messagebox.showerror("No se pudo insertar", str(error))

    def modificar_mantenimiento(self):
        try:
            tabla = self.tabla_mantenimiento_actual()
            self.mantenimiento.actualizar(tabla, self.valores_mantenimiento(), self.mant_pk_original)
            self.refrescar_mantenimiento()
            self.lbl_mant_estado.config(text="Registro modificado correctamente.", style="Status.TLabel")
        except Exception as error:
            self.lbl_mant_estado.config(text=f"Error: {error}", style="Danger.TLabel")
            messagebox.showerror("No se pudo modificar", str(error))

    def eliminar_mantenimiento(self):
        try:
            tabla = self.tabla_mantenimiento_actual()
            if not self.mant_pk_original:
                raise ValueError("Selecciona primero una fila")
            if not messagebox.askyesno("Confirmar eliminacion", "Deseas eliminar la fila seleccionada?"):
                return
            self.mantenimiento.eliminar(tabla, self.mant_pk_original)
            self.refrescar_mantenimiento()
            self.limpiar_mantenimiento()
            self.lbl_mant_estado.config(text="Registro eliminado correctamente.", style="Status.TLabel")
        except Exception as error:
            self.lbl_mant_estado.config(text=f"Error: {error}", style="Danger.TLabel")
            messagebox.showerror("No se pudo eliminar", str(error))

    def ejecutar_sql(self):
        sql = self.txt_sql.get("1.0", tk.END)
        try:
            (columnas, filas), mensaje = self.explorer.ejecutar_sql(sql)
            self.tabla_sql.mostrar(columnas, filas)
            self.lbl_sql_estado.config(text=mensaje, style="Status.TLabel")
            self.cargar_objetos()   
        except Exception as error:
            self.tabla_sql.limpiar()
            self.lbl_sql_estado.config(text=f"Error: {error}", style="Danger.TLabel")
            messagebox.showerror("Error SQLite", str(error))

    def cargar_ejemplo_sql(self):
        self.txt_sql.delete("1.0", tk.END)
        self.txt_sql.insert(
            "1.0",
            "SELECT *\nFROM vw_reporte_inventario_actual\nORDER BY almacen, recurso;",
        )

    def registrar_inventario(self):
        try:
            self.inventario.registrar_inventario_inicial(
                int(self.inv_entries["almacen"].get()),
                int(self.inv_entries["recurso"].get()),
                int(self.inv_entries["cantidad"].get()),
                int(self.inv_entries["minima"].get()),
            )
            messagebox.showinfo("Inventario", "Inventario inicial registrado")
            self.ver_inventario()
        except Exception as error:
            messagebox.showerror("Error SQLite", str(error))

    def aplicar_movimiento(self):
        try:
            self.inventario.aplicar_movimiento_inventario(
                int(self.inv_entries["movimiento"].get()),
                int(self.inv_entries["recurso"].get()),
                int(self.inv_entries["cantidad"].get()),
                self.inv_entries["revertir"].get(),
            )
            messagebox.showinfo("Inventario", "Movimiento aplicado")
            self.ver_inventario()
        except Exception as error:
            messagebox.showerror("Error SQLite", str(error))

    def ver_inventario(self):
        columnas, filas = self.explorer.consultar_objeto("vw_reporte_inventario_actual", 1000)
        self.tabla_inventario.mostrar(columnas, filas)

    def cerrar(self):
        try:
            self.conn.close()
        finally:
            self.root.destroy()


if __name__ == "__main__":
    root = tk.Tk()
    App(root)
    root.mainloop()
