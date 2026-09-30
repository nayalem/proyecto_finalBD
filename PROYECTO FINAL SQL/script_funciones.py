import sqlite3

from app_paths import DB_PATH, ruta_sqls

SQL_DIR = ruta_sqls()


def conectar(db_path=DB_PATH):
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def filas_a_tabla(cursor, filas):
    columnas = [desc[0] for desc in cursor.description] if cursor.description else []
    return columnas, [tuple(fila) for fila in filas]


def nombre_sql(nombre):
    return '"' + nombre.replace('"', '""') + '"'


def ejecutar_script_sql(conn, ruta):
    with open(ruta, "r", encoding="utf-8") as archivo:
        conn.executescript(archivo.read())
    conn.commit()


def inicializar_componentes_sql(conn):
    """Aplica componentes que no duplican tablas base al iniciar la app."""
    for nombre in ("indices.sql", "vistas_reportes.sql"):
        ruta = SQL_DIR / nombre
        if ruta.exists():
            ejecutar_script_sql(conn, ruta)


class VoluntariadoDB:
    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn

    def fn_stock_recurso_almacen(self, id_almacen, id_recurso):
        fila = self.conn.execute(
            """
            SELECT COALESCE(cantidad_actual, 0)
            FROM inventario
            WHERE id_almacen = ? AND id_recurso = ?
            """,
            (id_almacen, id_recurso),
        ).fetchone()
        return fila[0] if fila else 0

    def fn_total_donaciones_proyecto(self, id_proyecto):
        return self.conn.execute(
            """
            SELECT COALESCE(SUM(monto), 0)
            FROM donacion
            WHERE id_proyecto = ?
            """,
            (id_proyecto,),
        ).fetchone()[0]

    def fn_total_gastos_proyecto(self, id_proyecto):
        return self.conn.execute(
            """
            SELECT COALESCE(SUM(g.monto), 0)
            FROM gasto g
            JOIN partida_presupuestal pp ON pp.id_partida = g.id_partida
            JOIN presupuesto pre ON pre.id_presupuesto = pp.id_presupuesto
            WHERE pre.id_proyecto = ?
            """,
            (id_proyecto,),
        ).fetchone()[0]

    def fn_saldo_presupuestal_proyecto(self, id_proyecto):
        presupuesto = self.conn.execute(
            """
            SELECT COALESCE(SUM(monto_total), 0)
            FROM presupuesto
            WHERE id_proyecto = ?
            """,
            (id_proyecto,),
        ).fetchone()[0]
        return presupuesto - self.fn_total_gastos_proyecto(id_proyecto)

    def fn_porcentaje_asistencia_voluntario(self, id_voluntario):
        total, asistio = self.conn.execute(
            """
            SELECT
                COUNT(*),
                COALESCE(SUM(CASE WHEN estado = 'Asistio' THEN 1 ELSE 0 END), 0)
            FROM participacion
            WHERE id_voluntario = ?
            """,
            (id_voluntario,),
        ).fetchone()

        if total == 0:
            return 0.0
        return round((asistio * 100) / total, 2)

    def reporte_resumen_proyecto(self, id_proyecto=None):
        sql = "SELECT * FROM vw_reporte_proyectos_resumen"
        params = ()
        if id_proyecto not in (None, ""):
            sql += " WHERE id_proyecto = ?"
            params = (id_proyecto,)
        sql += " ORDER BY id_proyecto"
        cur = self.conn.execute(sql, params)
        return filas_a_tabla(cur, cur.fetchall())

    def reporte_financiero_proyecto(self, id_proyecto=None):
        sql = "SELECT * FROM vw_reporte_financiero_proyecto"
        params = ()
        if id_proyecto not in (None, ""):
            sql += " WHERE id_proyecto = ?"
            params = (id_proyecto,)
        sql += " ORDER BY id_proyecto"
        cur = self.conn.execute(sql, params)
        return filas_a_tabla(cur, cur.fetchall())

    def reporte_participacion_voluntarios(self):
        cur = self.conn.execute(
            """
            SELECT *
            FROM vw_reporte_participacion_voluntarios
            ORDER BY voluntario
            """
        )
        return filas_a_tabla(cur, cur.fetchall())


