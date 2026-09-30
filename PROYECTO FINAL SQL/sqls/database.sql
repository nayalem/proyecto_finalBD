PRAGMA foreign_keys = ON;

CREATE TABLE organizacion (
    id_organizacion INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL,
    tipo TEXT NOT NULL,
    direccion TEXT,
    correo TEXT
);

CREATE TABLE donante (
    id_donante INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL,

    tipo TEXT NOT NULL
    CHECK(tipo IN (
        'Persona',
        'Empresa',
        'ONG'
    )),

    telefono TEXT,
    correo TEXT
);

CREATE TABLE voluntario (
    id_voluntario INTEGER
    PRIMARY KEY AUTOINCREMENT,

    nombres TEXT NOT NULL,
    apellidos TEXT NOT NULL,

    dni TEXT UNIQUE NOT NULL,

    fecha_nacimiento DATE NOT NULL,
    telefono TEXT,
    correo TEXT,
    direccion TEXT,

    fecha_registro DATE NOT NULL,

    estado TEXT DEFAULT 'Activo'
    CHECK(estado IN (
        'Activo',
        'Inactivo'
    ))
);

CREATE TABLE proveedor (
    id_proveedor INTEGER
    PRIMARY KEY AUTOINCREMENT,

    nombre TEXT NOT NULL,
    telefono TEXT,
    correo TEXT,
    direccion TEXT
);

CREATE TABLE recurso (
    id_recurso INTEGER
    PRIMARY KEY AUTOINCREMENT,

    nombre TEXT NOT NULL,
    descripcion TEXT,
    tipo TEXT,
    unidad_medida TEXT NOT NULL
);

CREATE TABLE almacen (
    id_almacen INTEGER
    PRIMARY KEY AUTOINCREMENT,

    nombre TEXT NOT NULL,
    ubicacion TEXT,
    descripcion TEXT
);


CREATE TABLE proyecto (
    id_proyecto INTEGER
    PRIMARY KEY AUTOINCREMENT,

    nombre TEXT NOT NULL,
    descripcion TEXT,

    fecha_inicio DATE NOT NULL,
    fecha_fin DATE,

    estado TEXT DEFAULT 'Activo'
    CHECK(estado IN (
        'Activo',
        'Finalizado',
        'Suspendido'
    )),

    id_organizacion INTEGER NOT NULL,

    FOREIGN KEY (id_organizacion)
    REFERENCES organizacion(id_organizacion)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
);

CREATE TABLE presupuesto (
    id_presupuesto INTEGER
    PRIMARY KEY AUTOINCREMENT,

    monto_total REAL NOT NULL,
    periodo TEXT,

    id_proyecto INTEGER NOT NULL,

    FOREIGN KEY (id_proyecto)
    REFERENCES proyecto(id_proyecto)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
);

CREATE TABLE actividad (
    id_actividad INTEGER
    PRIMARY KEY AUTOINCREMENT,

    nombre TEXT NOT NULL,
    descripcion TEXT,

    fecha DATE NOT NULL,
    cupo_maximo INTEGER,

    id_proyecto INTEGER NOT NULL,

    FOREIGN KEY (id_proyecto)
    REFERENCES proyecto(id_proyecto)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
);

CREATE TABLE donacion (
    id_donacion INTEGER
    PRIMARY KEY AUTOINCREMENT,

    fecha DATE NOT NULL,
    monto REAL NOT NULL,
    descripcion TEXT,

    id_proyecto INTEGER NOT NULL,
    id_donante INTEGER NOT NULL,

    FOREIGN KEY (id_proyecto)
    REFERENCES proyecto(id_proyecto),

    FOREIGN KEY (id_donante)
    REFERENCES donante(id_donante)
);

