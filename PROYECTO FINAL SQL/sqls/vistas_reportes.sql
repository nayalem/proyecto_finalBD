PRAGMA foreign_keys = ON;

DROP VIEW IF EXISTS vw_reporte_proyectos_resumen;

CREATE VIEW vw_reporte_proyectos_resumen AS
SELECT
    p.id_proyecto,
    p.nombre AS proyecto,
    p.estado,
    p.fecha_inicio,
    p.fecha_fin,
    o.nombre AS organizacion,
    COALESCE(a.total_actividades, 0) AS total_actividades,
    COALESCE(a.proximas_actividades, 0) AS proximas_actividades,
    COALESCE(pa.total_voluntarios, 0) AS voluntarios_vinculados,
    COALESCE(pa.asistencias, 0) AS asistencias_registradas,
    COALESCE(d.total_donaciones, 0) AS total_donaciones,
    COALESCE(pr.total_presupuestado, 0) AS total_presupuestado,
    COALESCE(g.total_gastado, 0) AS total_gastado,
    COALESCE(d.total_donaciones, 0) - COALESCE(g.total_gastado, 0) AS saldo_financiero,
    COALESCE(pr.total_presupuestado, 0) - COALESCE(g.total_gastado, 0) AS saldo_presupuestal
FROM proyecto p
JOIN organizacion o
    ON o.id_organizacion = p.id_organizacion
LEFT JOIN (
    SELECT
        id_proyecto,
        COUNT(*) AS total_actividades,
        SUM(
            CASE
                WHEN fecha >= CURRENT_DATE THEN 1
                ELSE 0
            END
        ) AS proximas_actividades
    FROM actividad
    GROUP BY id_proyecto
) a
    ON a.id_proyecto = p.id_proyecto
LEFT JOIN (
    SELECT
        ac.id_proyecto,
        COUNT(DISTINCT pa.id_voluntario) AS total_voluntarios,
        SUM(
            CASE
                WHEN pa.estado = 'Asistio' THEN 1
                ELSE 0
            END
        ) AS asistencias
    FROM actividad ac
    JOIN participacion pa
        ON pa.id_actividad = ac.id_actividad
    GROUP BY ac.id_proyecto
) pa
    ON pa.id_proyecto = p.id_proyecto
LEFT JOIN (
    SELECT
        id_proyecto,
        SUM(monto) AS total_donaciones
    FROM donacion
    GROUP BY id_proyecto
) d
    ON d.id_proyecto = p.id_proyecto
LEFT JOIN (
    SELECT
        id_proyecto,
        SUM(monto_total) AS total_presupuestado
    FROM presupuesto
    GROUP BY id_proyecto
) pr
    ON pr.id_proyecto = p.id_proyecto
LEFT JOIN (
    SELECT
        pre.id_proyecto,
        SUM(ga.monto) AS total_gastado
    FROM presupuesto pre
    JOIN partida_presupuestal pp
        ON pp.id_presupuesto = pre.id_presupuesto
    JOIN gasto ga
        ON ga.id_partida = pp.id_partida
    GROUP BY pre.id_proyecto
) g
    ON g.id_proyecto = p.id_proyecto;

DROP VIEW IF EXISTS vw_reporte_participacion_voluntarios;

CREATE VIEW vw_reporte_participacion_voluntarios AS
SELECT
    v.id_voluntario,
    v.nombres || ' ' || v.apellidos AS voluntario,
    v.dni,
    v.estado AS estado_voluntario,
    COUNT(pa.id_participacion) AS actividades_asignadas,
    SUM(
        CASE
            WHEN pa.estado = 'Asistio' THEN 1
            ELSE 0
        END
    ) AS asistencias,
    SUM(
        CASE
            WHEN pa.estado = 'Ausente' THEN 1
            ELSE 0
        END
    ) AS ausencias,
    SUM(
        CASE
            WHEN pa.estado = 'Pendiente' THEN 1
            ELSE 0
        END
    ) AS pendientes,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN pa.estado = 'Asistio' THEN 1
                ELSE 0
            END
        ) /
        NULLIF(COUNT(pa.id_participacion), 0),
        2
    ) AS porcentaje_asistencia
FROM voluntario v
LEFT JOIN participacion pa
    ON pa.id_voluntario = v.id_voluntario
GROUP BY
    v.id_voluntario,
    v.nombres,
    v.apellidos,
    v.dni,
    v.estado;

DROP VIEW IF EXISTS vw_reporte_cronograma_actividades;

CREATE VIEW vw_reporte_cronograma_actividades AS
SELECT
    ac.id_actividad,
    ac.nombre AS actividad,
    ac.fecha,
    ac.cupo_maximo,
    p.id_proyecto,
    p.nombre AS proyecto,
    o.nombre AS organizacion,
    COUNT(pa.id_participacion) AS voluntarios_inscritos,
    SUM(
        CASE
            WHEN pa.estado = 'Asistio' THEN 1
            ELSE 0
        END
    ) AS asistencias,
    MAX(
        COALESCE(ac.cupo_maximo, 0) -
        COUNT(pa.id_participacion),
        0
    ) AS cupos_disponibles
FROM actividad ac
JOIN proyecto p
    ON p.id_proyecto = ac.id_proyecto
JOIN organizacion o
    ON o.id_organizacion = p.id_organizacion
LEFT JOIN participacion pa
    ON pa.id_actividad = ac.id_actividad
GROUP BY
    ac.id_actividad,
    ac.nombre,
    ac.fecha,
    ac.cupo_maximo,
    p.id_proyecto,
    p.nombre,
    o.nombre;

