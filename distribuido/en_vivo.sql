--en_vivo.sql escenario distribuido en vivo desde a
\set ON_ERROR_STOP on
\set QUIET on
\pset pager off
\pset footer off
SET client_min_messages = warning;

--medir local o remoto
CREATE OR REPLACE FUNCTION medir_red(que TEXT, consulta TEXT)
RETURNS TABLE (consulta_ TEXT, donde_lee TEXT, filas BIGINT, ms NUMERIC) AS $$
DECLARE
    p JSONB;
    nodo JSONB;
BEGIN
    EXECUTE 'EXPLAIN (ANALYZE, FORMAT JSON) ' || consulta INTO p;
    nodo := p->0->'Plan';
    WHILE nodo->>'Node Type' NOT LIKE '%Scan%' AND nodo ? 'Plans' LOOP
        nodo := nodo->'Plans'->0;
    END LOOP;
    consulta_ := que;
    donde_lee := CASE WHEN nodo->>'Node Type' = 'Foreign Scan'
                      THEN 'remoto: ' || (nodo->>'Relation Name') || ' (otro nodo)'
                      ELSE 'local: ' || (nodo->>'Node Type') || coalesce(' con ' || (nodo->>'Index Name'), '') END;
    filas := (p->0->'Plan'->>'Actual Rows')::numeric::bigint;
    ms := round((p->0->>'Execution Time')::numeric, 2);
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

\echo
\echo '=== 1. Como ve el nodo A la tabla participacion ==='
\echo 'Una particion es local (el fragmento de A) y las otras dos son tablas remotas (postgres_fdw) que pasan por red.py.'
SELECT pg_get_partkeydef('participacion'::regclass) AS particionada_por;
SELECT c.relname AS particion,
       CASE WHEN c.relkind = 'f' THEN 'remota, servidor ' || s.srvname || ' (' || array_to_string(s.srvoptions[1:2], ', ') || ')'
            ELSE 'local, en este nodo' END AS donde_esta,
       pg_get_expr(c.relpartbound, c.oid) AS que_filas_guarda
FROM pg_inherits i
JOIN pg_class c ON c.oid = i.inhrelid
LEFT JOIN pg_foreign_table f ON f.ftrelid = c.oid
LEFT JOIN pg_foreign_server s ON s.oid = f.ftserver
WHERE i.inhparent = 'participacion'::regclass
ORDER BY 1;

--abrir conexiones antes
SELECT count(*) FROM participacion WHERE id_voluntario = 2 AND zona = 2 \g /dev/null
SELECT count(*) FROM participacion WHERE id_voluntario = 3 AND zona = 3 \g /dev/null

\echo
\echo '=== 2. Un voluntario de cada zona, consultado desde A ==='
\echo 'Que mirar: local tarda centesimas de ms; ir a B (20 ms de ida y vuelta) tarda alrededor de 62 ms y a C (40 ms) alrededor de 123 ms: unas 3 idas y vueltas.'
SELECT * FROM medir_red('voluntario 1, zona Norte', 'SELECT * FROM participacion WHERE id_voluntario = 1 AND zona = 1')
UNION ALL SELECT * FROM medir_red('voluntario 2, zona Centro', 'SELECT * FROM participacion WHERE id_voluntario = 2 AND zona = 2')
UNION ALL SELECT * FROM medir_red('voluntario 3, zona Sur', 'SELECT * FROM participacion WHERE id_voluntario = 3 AND zona = 3');

--voluntario pedido
SELECT :vol > 0 AS hay_voluntario \gset
\if :hay_voluntario
\echo
\echo '=== 2b. El voluntario pedido:' :vol '==='
SELECT * FROM medir_red(format('voluntario %s, zona %s', :vol, (:vol - 1) % 3 + 1),
                        format('SELECT * FROM participacion WHERE id_voluntario = %s AND zona = %s', :vol, (:vol - 1) % 3 + 1));
SELECT p.id_voluntario, v.nombres || ' ' || v.apellidos AS voluntario, a.nombre AS actividad, p.fecha, p.estado
FROM participacion p
JOIN voluntario v ON v.id_voluntario = p.id_voluntario AND v.zona = p.zona
JOIN actividad a ON a.id_actividad = p.id_actividad
WHERE p.id_voluntario = :vol AND p.zona = (:vol - 1) % 3 + 1
ORDER BY p.fecha LIMIT 5;
\endif

\echo
\echo '=== 3. Una consulta que necesita a los tres nodos: la asistencia a la actividad 1 ==='
\echo 'Que mirar en el plan: la condicion id_actividad = 1 viaja a B y a C (Foreign Scan), que devuelven solo esas filas; A las agrupa.'
\echo 'Las preguntas a B y a C se hacen una despues de la otra, por eso el tiempo es parecido a la suma de ir a B y a C.'
EXPLAIN (COSTS OFF) SELECT estado, count(*) FROM participacion WHERE id_actividad = 1 GROUP BY estado;
\timing on
SELECT estado, count(*) FROM participacion WHERE id_actividad = 1 GROUP BY estado ORDER BY estado;
\timing off

\echo
\echo '=== 4. Una insercion desde A para un voluntario de la zona Centro ==='
\echo 'Que mirar: PostgreSQL la manda sola a la particion del nodo B; el id sale de la secuencia de A (1000001, 1000004...).'
INSERT INTO participacion (id_voluntario, zona, id_actividad, fecha, estado)
VALUES (2, 2, 1, current_date, 'Pendiente')
RETURNING id_participacion, tableoid::regclass AS guardada_en;
--deshacer prueba
DELETE FROM participacion WHERE id_voluntario = 2 AND zona = 2 AND fecha = current_date AND estado = 'Pendiente' AND id_participacion > 1000000;

\echo
\echo 'Listo. Para probar a mano desde A:'
\echo '  docker compose -f distribuido/docker-compose.yml exec nodo_a psql -U postgres'