class InventarioService:
    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn

    def registrar_inventario_inicial(
        self, id_almacen, id_recurso, cantidad_actual, cantidad_minima
    ):
        if cantidad_actual < 0 or cantidad_minima < 0:
            raise ValueError("Las cantidades de inventario no pueden ser negativas")

        self.conn.execute(
            """
            INSERT INTO inventario (
                id_almacen,
                id_recurso,
                cantidad_actual,
                cantidad_minima
            )
            VALUES (?, ?, ?, ?)
            ON CONFLICT(id_almacen, id_recurso)
            DO UPDATE SET
                cantidad_actual = excluded.cantidad_actual,
                cantidad_minima = excluded.cantidad_minima
            """,
            (id_almacen, id_recurso, cantidad_actual, cantidad_minima),
        )
        self.conn.commit()

    def kardex_recurso(self, id_recurso, fecha_inicio, fecha_fin):
        cur = self.conn.execute(
            """
            SELECT
                fecha,
                tipo_movimiento,
                almacen_origen,
                almacen_destino,
                recurso,
                unidad_medida,
                cantidad,
                proveedor,
                actividad,
                descripcion
            FROM vw_reporte_movimientos_recursos
            WHERE id_recurso = ?
              AND fecha BETWEEN ? AND ?
            ORDER BY fecha, tipo_movimiento
            """,
            (id_recurso, fecha_inicio, fecha_fin),
        )
        return filas_a_tabla(cur, cur.fetchall())

    def aplicar_movimiento_inventario(
        self, id_movimiento, id_recurso, cantidad, revertir=False
    ):
        if cantidad <= 0:
            raise ValueError("La cantidad del movimiento debe ser mayor a cero")

        cur = self.conn.cursor()
        fila = cur.execute(
            """
            SELECT tipo_movimiento, id_almacen_origen, id_almacen_destino
            FROM movimiento
            WHERE id_movimiento = ?
            """,
            (id_movimiento,),
        ).fetchone()

        if not fila:
            raise ValueError("El movimiento indicado no existe")

        tipo, origen, destino = fila

        def stock(almacen):
            fila_stock = cur.execute(
                """
                SELECT COALESCE(cantidad_actual, 0)
                FROM inventario
                WHERE id_almacen = ? AND id_recurso = ?
                """,
                (almacen, id_recurso),
            ).fetchone()
            return fila_stock[0] if fila_stock else 0

        def mover(almacen, delta):
            cur.execute(
                """
                INSERT INTO inventario (
                    id_almacen,
                    id_recurso,
                    cantidad_actual,
                    cantidad_minima
                )
                VALUES (?, ?, ?, 0)
                ON CONFLICT(id_almacen, id_recurso)
                DO UPDATE SET cantidad_actual = cantidad_actual + excluded.cantidad_actual
                """,
                (almacen, id_recurso, delta),
            )

        operaciones = []
        if tipo == "Entrada Compra":
            operaciones = [(destino, -cantidad if revertir else cantidad)]
        elif tipo == "Salida Actividad":
            operaciones = [(origen, cantidad if revertir else -cantidad)]
        elif tipo == "Transferencia":
            operaciones = (
                [(destino, -cantidad), (origen, cantidad)]
                if revertir
                else [(origen, -cantidad), (destino, cantidad)]
            )
        elif tipo == "Ajuste Inventario":
            almacen = destino if destino is not None else origen
            signo = 1 if destino is not None else -1
            operaciones = [(almacen, -signo * cantidad if revertir else signo * cantidad)]
        else:
            raise ValueError(f"Tipo de movimiento no soportado: {tipo}")

        try:
            for almacen, delta in operaciones:
                if almacen is None:
                    raise ValueError("El movimiento no tiene almacen valido")
                if delta < 0 and stock(almacen) < abs(delta):
                    raise ValueError("Stock insuficiente para aplicar el movimiento")
                mover(almacen, delta)
            self.conn.commit()
        except Exception:
            self.conn.rollback()
            raise


class SqliteExplorer:
    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn

    def listar_objetos(self, tipo=None):
        sql = """
            SELECT type, name
            FROM sqlite_master
            WHERE type IN ('table', 'view')
              AND name NOT LIKE 'sqlite_%'
        """
        params = ()
        if tipo:
            sql += " AND type = ?"
            params = (tipo,)
        sql += " ORDER BY type, name"
        return [(fila["type"], fila["name"]) for fila in self.conn.execute(sql, params)]

    def listar_vistas_reporte(self):
        return [nombre for tipo, nombre in self.listar_objetos("view") if nombre.startswith("vw_")]

    def validar_objeto(self, nombre):
        fila = self.conn.execute(
            """
            SELECT name
            FROM sqlite_master
            WHERE type IN ('table', 'view')
              AND name = ?
              AND name NOT LIKE 'sqlite_%'
            """,
            (nombre,),
        ).fetchone()
        if not fila:
            raise ValueError("La tabla o vista seleccionada no existe")

    def consultar_objeto(self, nombre, limite=300):
        self.validar_objeto(nombre)
        limite = max(1, min(int(limite), 1000))
        nombre_seguro = nombre_sql(nombre)
        cur = self.conn.execute(f"SELECT * FROM {nombre_seguro} LIMIT ?", (limite,))
        return filas_a_tabla(cur, cur.fetchall())

    def ejecutar_sql(self, sql):
        sql = sql.strip()
        if not sql:
            raise ValueError("Escribe una consulta o sentencia SQL")

        try:
            cur = self.conn.cursor()
            cur.execute(sql)
            if cur.description:
                filas = cur.fetchall()
                return filas_a_tabla(cur, filas), f"{len(filas)} fila(s)"
            self.conn.commit()
            return ([], []), f"OK. Filas afectadas: {cur.rowcount}"
        except sqlite3.ProgrammingError as error:
            if "You can only execute one statement" not in str(error):
                raise
            self.conn.executescript(sql)
            self.conn.commit()
            return ([], []), "Script ejecutado correctamente"
        except Exception:
            self.conn.rollback()
            raise