DROP VIEW IF EXISTS vw_reporte_financiero_proyecto;

CREATE VIEW vw_reporte_financiero_proyecto AS
SELECT
    p.id_proyecto,
    p.nombre AS proyecto,
    COALESCE(d.total_donaciones, 0) AS total_donaciones,
    COALESCE(pr.total_presupuestado, 0) AS total_presupuestado,
    COALESCE(g.total_gastado, 0) AS total_gastado,
    COALESCE(d.total_donaciones, 0) - COALESCE(g.total_gastado, 0) AS saldo_caja_estimado,
    COALESCE(pr.total_presupuestado, 0) - COALESCE(g.total_gastado, 0) AS saldo_presupuestal
FROM proyecto p
LEFT JOIN (
    SELECT
        id_proyecto,
        SUM(monto) AS total_donaciones
    FROM donacion
    GROUP BY id_proyecto
) d
    ON d.id_proyecto = p.id_proyecto
LEFT JOIN (
    SELECT
        id_proyecto,
        SUM(monto_total) AS total_presupuestado
    FROM presupuesto
    GROUP BY id_proyecto
) pr
    ON pr.id_proyecto = p.id_proyecto
LEFT JOIN (
    SELECT
        pre.id_proyecto,
        SUM(ga.monto) AS total_gastado
    FROM presupuesto pre
    JOIN partida_presupuestal pp
        ON pp.id_presupuesto = pre.id_presupuesto
    JOIN gasto ga
        ON ga.id_partida = pp.id_partida
    GROUP BY pre.id_proyecto
) g
    ON g.id_proyecto = p.id_proyecto;

DROP VIEW IF EXISTS vw_reporte_gastos_por_partida;

CREATE VIEW vw_reporte_gastos_por_partida AS
SELECT
    pp.id_partida,
    pp.nombre AS partida,
    pp.monto_asignado,
    pre.id_presupuesto,
    pre.periodo,
    p.id_proyecto,
    p.nombre AS proyecto,
    COALESCE(SUM(g.monto), 0) AS total_gastado,
    pp.monto_asignado - COALESCE(SUM(g.monto), 0) AS saldo_partida,
    ROUND(
        100.0 * COALESCE(SUM(g.monto), 0) /
        NULLIF(pp.monto_asignado, 0),
        2
    ) AS porcentaje_ejecucion
FROM partida_presupuestal pp
JOIN presupuesto pre
    ON pre.id_presupuesto = pp.id_presupuesto
JOIN proyecto p
    ON p.id_proyecto = pre.id_proyecto
LEFT JOIN gasto g
    ON g.id_partida = pp.id_partida
GROUP BY
    pp.id_partida,
    pp.nombre,
    pp.monto_asignado,
    pre.id_presupuesto,
    pre.periodo,
    p.id_proyecto,
    p.nombre;

DROP VIEW IF EXISTS vw_reporte_inventario_actual;

CREATE VIEW vw_reporte_inventario_actual AS
SELECT
    i.id_almacen,
    a.nombre AS almacen,
    a.ubicacion,
    i.id_recurso,
    r.nombre AS recurso,
    r.tipo,
    r.unidad_medida,
    i.cantidad_actual,
    i.cantidad_minima,
    CASE
        WHEN i.cantidad_actual <= i.cantidad_minima
            THEN 'Stock minimo'
        ELSE 'Stock suficiente'
    END AS estado_stock
FROM inventario i
JOIN almacen a
    ON a.id_almacen = i.id_almacen
JOIN recurso r
    ON r.id_recurso = i.id_recurso;

DROP VIEW IF EXISTS vw_reporte_alertas_stock;

CREATE VIEW vw_reporte_alertas_stock AS
SELECT *
FROM vw_reporte_inventario_actual
WHERE cantidad_actual <= cantidad_minima;

DROP VIEW IF EXISTS vw_reporte_movimientos_recursos;

CREATE VIEW vw_reporte_movimientos_recursos AS
SELECT
    m.id_movimiento,
    m.fecha,
    m.tipo_movimiento,
    ao.nombre AS almacen_origen,
    ad.nombre AS almacen_destino,
    ac.nombre AS actividad,
    pr.nombre AS proveedor,
    r.id_recurso,
    r.nombre AS recurso,
    r.unidad_medida,
    dm.cantidad,
    m.descripcion
FROM movimiento m
JOIN detalle_movimiento dm
    ON dm.id_movimiento = m.id_movimiento
JOIN recurso r
    ON r.id_recurso = dm.id_recurso
LEFT JOIN almacen ao
    ON ao.id_almacen = m.id_almacen_origen
LEFT JOIN almacen ad
    ON ad.id_almacen = m.id_almacen_destino
LEFT JOIN actividad ac
    ON ac.id_actividad = m.id_actividad
LEFT JOIN proveedor pr
    ON pr.id_proveedor = m.id_proveedor;

DROP VIEW IF EXISTS vw_reporte_donaciones_por_donante;

CREATE VIEW vw_reporte_donaciones_por_donante AS
SELECT
    d.id_donante,
    d.nombre AS donante,
    d.tipo,
    COUNT(do.id_donacion) AS cantidad_donaciones,
    COALESCE(SUM(do.monto), 0) AS total_donado,
    MIN(do.fecha) AS primera_donacion,
    MAX(do.fecha) AS ultima_donacion
FROM donante d
LEFT JOIN donacion do
    ON do.id_donante = d.id_donante
GROUP BY
    d.id_donante,
    d.nombre,
    d.tipo;