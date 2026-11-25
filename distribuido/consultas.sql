--consultas.sql locales y entre nodos desde a (rodrigo)
\set ON_ERROR_STOP on
\pset pager off
\pset footer off
SET client_min_messages = warning;
CREATE TABLE IF NOT EXISTS consultas_dist (estrategia TEXT, consulta TEXT, repeticion INT, ms FLOAT, filas_red INT);
DELETE FROM consultas_dist WHERE estrategia = :'estrategia';

--tiempo y filas por la red
CREATE OR REPLACE FUNCTION medir_consulta(estrategia TEXT, nombre TEXT, sql TEXT) RETURNS VOID AS $$
DECLARE
    plan JSONB;
BEGIN
    FOR rep IN 1..5 LOOP
        EXECUTE 'EXPLAIN (ANALYZE, FORMAT JSON) ' || sql INTO plan;
        INSERT INTO consultas_dist VALUES (estrategia, nombre, rep, (plan->0->>'Execution Time')::float,
            --filas de foreign scan
            (SELECT coalesce(sum(x::int), 0) FROM jsonb_path_query(plan,
                'strict $.**? (@."Node Type" == "Foreign Scan")."Actual Rows"') AS x));
    END LOOP;
END;
$$ LANGUAGE plpgsql;

--un voluntario por zona
SELECT medir_consulta(:'estrategia', '1. voluntario de la zona Norte',
       'SELECT * FROM participacion WHERE id_voluntario = 4 AND zona = 1') \g /dev/null
SELECT medir_consulta(:'estrategia', '2. voluntario de la zona Centro',
       'SELECT * FROM participacion WHERE id_voluntario = 5 AND zona = 2') \g /dev/null
SELECT medir_consulta(:'estrategia', '3. voluntario de la zona Sur',
       'SELECT * FROM participacion WHERE id_voluntario = 6 AND zona = 3') \g /dev/null
--varios nodos, poco resultado
SELECT medir_consulta(:'estrategia', '4. asistencia de una actividad (varios nodos)',
       'SELECT estado, count(*) FROM participacion WHERE id_actividad = 100 GROUP BY estado') \g /dev/null
--varios nodos, muchas filas
SELECT medir_consulta(:'estrategia', '5. participantes de un mes con su nombre (varios nodos, muchas filas)',
       'SELECT v.nombres, p.fecha FROM participacion p JOIN voluntario v ON v.id_voluntario = p.id_voluntario
        WHERE p.fecha BETWEEN ''2025-01-01'' AND ''2025-01-31''') \g /dev/null

SELECT consulta,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY ms)::numeric, 2) AS ms_mediana,
       max(filas_red) AS filas_por_la_red
FROM consultas_dist WHERE estrategia = :'estrategia' GROUP BY consulta ORDER BY consulta;
