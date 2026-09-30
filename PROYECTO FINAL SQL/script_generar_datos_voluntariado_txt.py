import argparse
import csv
import random
from datetime import date, timedelta
from pathlib import Path


NULL_TOKEN = r"\N"
SEPARADOR = "|"


def opcional(valor, prob_null=0.18):
    return None if random.random() < prob_null else valor


def fecha_aleatoria(inicio, fin):
    dias = (fin - inicio).days
    return inicio + timedelta(days=random.randint(0, dias))


def partir_monto(total, partes):
    pesos = [random.uniform(0.7, 1.5) for _ in range(partes)]
    suma = sum(pesos)
    montos = [round(total * peso / suma, 2) for peso in pesos]
    diferencia = round(total - sum(montos), 2)
    montos[-1] = round(montos[-1] + diferencia, 2)
    return montos


def escribir_tabla(archivo, nombre, columnas, filas):
    archivo.write(f"@TABLE {nombre}\n")
    archivo.write("@COLUMNS " + SEPARADOR.join(columnas) + "\n")
    writer = csv.writer(
        archivo,
        delimiter=SEPARADOR,
        lineterminator="\n",
        quoting=csv.QUOTE_MINIMAL,
    )
    for fila in filas:
        writer.writerow([NULL_TOKEN if valor is None else valor for valor in fila])
    archivo.write("@END\n\n")


