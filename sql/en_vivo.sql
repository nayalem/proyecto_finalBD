--en_vivo.sql prueba en vivo para la defensa
--docker compose exec db psql -U postgres -f sql/en_vivo.sql
--con valores: -v clave=4321 -v desde=500 -v hasta=530
\set ON_ERROR_STOP on
\set QUIET on
\pset pager off
\pset footer off
SET client_min_messages = warning;
--valores por defecto
\if :{?clave}
\else
    \set clave 777
\endif
\if :{?desde}
\else
    \set desde 1000
\endif
\if :{?hasta}
\else
    \set hasta 1020
\endif
\set n 200000
\set nueva 250000
CREATE EXTENSION IF NOT EXISTS skiplist;

--medir con explain: plan, filas, paginas, ms
CREATE OR REPLACE FUNCTION medir(escenario TEXT, consulta TEXT)
RETURNS TABLE (escenario_ TEXT, como_busca TEXT, filas BIGINT, paginas BIGINT, ms NUMERIC) AS $$
DECLARE
    p JSONB;
    nodo JSONB;
BEGIN
    EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ' || consulta INTO p;
    nodo := p->0->'Plan';
    --buscar nodo scan
    WHILE nodo->>'Node Type' NOT LIKE '%Scan%' AND nodo ? 'Plans' LOOP
        nodo := nodo->'Plans'->0;
    END LOOP;
    escenario_ := escenario;
    como_busca := (nodo->>'Node Type') || coalesce(' con ' || (nodo->>'Index Name'), '');
    filas := (p->0->'Plan'->>'Actual Rows')::numeric::bigint;
    paginas := (p->0->'Plan'->>'Shared Hit Blocks')::bigint + (p->0->'Plan'->>'Shared Read Blocks')::bigint;
    ms := round((p->0->>'Execution Time')::numeric, 3);
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

\echo
\echo '=== Paso 1. Tres tablas con los mismos datos ==='
\echo 'Claves de 1 a 200 000 cargadas en orden aleatorio. Una tabla queda sin indice, otra con B-tree y otra con la Skip List.'
DROP TABLE IF EXISTS vivo_sin, vivo_bt, vivo_sl;
SELECT setseed(0.42) \g /dev/null
CREATE TABLE vivo_sin AS SELECT i AS id, 'Recurso ' || i AS nombre FROM generate_series(1, :n) i ORDER BY random();
CREATE TABLE vivo_bt AS SELECT * FROM vivo_sin;
CREATE TABLE vivo_sl AS SELECT * FROM vivo_sin;
SELECT count(*) AS filas_en_cada_tabla FROM vivo_sin;

\echo
\echo '=== Paso 2. Construccion de los indices (CREATE INDEX) ==='
\echo 'Que mirar: el tiempo de cada uno. La Skip List junta las claves, las ordena y las enlaza de izquierda a derecha.'
\timing on
CREATE INDEX vivo_idx_bt ON vivo_bt USING btree (id);
CREATE INDEX vivo_idx_sl ON vivo_sl USING skiplist (id);
\timing off
ANALYZE vivo_sin; ANALYZE vivo_bt; ANALYZE vivo_sl;
SELECT 'B-tree' AS indice, pg_size_pretty(pg_relation_size('vivo_idx_bt')) AS tamano
UNION ALL SELECT 'Skip List', pg_size_pretty(pg_relation_size('vivo_idx_sl'));

--obligar uso del indice
SET enable_seqscan = off;
SET enable_bitmapscan = off;

\echo
\echo '=== Paso 3. Buscar una clave que existe:' :clave '==='
\echo 'Que mirar: sin indice se recorre toda la tabla; el B-tree lee 3 o 4 paginas y la Skip List entre 30 y 50 (un acceso por nodo visitado).'
\echo 'Un solo tiempo varia mucho de una vez a otra; por eso el benchmark promedia 10 000 busquedas.'
SELECT * FROM medir('Sin indice', format('SELECT * FROM vivo_sin WHERE id = %s', :clave))
UNION ALL SELECT * FROM medir('B-tree', format('SELECT * FROM vivo_bt WHERE id = %s', :clave))
UNION ALL SELECT * FROM medir('Skip List', format('SELECT * FROM vivo_sl WHERE id = %s', :clave));
SELECT * FROM vivo_sl WHERE id = :clave;

\echo
\echo '=== Paso 4. Buscar una clave que NO existe: -5 ==='
\echo 'Que mirar: el indice baja por los niveles, no la encuentra y devuelve 0 filas sin recorrer la tabla.'
SELECT * FROM medir('Sin indice', 'SELECT * FROM vivo_sin WHERE id = -5')
UNION ALL SELECT * FROM medir('B-tree', 'SELECT * FROM vivo_bt WHERE id = -5')
UNION ALL SELECT * FROM medir('Skip List', 'SELECT * FROM vivo_sl WHERE id = -5');

\echo
\echo '=== Paso 4b. Lo mismo pero con muchas busquedas, como en el benchmark ==='
\echo 'Que mirar: con 10 000 busquedas al azar (100 sin indice, porque cada una recorre la tabla) se ve la diferencia real.'
--tiempo promedio por busqueda
CREATE OR REPLACE FUNCTION cronometrar(tabla TEXT, cuantas INT) RETURNS NUMERIC AS $$
DECLARE
    t0 TIMESTAMPTZ; x BIGINT; k INT;
