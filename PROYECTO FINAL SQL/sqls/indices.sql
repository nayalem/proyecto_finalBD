PRAGMA foreign_keys = ON;

CREATE INDEX IF NOT EXISTS idx_proyecto_organizacion_estado
    ON proyecto (id_organizacion, estado);

CREATE INDEX IF NOT EXISTS idx_actividad_proyecto_fecha
    ON actividad (id_proyecto, fecha);

CREATE INDEX IF NOT EXISTS idx_participacion_voluntario_estado
    ON participacion (id_voluntario, estado);

CREATE INDEX IF NOT EXISTS idx_donacion_proyecto_fecha
    ON donacion (id_proyecto, fecha);

CREATE INDEX IF NOT EXISTS idx_presupuesto_proyecto
    ON presupuesto (id_proyecto);

CREATE INDEX IF NOT EXISTS idx_partida_presupuesto
    ON partida_presupuestal (id_presupuesto);

CREATE INDEX IF NOT EXISTS idx_gasto_partida_fecha
    ON gasto (id_partida, fecha);

CREATE INDEX IF NOT EXISTS idx_movimiento_fecha_tipo
    ON movimiento (fecha, tipo_movimiento);

CREATE INDEX IF NOT EXISTS idx_movimiento_almacenes
    ON movimiento (id_almacen_origen, id_almacen_destino);

CREATE INDEX IF NOT EXISTS idx_detalle_recurso
    ON detalle_movimiento (id_recurso);

CREATE INDEX IF NOT EXISTS idx_inventario_recurso
    ON inventario (id_recurso);