def generar_datos():
    datos = {}

    organizaciones = [
        "Manos Unidas Peru",
        "Red Solidaria Andina",
        "Fundacion Nuevo Horizonte",
        "Ayuda Verde",
        "Voluntarios del Norte",
        "Comunidad Esperanza",
        "Puentes de Barrio",
        "Sonrisas del Sur",
        "Jovenes en Accion",
        "Red de Apoyo Familiar",
        "Brigada Humanitaria Lima",
        "Semillas de Futuro",
    ]
    datos["organizacion"] = [
        (
            i,
            nombre,
            random.choice(["ONG", "Municipalidad", "Asociacion", "Fundacion"]),
            opcional(random.choice(["Lima", "Arequipa", "Trujillo", "Cusco", "Piura"]) + f" {100 + i}"),
            opcional(f"contacto{i}@voluntariado.org"),
        )
        for i, nombre in enumerate(organizaciones, start=1)
    ]

    nombres = [
        "Ana",
        "Luis",
        "Maria",
        "Carlos",
        "Rosa",
        "Miguel",
        "Lucia",
        "Jorge",
        "Valeria",
        "Diego",
        "Sofia",
        "Pedro",
        "Elena",
        "Raul",
        "Camila",
        "Andrea",
        "Fernando",
        "Patricia",
        "Oscar",
        "Gabriela",
        "Hector",
        "Daniela",
        "Ricardo",
        "Fiorella",
        "Bruno",
        "Natalia",
        "Alonso",
    ]
    apellidos = [
        "Quispe",
        "Flores",
        "Garcia",
        "Torres",
        "Rojas",
        "Mendoza",
        "Castillo",
        "Vargas",
        "Chavez",
        "Paredes",
        "Salazar",
        "Medina",
        "Cruz",
        "Herrera",
        "Silva",
        "Navarro",
        "Campos",
        "Reyes",
        "Aguilar",
        "Sanchez",
    ]

    datos["donante"] = []
    for i in range(1, 46):
        tipo = random.choice(["Persona", "Empresa", "ONG"])
        if tipo == "Persona":
            nombre = f"{random.choice(nombres)} {random.choice(apellidos)}"
        else:
            nombre = random.choice(
                [
                    "Inversiones Sol",
                    "BioAndes",
                    "Textiles Lima",
                    "AgroNorte",
                    "Clinica Vida",
                    "Constructora Pacifico",
                    "Farmacias Buen Salud",
                    "Transportes Ruta Sur",
                    "Panaderia La Union",
                    "Cooperativa Santa Rosa",
                    "Editorial Horizonte",
                ]
            ) + f" {i}"
        datos["donante"].append(
            (
                i,
                nombre,
                tipo,
                opcional(f"9{random.randint(10000000, 99999999)}"),
                opcional(f"donante{i}@correo.pe"),
            )
        )

    datos["voluntario"] = []
    distritos = [
        "Lima",
        "Callao",
        "Ate",
        "Surco",
        "Comas",
        "San Miguel",
        "Los Olivos",
        "Villa Maria",
        "Chorrillos",
        "Rimac",
        "El Agustino",
        "La Molina",
    ]
    for i in range(1, 91):
        nombre = random.choice(nombres)
        apellido = random.choice(apellidos)
        nacimiento = fecha_aleatoria(date(1975, 1, 1), date(2011, 12, 31))
        registro = fecha_aleatoria(date(2023, 1, 1), date(2026, 6, 1))
        datos["voluntario"].append(
            (
                i,
                nombre,
                apellido,
                f"{70000000 + i}",
                nacimiento.isoformat(),
                opcional(f"9{random.randint(10000000, 99999999)}"),
                opcional(f"{nombre.lower()}.{apellido.lower()}{i}@mail.pe"),
                opcional(random.choice(distritos) + f" {i}"),
                registro.isoformat(),
                random.choices(["Activo", "Inactivo"], weights=[86, 14])[0],
            )
        )

    datos["proveedor"] = []
    for i in range(1, 21):
        nombre = random.choice(
            [
                "Distribuidora San Miguel",
                "Suministros Andinos",
                "Comercial Esperanza",
                "Logistica Peru",
                "Importadora Nuevo Mundo",
                "Abarrotes La Merced",
                "Tecnicas de Campo",
                "Materiales Unidos",
                "Ferreteria Central",
            ]
        )
        datos["proveedor"].append(
            (
                i,
                f"{nombre} {i}",
                opcional(f"01-{random.randint(2000000, 7999999)}"),
                opcional(f"ventas{i}@proveedor.pe"),
                opcional(random.choice(["Lima", "Arequipa", "Chiclayo", "Huancayo"]) + f" {i}"),
            )
        )

    recursos_base = [
        ("Agua embotellada", "Alimento", "caja"),
        ("Arroz", "Alimento", "kg"),
        ("Leche evaporada", "Alimento", "lata"),
        ("Mantas", "Abrigo", "unidad"),
        ("Botiquin", "Salud", "unidad"),
        ("Mascarillas", "Salud", "caja"),
        ("Guantes", "Salud", "caja"),
        ("Cuadernos", "Educacion", "paquete"),
        ("Lapiceros", "Educacion", "caja"),
        ("Carpas", "Emergencia", "unidad"),
        ("Linternas", "Emergencia", "unidad"),
        ("Pilas", "Emergencia", "paquete"),
        ("Pintura", "Construccion", "galon"),
        ("Brochas", "Construccion", "unidad"),
        ("Bolsas reciclables", "Ambiente", "paquete"),
        ("Plantones", "Ambiente", "unidad"),
        ("Jabon liquido", "Higiene", "litro"),
        ("Toallas", "Higiene", "unidad"),
        ("Alcohol gel", "Higiene", "litro"),
        ("Cepillos dentales", "Higiene", "paquete"),
        ("Papel higienico", "Higiene", "paquete"),
        ("Fideos", "Alimento", "kg"),
        ("Aceite vegetal", "Alimento", "litro"),
        ("Conservas", "Alimento", "lata"),
        ("Zapatos escolares", "Educacion", "par"),
        ("Mochilas", "Educacion", "unidad"),
        ("Sillas plegables", "Logistica", "unidad"),
        ("Mesas plegables", "Logistica", "unidad"),
        ("Megafonos", "Logistica", "unidad"),
        ("Casacas", "Abrigo", "unidad"),
        ("Colchonetas", "Emergencia", "unidad"),
        ("Baldes", "Emergencia", "unidad"),
        ("Escobas", "Ambiente", "unidad"),
        ("Bolsas de basura", "Ambiente", "paquete"),
    ]
    datos["recurso"] = [
        (i, nombre, opcional(f"Recurso usado en campanias de {tipo.lower()}"), tipo, unidad)
        for i, (nombre, tipo, unidad) in enumerate(recursos_base, start=1)
    ]

    almacenes = [
        ("Almacen Central", "Lima Centro"),
        ("Deposito Norte", "Los Olivos"),
        ("Deposito Sur", "Villa El Salvador"),
        ("Base Emergencias", "Ate"),
        ("Centro Comunitario", "San Juan de Lurigancho"),
        ("Modulo Callao", "Callao"),
        ("Almacen Este", "Santa Anita"),
        ("Punto de Acopio Ambiental", "Chorrillos"),
    ]
    datos["almacen"] = [
        (i, nombre, ubicacion, opcional(f"Espacio logistico ubicado en {ubicacion}"))
        for i, (nombre, ubicacion) in enumerate(almacenes, start=1)
    ]

    proyectos = [
        "Campania de abrigo",
        "Alimentos para familias",
        "Salud comunitaria",
        "Reforestacion urbana",
        "Apoyo escolar",
        "Respuesta ante emergencias",
        "Jornadas de limpieza",
        "Comedores solidarios",
        "Agua segura",
        "Acompanamiento adulto mayor",
        "Kits escolares para ninos",
        "Salud preventiva barrial",
        "Reciclaje comunitario",
        "Mejoramiento de espacios publicos",
        "Brigadas contra el frio",
        "Atencion a familias migrantes",
    ]
    datos["proyecto"] = []
    for i, nombre in enumerate(proyectos, start=1):
        inicio = fecha_aleatoria(date(2024, 1, 1), date(2026, 3, 1))
        estado = random.choices(["Activo", "Finalizado", "Suspendido"], weights=[65, 25, 10])[0]
        fin = None if estado == "Activo" else (inicio + timedelta(days=random.randint(60, 420))).isoformat()
        datos["proyecto"].append(
            (
                i,
                nombre,
                opcional(f"Proyecto social enfocado en {nombre.lower()}"),
                inicio.isoformat(),
                fin,
                estado,
                random.randint(1, len(datos["organizacion"])),
            )
        )

    datos["presupuesto"] = []
    datos["partida_presupuestal"] = []
    id_partida = 1
    partidas_por_presupuesto = {}
    for i, proyecto in enumerate(datos["proyecto"], start=1):
        monto_total = round(random.uniform(8000, 45000), 2)
        datos["presupuesto"].append((i, monto_total, f"Periodo {random.choice(['2024', '2025', '2026'])}", proyecto[0]))
        nombres_partida = ["Logistica", "Compras", "Transporte", "Materiales"]
        monto_asignable = round(monto_total * random.uniform(0.86, 0.95), 2)
        montos = partir_monto(monto_asignable, len(nombres_partida))
        partidas_por_presupuesto[i] = []
        for nombre_partida, monto in zip(nombres_partida, montos):
            datos["partida_presupuestal"].append(
                (id_partida, nombre_partida, opcional(f"Partida para {nombre_partida.lower()}"), monto, i)
            )
            partidas_por_presupuesto[i].append((id_partida, monto))
            id_partida += 1

    datos["actividad"] = []
    id_actividad = 1
    actividades_por_proyecto = {}
    for proyecto in datos["proyecto"]:
        cantidad = random.randint(4, 8)
        actividades_por_proyecto[proyecto[0]] = []
        for n in range(cantidad):
            actividad = random.choice(
                [
                    "Entrega de recursos",
                    "Registro de beneficiarios",
                    "Taller comunitario",
                    "Jornada de campo",
                    "Capacitacion de voluntarios",
                    "Visita domiciliaria",
                    "Campania informativa",
                    "Clasificacion de donaciones",
                    "Monitoreo de beneficiarios",
                    "Feria solidaria",
                ]
            )
            fecha = fecha_aleatoria(date(2024, 1, 10), date(2026, 12, 20))
            cupo = random.randint(8, 24)
            datos["actividad"].append(
                (
                    id_actividad,
                    f"{actividad} {proyecto[0]}-{n + 1}",
                    opcional(f"Actividad del proyecto {proyecto[1]}"),
                    fecha.isoformat(),
                    cupo,
                    proyecto[0],
                )
            )
            actividades_por_proyecto[proyecto[0]].append(id_actividad)
            id_actividad += 1

    datos["donacion"] = []
    motivos_donacion = [
        "Donacion general",
        "Apoyo para compras",
        "Campania puntual",
        "Aporte corporativo",
        "Recaudacion vecinal",
        "Fondo de emergencia",
        "Apoyo mensual",
        "Donacion anonima",
        "Colecta escolar",
        "Campania digital",
    ]
    for i in range(1, 121):
        id_proyecto = random.randint(1, len(datos["proyecto"]))
        datos["donacion"].append(
            (
                i,
                fecha_aleatoria(date(2024, 1, 1), date(2026, 6, 1)).isoformat(),
                round(random.uniform(80, 6000), 2),
                opcional(random.choice(motivos_donacion)),
                id_proyecto,
                random.randint(1, len(datos["donante"])),
            )
        )

    datos["participacion"] = []
    id_participacion = 1
    voluntarios_activos = [v[0] for v in datos["voluntario"] if v[-1] == "Activo"]
    for actividad in datos["actividad"]:
        cupo = actividad[4] or 12
        inscritos = random.sample(voluntarios_activos, k=min(len(voluntarios_activos), random.randint(3, cupo)))
        for id_voluntario in inscritos:
            datos["participacion"].append(
                (
                    id_participacion,
                    actividad[3],
                    random.choices(["Asistio", "Ausente", "Pendiente"], weights=[70, 15, 15])[0],
                    actividad[0],
                    id_voluntario,
                )
            )
            id_participacion += 1

    datos["inventario"] = []
    for id_almacen in range(1, len(datos["almacen"]) + 1):
        for id_recurso in range(1, len(datos["recurso"]) + 1):
            cantidad_minima = random.randint(5, 30)
            cantidad_actual = random.randint(cantidad_minima, cantidad_minima + 180)
            if random.random() < 0.08:
                cantidad_actual = random.randint(0, cantidad_minima)
            datos["inventario"].append((id_almacen, id_recurso, cantidad_actual, cantidad_minima))

    datos["movimiento"] = []
    tipos = ["Entrada Compra", "Salida Actividad", "Transferencia", "Ajuste Inventario"]
    descripciones_movimiento = {
        "Entrada Compra": [
            "Compra programada para abastecimiento",
            "Ingreso por reposicion de stock",
            "Compra urgente para actividad",
            "Ingreso desde proveedor local",
        ],
        "Salida Actividad": [
            "Salida para jornada comunitaria",
            "Entrega directa a beneficiarios",
            "Consumo por actividad de campo",
            "Despacho para campania",
        ],
        "Transferencia": [
            "Reubicacion por demanda operativa",
            "Transferencia entre almacenes",
            "Redistribucion preventiva",
            "Apoyo logistico entre sedes",
        ],
        "Ajuste Inventario": [
            "Regularizacion por conteo fisico",
            "Ajuste por diferencia de almacen",
            "Correccion documentaria",
            "Ajuste por merma controlada",
        ],
    }
    for i in range(1, 141):
        tipo = random.choices(tipos, weights=[35, 28, 22, 15])[0]
        origen = destino = proveedor = actividad = None
        if tipo == "Entrada Compra":
            destino = random.randint(1, len(datos["almacen"]))
            proveedor = random.randint(1, len(datos["proveedor"]))
        elif tipo == "Salida Actividad":
            origen = random.randint(1, len(datos["almacen"]))
            actividad = random.choice(datos["actividad"])[0]
        elif tipo == "Transferencia":
            origen = random.randint(1, len(datos["almacen"]))
            destino = random.randint(1, len(datos["almacen"]))
            while destino == origen:
                destino = random.randint(1, len(datos["almacen"]))
        else:
            if random.random() < 0.5:
                destino = random.randint(1, len(datos["almacen"]))
            else:
                origen = random.randint(1, len(datos["almacen"]))
        datos["movimiento"].append(
            (
                i,
                tipo,
                fecha_aleatoria(date(2024, 1, 1), date(2026, 6, 1)).isoformat(),
                opcional(random.choice(descripciones_movimiento[tipo])),
                proveedor,
                origen,
                destino,
                actividad,
            )
        )

    datos["detalle_movimiento"] = []
    detalle_usado = set()
    for movimiento in datos["movimiento"]:
        recursos = random.sample(range(1, len(datos["recurso"]) + 1), k=random.randint(1, 3))
        for id_recurso in recursos:
            clave = (movimiento[0], id_recurso)
            if clave in detalle_usado:
                continue
            detalle_usado.add(clave)
            datos["detalle_movimiento"].append((movimiento[0], id_recurso, random.randint(1, 60)))

    datos["gasto"] = []
    gasto_por_partida = {partida[0]: 0.0 for partida in datos["partida_presupuestal"]}
    monto_partida = {partida[0]: partida[3] for partida in datos["partida_presupuestal"]}
    entradas_compra = [m[0] for m in datos["movimiento"] if m[1] == "Entrada Compra"]
    conceptos_gasto = [
        "Compra de recursos",
        "Movilidad",
        "Servicio logistico",
        "Materiales para taller",
        "Alquiler de equipo",
        "Impresion de materiales",
        "Transporte de donaciones",
        "Mantenimiento de almacen",
        "Implementos de seguridad",
        "Apoyo operativo",
    ]
    for i in range(1, 96):
        id_partida_sel = random.choice(list(monto_partida.keys()))
        saldo = monto_partida[id_partida_sel] - gasto_por_partida[id_partida_sel]
        if saldo <= 120:
            continue
        monto = round(random.uniform(50, min(1800, saldo * 0.45)), 2)
        gasto_por_partida[id_partida_sel] += monto
        datos["gasto"].append(
            (
                len(datos["gasto"]) + 1,
                fecha_aleatoria(date(2024, 1, 1), date(2026, 6, 1)).isoformat(),
                monto,
                opcional(random.choice(conceptos_gasto)),
                opcional(random.choice(entradas_compra), 0.35) if entradas_compra else None,
                id_partida_sel,
            )
        )

    datos["comprobante"] = []
    tipos_comprobante = ["Factura", "Boleta", "Recibo"]
    for gasto in datos["gasto"]:
        tipo = random.choice(tipos_comprobante)
        datos["comprobante"].append(
            (
                gasto[0],
                tipo,
                f"{tipo[0]}{random.randint(100, 999)}-{20240000 + gasto[0]}",
                gasto[1],
                gasto[0],
            )
        )

    return datos