BEGIN
    PERFORM setseed(0.43);
    t0 := clock_timestamp();
    FOR i IN 1..cuantas LOOP
        k := (random() * 200000)::int + 1;
        IF tabla = 'vivo_sin' THEN SELECT count(*) INTO x FROM vivo_sin WHERE id = k;
        ELSIF tabla = 'vivo_bt' THEN SELECT count(*) INTO x FROM vivo_bt WHERE id = k;
        ELSE SELECT count(*) INTO x FROM vivo_sl WHERE id = k; END IF;
    END LOOP;
    RETURN round((extract(epoch FROM clock_timestamp() - t0) * 1000 / cuantas)::numeric, 4);
END;
$$ LANGUAGE plpgsql;
SELECT 'Sin indice' AS escenario, 100 AS busquedas, cronometrar('vivo_sin', 100) AS ms_por_busqueda
UNION ALL SELECT 'B-tree', 10000, cronometrar('vivo_bt', 10000)
UNION ALL SELECT 'Skip List', 10000, cronometrar('vivo_sl', 10000);

\echo
\echo '=== Paso 5. Busqueda por rango: BETWEEN' :desde 'AND' :hasta '==='
\echo 'Que mirar: el WHERE se convierte en el rango [desde, hasta]; se busca el inicio y se avanza por el nivel 0.'
SELECT * FROM medir('Sin indice', format('SELECT * FROM vivo_sin WHERE id BETWEEN %s AND %s', :desde, :hasta))
UNION ALL SELECT * FROM medir('B-tree', format('SELECT * FROM vivo_bt WHERE id BETWEEN %s AND %s', :desde, :hasta))
UNION ALL SELECT * FROM medir('Skip List', format('SELECT * FROM vivo_sl WHERE id BETWEEN %s AND %s', :desde, :hasta));
SELECT array_agg(id ORDER BY id) AS claves_del_rango FROM vivo_sl WHERE id BETWEEN :desde AND :hasta;

\echo
\echo '=== Paso 6. Insertar una fila nueva con la clave' :nueva 'y encontrarla ==='
\echo 'Que mirar: el INSERT pasa por insertarFila, que busca el lugar y engancha el nodo; luego la busqueda la encuentra.'
INSERT INTO vivo_sin VALUES (:nueva, 'Nueva');
INSERT INTO vivo_bt VALUES (:nueva, 'Nueva');
INSERT INTO vivo_sl VALUES (:nueva, 'Nueva');
SELECT * FROM medir('Skip List', format('SELECT * FROM vivo_sl WHERE id = %s', :nueva));

\echo
\echo '=== Paso 7. Claves repetidas: insertamos la clave' :clave 'dos veces mas ==='
\echo 'Que mirar: el indice acepta repetidas y devuelve las 3 filas.'
INSERT INTO vivo_sl VALUES (:clave, 'Repetida 1'), (:clave, 'Repetida 2');
SELECT * FROM vivo_sl WHERE id = :clave ORDER BY nombre;

\echo
\echo '=== Paso 8. Borrar y pasar VACUUM ==='
\echo 'Que mirar: VACUUM llama a limpiar, que marca los nodos borrados; la busqueda ya no devuelve esas filas.'
DELETE FROM vivo_sl WHERE id = :clave;
VACUUM vivo_sl;
SELECT * FROM medir('Skip List', format('SELECT * FROM vivo_sl WHERE id = %s', :clave));

\echo
\echo '=== Paso 9. Comprobacion: 200 consultas al azar con el indice y sin el ==='
\echo 'Si todas dan la misma cantidad de filas, el indice no pierde ni agrega filas: PASA.'
--comparar con y sin indice
CREATE OR REPLACE FUNCTION comprobar_vivo() RETURNS TABLE (consultas INT, iguales INT, resultado TEXT) AS $$
DECLARE
    a BIGINT; b BIGINT; x INT; ok INT := 0;
BEGIN
    PERFORM setseed(0.7);
    FOR i IN 1..200 LOOP
        x := (random() * 260000)::int - 5000;
        SET LOCAL enable_seqscan = off;
        IF i % 2 = 0 THEN SELECT count(*) INTO a FROM vivo_sl WHERE id = x;
        ELSE SELECT count(*) INTO a FROM vivo_sl WHERE id BETWEEN x AND x + 300; END IF;
        SET LOCAL enable_seqscan = on; SET LOCAL enable_indexscan = off;   --sin indice
        IF i % 2 = 0 THEN SELECT count(*) INTO b FROM vivo_sl WHERE id = x;
        ELSE SELECT count(*) INTO b FROM vivo_sl WHERE id BETWEEN x AND x + 300; END IF;
        SET LOCAL enable_indexscan = on;
        IF a = b THEN ok := ok + 1; END IF;
    END LOOP;
    consultas := 200; iguales := ok;
    resultado := CASE WHEN ok = 200 THEN 'PASA' ELSE 'FALLA' END;
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;
SELECT * FROM comprobar_vivo();

\echo
\echo 'Listo. Las tablas vivo_sin, vivo_bt y vivo_sl quedan creadas para seguir probando a mano:'
\echo '  docker compose exec db psql -U postgres'
\echo '  SET enable_seqscan = off;  EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vivo_sl WHERE id = 123;'
