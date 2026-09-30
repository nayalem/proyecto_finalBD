PRAGMA foreign_keys = ON;

-- Validaciones de reglas de negocio. Se mantienen como triggers porque dependen
-- de otras filas o de condiciones que un CHECK simple no puede consultar.

DROP TRIGGER IF EXISTS trg_voluntario_bi_validar;
CREATE TRIGGER trg_voluntario_bi_validar
BEFORE INSERT ON voluntario
BEGIN
    SELECT CASE
        WHEN NEW.fecha_nacimiento > date('now', '-14 years')
        THEN RAISE(ABORT, 'El voluntario debe tener al menos 14 anios')
    END;
END;

DROP TRIGGER IF EXISTS trg_actividad_bi_validar;
CREATE TRIGGER trg_actividad_bi_validar
BEFORE INSERT ON actividad
BEGIN
    SELECT CASE
        WHEN NEW.cupo_maximo IS NOT NULL AND NEW.cupo_maximo <= 0
        THEN RAISE(ABORT, 'El cupo maximo debe ser mayor a cero')
    END;
END;

DROP TRIGGER IF EXISTS trg_presupuesto_bi_validar;
CREATE TRIGGER trg_presupuesto_bi_validar
BEFORE INSERT ON presupuesto
BEGIN
    SELECT CASE
        WHEN NEW.monto_total <= 0
        THEN RAISE(ABORT, 'El presupuesto debe ser mayor a cero')
    END;
END;

DROP TRIGGER IF EXISTS trg_partida_bi_validar;
CREATE TRIGGER trg_partida_bi_validar
BEFORE INSERT ON partida_presupuestal
BEGIN
    SELECT CASE
        WHEN NEW.monto_asignado <= 0
        THEN RAISE(ABORT, 'El monto asignado debe ser mayor a cero')
    END;

    SELECT CASE
        WHEN (
            NEW.monto_asignado +
            IFNULL((
                SELECT SUM(monto_asignado)
                FROM partida_presupuestal
                WHERE id_presupuesto = NEW.id_presupuesto
            ), 0)
        ) > (
            SELECT monto_total
            FROM presupuesto
            WHERE id_presupuesto = NEW.id_presupuesto
        )
        THEN RAISE(ABORT, 'Las partidas superan el monto total del presupuesto')
    END;
END;

DROP TRIGGER IF EXISTS trg_donacion_bi_validar;
CREATE TRIGGER trg_donacion_bi_validar
BEFORE INSERT ON donacion
BEGIN
    SELECT CASE
        WHEN NEW.monto <= 0
        THEN RAISE(ABORT, 'La donacion debe ser mayor a cero')
    END;
END;

DROP TRIGGER IF EXISTS trg_gasto_bi_validar;
CREATE TRIGGER trg_gasto_bi_validar
BEFORE INSERT ON gasto
BEGIN
    SELECT CASE
        WHEN NEW.monto <= 0
        THEN RAISE(ABORT, 'El gasto debe ser mayor a cero')
    END;

    SELECT CASE
        WHEN (
            NEW.monto +
            IFNULL((
                SELECT SUM(monto)
                FROM gasto
                WHERE id_partida = NEW.id_partida
            ), 0)
        ) > (
            SELECT monto_asignado
            FROM partida_presupuestal
            WHERE id_partida = NEW.id_partida
        )
        THEN RAISE(ABORT, 'El gasto supera el saldo disponible de la partida')
    END;
END;

DROP TRIGGER IF EXISTS trg_participacion_bi_validar;
CREATE TRIGGER trg_participacion_bi_validar
BEFORE INSERT ON participacion
BEGIN
    SELECT CASE
        WHEN (SELECT estado FROM voluntario WHERE id_voluntario = NEW.id_voluntario) <> 'Activo'
        THEN RAISE(ABORT, 'Solo voluntarios activos')
    END;

    SELECT CASE
        WHEN (
            SELECT COUNT(*)
            FROM participacion
            WHERE id_actividad = NEW.id_actividad
        ) >= IFNULL((
            SELECT cupo_maximo
            FROM actividad
            WHERE id_actividad = NEW.id_actividad
        ), 999999)
        THEN RAISE(ABORT, 'Actividad sin cupo disponible')
    END;
END;

DROP TRIGGER IF EXISTS trg_participacion_bu_validar;
CREATE TRIGGER trg_participacion_bu_validar
BEFORE UPDATE ON participacion
BEGIN
    SELECT CASE
        WHEN (SELECT estado FROM voluntario WHERE id_voluntario = NEW.id_voluntario) <> 'Activo'
        THEN RAISE(ABORT, 'Solo voluntarios activos')
    END;
END;

DROP TRIGGER IF EXISTS trg_movimiento_bi_validar;
CREATE TRIGGER trg_movimiento_bi_validar
BEFORE INSERT ON movimiento
BEGIN
    SELECT CASE
        WHEN NEW.tipo_movimiento = 'Entrada Compra'
             AND (NEW.id_almacen_destino IS NULL OR NEW.id_almacen_origen IS NOT NULL)
        THEN RAISE(ABORT, 'Entrada invalida')
    END;

    SELECT CASE
        WHEN NEW.tipo_movimiento = 'Salida Actividad'
             AND (
                NEW.id_almacen_origen IS NULL
                OR NEW.id_actividad IS NULL
                OR NEW.id_almacen_destino IS NOT NULL
             )
        THEN RAISE(ABORT, 'Salida invalida')
    END;

    SELECT CASE
        WHEN NEW.tipo_movimiento = 'Transferencia'
             AND (
                NEW.id_almacen_origen IS NULL
                OR NEW.id_almacen_destino IS NULL
                OR NEW.id_almacen_origen = NEW.id_almacen_destino
             )
        THEN RAISE(ABORT, 'Transferencia invalida')
    END;

    SELECT CASE
        WHEN NEW.tipo_movimiento = 'Ajuste Inventario'
             AND NOT (
                (NEW.id_almacen_origen IS NULL AND NEW.id_almacen_destino IS NOT NULL)
                OR
                (NEW.id_almacen_origen IS NOT NULL AND NEW.id_almacen_destino IS NULL)
             )
        THEN RAISE(ABORT, 'Ajuste invalido')
    END;
END;

DROP TRIGGER IF EXISTS trg_detalle_movimiento_bi_validar;
CREATE TRIGGER trg_detalle_movimiento_bi_validar
BEFORE INSERT ON detalle_movimiento
BEGIN
    SELECT CASE
        WHEN NEW.cantidad <= 0
        THEN RAISE(ABORT, 'Cantidad invalida')
    END;
END;