class MantenimientoTablas:
    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn

    def listar_tablas(self):
        return [nombre for _, nombre in SqliteExplorer(self.conn).listar_objetos("table")]

    def columnas(self, tabla):
        self.validar_tabla(tabla)
        filas = self.conn.execute(f"PRAGMA table_info({nombre_sql(tabla)})").fetchall()
        return [
            {
                "cid": fila["cid"],
                "name": fila["name"],
                "type": fila["type"],
                "notnull": bool(fila["notnull"]),
                "default": fila["dflt_value"],
                "pk": fila["pk"],
            }
            for fila in filas
        ]

    def claves_primarias(self, tabla):
        return [col["name"] for col in self.columnas(tabla) if col["pk"]]

    def claves_foraneas(self, tabla):
        self.validar_tabla(tabla)
        filas = self.conn.execute(f"PRAGMA foreign_key_list({nombre_sql(tabla)})").fetchall()
        return [
            {
                "id": fila["id"],
                "seq": fila["seq"],
                "table": fila["table"],
                "from": fila["from"],
                "to": fila["to"],
                "on_update": fila["on_update"],
                "on_delete": fila["on_delete"],
            }
            for fila in filas
        ]

    def validar_tabla(self, tabla):
        fila = self.conn.execute(
            """
            SELECT name
            FROM sqlite_master
            WHERE type = 'table'
              AND name = ?
              AND name NOT LIKE 'sqlite_%'
            """,
            (tabla,),
        ).fetchone()
        if not fila:
            raise ValueError("La tabla seleccionada no existe")

    def consultar(self, tabla, limite=300):
        self.validar_tabla(tabla)
        limite = max(1, min(int(limite), 1000))
        cur = self.conn.execute(f"SELECT * FROM {nombre_sql(tabla)} LIMIT ?", (limite,))
        return filas_a_tabla(cur, cur.fetchall())

    def insertar(self, tabla, valores):
        columnas = self.columnas(tabla)
        self._validar_foraneas(tabla, valores)
        valores_limpios = self._preparar_valores_insert(columnas, valores)
        if not valores_limpios:
            raise ValueError("No hay valores para insertar")

        nombres = list(valores_limpios.keys())
        placeholders = ", ".join("?" for _ in nombres)
        sql = (
            f"INSERT INTO {nombre_sql(tabla)} "
            f"({', '.join(nombre_sql(nombre) for nombre in nombres)}) "
            f"VALUES ({placeholders})"
        )
        try:
            self.conn.execute(sql, tuple(valores_limpios[nombre] for nombre in nombres))
            self.conn.commit()
        except sqlite3.IntegrityError as error:
            self.conn.rollback()
            raise ValueError(self._mensaje_integridad(tabla, valores_limpios, error)) from error

    def actualizar(self, tabla, valores, pk_original):
        columnas = self.columnas(tabla)
        pk_cols = self.claves_primarias(tabla)
        if not pk_cols:
            raise ValueError("Esta tabla no tiene clave primaria para ubicar la fila")
        if any(pk_original.get(pk) in (None, "") for pk in pk_cols):
            raise ValueError("Selecciona primero una fila valida")

        self._validar_foraneas(tabla, valores)
        valores_limpios = self._preparar_valores_update(columnas, valores)
        set_cols = list(valores_limpios)
        if not set_cols:
            raise ValueError("No hay columnas editables para actualizar")

        sql = (
            f"UPDATE {nombre_sql(tabla)} SET "
            + ", ".join(f"{nombre_sql(col)} = ?" for col in set_cols)
            + " WHERE "
            + " AND ".join(f"{nombre_sql(pk)} = ?" for pk in pk_cols)
        )
        params = [valores_limpios[col] for col in set_cols] + [pk_original[pk] for pk in pk_cols]
        try:
            cur = self.conn.execute(sql, params)
            self.conn.commit()
        except sqlite3.IntegrityError as error:
            self.conn.rollback()
            raise ValueError(self._mensaje_integridad(tabla, valores_limpios, error)) from error
        if cur.rowcount == 0:
            raise ValueError("No se encontro la fila seleccionada para actualizar")

    def eliminar(self, tabla, pk_original):
        pk_cols = self.claves_primarias(tabla)
        if not pk_cols:
            raise ValueError("Esta tabla no tiene clave primaria para eliminar filas con seguridad")
        if any(pk_original.get(pk) in (None, "") for pk in pk_cols):
            raise ValueError("Selecciona primero una fila valida")

        sql = (
            f"DELETE FROM {nombre_sql(tabla)} WHERE "
            + " AND ".join(f"{nombre_sql(pk)} = ?" for pk in pk_cols)
        )
        try:
            cur = self.conn.execute(sql, tuple(pk_original[pk] for pk in pk_cols))
            self.conn.commit()
        except sqlite3.IntegrityError as error:
            self.conn.rollback()
            detalle = self._dependencias_hijas(tabla, pk_original)
            if detalle:
                raise ValueError(
                    "No se puede eliminar porque otros registros dependen de esta fila:\n"
                    + "\n".join(detalle)
                ) from error
            raise ValueError(self._mensaje_integridad(tabla, pk_original, error)) from error
        if cur.rowcount == 0:
            raise ValueError("No se encontro la fila seleccionada para eliminar")

    def _preparar_valores_insert(self, columnas, valores):
        resultado = {}
        pk_autoincremental = self._pk_entero_unico(columnas)
        for col in columnas:
            nombre = col["name"]
            valor = self._normalizar_valor(valores.get(nombre))
            if nombre == pk_autoincremental and valor is None:
                continue
            if valor is None and col["default"] is not None:
                continue
            resultado[nombre] = valor
        return resultado

    def _preparar_valores_update(self, columnas, valores):
        return {col["name"]: self._normalizar_valor(valores.get(col["name"])) for col in columnas}

    def _normalizar_valor(self, valor):
        if valor is None:
            return None
        if isinstance(valor, str) and valor.strip() == "":
            return None
        return valor

    def _pk_entero_unico(self, columnas):
        pk_cols = [col for col in columnas if col["pk"]]
        if len(pk_cols) == 1 and "INT" in (pk_cols[0]["type"] or "").upper():
            return pk_cols[0]["name"]
        return None

    def _validar_foraneas(self, tabla, valores):
        faltantes = []
        for fk in self.claves_foraneas(tabla):
            valor = self._normalizar_valor(valores.get(fk["from"]))
            if valor is None:
                continue
            ref_col = fk["to"] or self.claves_primarias(fk["table"])[0]
            existe = self.conn.execute(
                f"SELECT 1 FROM {nombre_sql(fk['table'])} "
                f"WHERE {nombre_sql(ref_col)} = ? LIMIT 1",
                (valor,),
            ).fetchone()
            if not existe:
                faltantes.append(
                    f"{fk['from']}={valor} necesita existir en "
                    f"{fk['table']}.{ref_col}"
                )
        if faltantes:
            raise ValueError("Faltan registros relacionados:\n" + "\n".join(faltantes))

    def _dependencias_hijas(self, tabla, pk_original):
        dependencias = []
        for hija in self.listar_tablas():
            for fk in self.claves_foraneas(hija):
                if fk["table"] != tabla:
                    continue
                ref_col = fk["to"] or self.claves_primarias(tabla)[0]
                if ref_col not in pk_original:
                    continue
                total = self.conn.execute(
                    f"SELECT COUNT(*) FROM {nombre_sql(hija)} "
                    f"WHERE {nombre_sql(fk['from'])} = ?",
                    (pk_original[ref_col],),
                ).fetchone()[0]
                if total:
                    dependencias.append(f"{hija}.{fk['from']}: {total} registro(s)")
        return dependencias

    def _mensaje_integridad(self, tabla, valores, error):
        texto = str(error)
        if "FOREIGN KEY constraint failed" in texto:
            return (
                "No se pudo guardar por una clave foranea. Revisa que los IDs "
                "relacionados existan antes de insertar o modificar."
            )
        if "NOT NULL constraint failed" in texto:
            return "Hay campos obligatorios vacios: " + texto.replace("NOT NULL constraint failed: ", "")
        if "UNIQUE constraint failed" in texto:
            return "Ya existe un registro con esos valores unicos: " + texto.replace(
                "UNIQUE constraint failed: ", ""
            )
        if "CHECK constraint failed" in texto:
            return "Alguno de los valores no cumple las opciones permitidas: " + texto
        return f"Error de integridad en {tabla}: {texto}"