CREATE TABLE movimiento (
    id_movimiento INTEGER
    PRIMARY KEY AUTOINCREMENT,

    tipo_movimiento TEXT NOT NULL
    CHECK(tipo_movimiento IN (
        'Entrada Compra',
        'Salida Actividad',
        'Transferencia',
        'Ajuste Inventario'
    )),

    fecha DATE NOT NULL,
    descripcion TEXT,

    id_proveedor INTEGER,

    id_almacen_origen INTEGER,
    id_almacen_destino INTEGER,
    id_actividad INTEGER,

    FOREIGN KEY (id_proveedor)
    REFERENCES proveedor(id_proveedor)
    ON DELETE SET NULL
    ON UPDATE CASCADE,

    FOREIGN KEY (id_almacen_origen)
    REFERENCES almacen(id_almacen)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,

    FOREIGN KEY (id_almacen_destino)
    REFERENCES almacen(id_almacen)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,

    FOREIGN KEY (id_actividad)
    REFERENCES actividad(id_actividad)
    ON DELETE SET NULL
    ON UPDATE CASCADE
);

CREATE TABLE partida_presupuestal (
    id_partida INTEGER
    PRIMARY KEY AUTOINCREMENT,

    nombre TEXT NOT NULL,
    descripcion TEXT,
    monto_asignado REAL NOT NULL,

    id_presupuesto INTEGER NOT NULL,

    FOREIGN KEY (id_presupuesto)
    REFERENCES presupuesto(id_presupuesto)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
);

CREATE TABLE participacion (
    id_participacion INTEGER
    PRIMARY KEY AUTOINCREMENT,

    fecha DATE NOT NULL,

    estado TEXT NOT NULL
    DEFAULT 'Pendiente'
    CHECK(
        estado IN (
            'Asistio',
            'Ausente',
            'Pendiente'
        )
    ),

    id_actividad INTEGER NOT NULL,
    id_voluntario INTEGER NOT NULL,

    FOREIGN KEY (id_actividad)
    REFERENCES actividad(id_actividad),

    FOREIGN KEY (id_voluntario)
    REFERENCES voluntario(id_voluntario),

    UNIQUE (
        id_actividad,
        id_voluntario
    )
);

CREATE TABLE inventario (

    id_almacen INTEGER NOT NULL,
    id_recurso INTEGER NOT NULL,

    cantidad_actual INTEGER DEFAULT 0,
    cantidad_minima INTEGER DEFAULT 0,

    PRIMARY KEY (
        id_almacen,
        id_recurso
    ),

    FOREIGN KEY (id_almacen)
    REFERENCES almacen(id_almacen),

    FOREIGN KEY (id_recurso)
    REFERENCES recurso(id_recurso)
);

CREATE TABLE detalle_movimiento (

    id_movimiento INTEGER NOT NULL,
    id_recurso INTEGER NOT NULL,

    cantidad INTEGER NOT NULL,

    PRIMARY KEY (
        id_movimiento,
        id_recurso
    ),

    FOREIGN KEY (id_movimiento)
    REFERENCES movimiento(id_movimiento),

    FOREIGN KEY (id_recurso)
    REFERENCES recurso(id_recurso)
);

CREATE TABLE gasto (
    id_gasto INTEGER
    PRIMARY KEY AUTOINCREMENT,

    fecha DATE NOT NULL,
    monto REAL NOT NULL,
    descripcion TEXT,

    id_movimiento INTEGER,
    id_partida INTEGER NOT NULL,

    FOREIGN KEY (id_movimiento)
    REFERENCES movimiento(id_movimiento)
    ON DELETE SET NULL,

    FOREIGN KEY (id_partida)
    REFERENCES partida_presupuestal(id_partida)
);

CREATE TABLE comprobante (
    id_comprobante INTEGER
    PRIMARY KEY AUTOINCREMENT,

    tipo TEXT NOT NULL
    CHECK(
        tipo IN (
            'Factura',
            'Boleta',
            'Recibo'
        )
    ),

    numero TEXT NOT NULL,
    fecha DATE NOT NULL,

    id_gasto INTEGER NOT NULL,

    FOREIGN KEY (id_gasto)
    REFERENCES gasto(id_gasto)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,

    UNIQUE (
        tipo,
        numero
    )
);