ORDEN_TABLAS = [
    ("organizacion", ["id_organizacion", "nombre", "tipo", "direccion", "correo"]),
    ("donante", ["id_donante", "nombre", "tipo", "telefono", "correo"]),
    (
        "voluntario",
        [
            "id_voluntario",
            "nombres",
            "apellidos",
            "dni",
            "fecha_nacimiento",
            "telefono",
            "correo",
            "direccion",
            "fecha_registro",
            "estado",
        ],
    ),
    ("proveedor", ["id_proveedor", "nombre", "telefono", "correo", "direccion"]),
    ("recurso", ["id_recurso", "nombre", "descripcion", "tipo", "unidad_medida"]),
    ("almacen", ["id_almacen", "nombre", "ubicacion", "descripcion"]),
    (
        "proyecto",
        [
            "id_proyecto",
            "nombre",
            "descripcion",
            "fecha_inicio",
            "fecha_fin",
            "estado",
            "id_organizacion",
        ],
    ),
    ("presupuesto", ["id_presupuesto", "monto_total", "periodo", "id_proyecto"]),
    ("actividad", ["id_actividad", "nombre", "descripcion", "fecha", "cupo_maximo", "id_proyecto"]),
    ("donacion", ["id_donacion", "fecha", "monto", "descripcion", "id_proyecto", "id_donante"]),
    (
        "movimiento",
        [
            "id_movimiento",
            "tipo_movimiento",
            "fecha",
            "descripcion",
            "id_proveedor",
            "id_almacen_origen",
            "id_almacen_destino",
            "id_actividad",
        ],
    ),
    (
        "partida_presupuestal",
        ["id_partida", "nombre", "descripcion", "monto_asignado", "id_presupuesto"],
    ),
    ("participacion", ["id_participacion", "fecha", "estado", "id_actividad", "id_voluntario"]),
    ("inventario", ["id_almacen", "id_recurso", "cantidad_actual", "cantidad_minima"]),
    ("detalle_movimiento", ["id_movimiento", "id_recurso", "cantidad"]),
    ("gasto", ["id_gasto", "fecha", "monto", "descripcion", "id_movimiento", "id_partida"]),
    ("comprobante", ["id_comprobante", "tipo", "numero", "fecha", "id_gasto"]),
]


def main():
    parser = argparse.ArgumentParser(description="Genera datos aleatorios coherentes para voluntariado.db")
    parser.add_argument("--salida", default="datos_voluntariado_seed.txt")
    parser.add_argument("--seed", type=int, default=None)
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)
    else:
        random.seed()

    datos = generar_datos()
    salida = Path(args.salida)
    with salida.open("w", encoding="utf-8", newline="") as archivo:
        archivo.write("# VOLUNTARIADO_SEED_TXT v1\n")
        archivo.write(f"# SEPARADOR={SEPARADOR} NULL={NULL_TOKEN}\n")
        archivo.write("# Cada bloque declara tabla, columnas y filas en orden de insercion.\n\n")
        for tabla, columnas in ORDEN_TABLAS:
            escribir_tabla(archivo, tabla, columnas, datos[tabla])

    total_filas = sum(len(datos[tabla]) for tabla, _ in ORDEN_TABLAS)
    print(f"OK: generado {salida} con {total_filas} filas distribuidas en {len(ORDEN_TABLAS)} tablas.")


if __name__ == "__main__":
    main()
