--resumen.sql tablas del escenario distribuido
\set ON_ERROR_STOP on
\pset pager off
\pset footer off
SET client_min_messages = warning;
DROP TABLE IF EXISTS carga;
CREATE TABLE carga (escenario TEXT, concentracion TEXT, repeticion INT, nodo TEXT, script TEXT, segundos INT, transacciones INT, latencia_ms FLOAT);
\copy carga FROM 'distribuido/resultados/carga.csv' CSV HEADER

--guardar entorno
\o distribuido/resultados/entorno.txt
SELECT version() AS postgresql;
SELECT name, setting, unit FROM pg_settings
WHERE name IN ('shared_buffers', 'work_mem', 'wal_level', 'enable_partitionwise_aggregate', 'enable_partitionwise_join') ORDER BY name;
SELECT 'A-B 20 ms, A-C 40 ms, B-C 25 ms (ida y vuelta, con red.py)' AS latencias,
       '1 000 000 participaciones, 99 999 voluntarios, 3000 actividades, 30 organizaciones (semilla 42)' AS datos,
       '70% lecturas / 30% escrituras, 2 clientes por nodo, ' || max(segundos) || ' s por repeticion' AS carga,
       count(DISTINCT repeticion) AS repeticiones, 'mediana' AS medida_central, now() AS fecha
FROM carga;
\o

\echo '=== 7.3 Consultas desde el nodo A: tiempo (ms, mediana de 5) y filas que llegaron por la red ==='
SELECT consulta,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY ms) FILTER (WHERE estrategia = 'E1-skiplist')::numeric, 2) AS e1_skiplist_ms,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY ms) FILTER (WHERE estrategia = 'E1-btree')::numeric, 2)    AS e1_btree_ms,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY ms) FILTER (WHERE estrategia = 'E2-skiplist')::numeric, 2) AS e2_skiplist_ms,
       max(filas_red) FILTER (WHERE estrategia = 'E1-skiplist') AS e1_filas_red,
       max(filas_red) FILTER (WHERE estrategia = 'E2-skiplist') AS e2_filas_red
FROM consultas_dist GROUP BY consulta ORDER BY consulta;

\echo '=== 7.4 Carga 70/30: transacciones por segundo de los 3 nodos juntos (mediana de 5) ==='
SELECT escenario, concentracion, round(percentile_cont(0.5) WITHIN GROUP (ORDER BY tps)::numeric, 1) AS tps
FROM (SELECT escenario, concentracion, repeticion, sum(transacciones)::float / max(segundos) AS tps
      FROM carga GROUP BY 1, 2, 3) s
GROUP BY 1, 2 ORDER BY 1, 2 DESC;

\echo '=== 7.4 Latencia promedio por tipo de operacion (ms, mediana de 5) ==='
SELECT script AS operacion,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY lat) FILTER (WHERE escenario = 'E1-skiplist' AND concentracion = 'normal')::numeric, 1) AS e1_sl_normal,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY lat) FILTER (WHERE escenario = 'E1-btree' AND concentracion = 'normal')::numeric, 1)    AS e1_bt_normal,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY lat) FILTER (WHERE escenario = 'E2-skiplist' AND concentracion = 'normal')::numeric, 1) AS e2_sl_normal,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY lat) FILTER (WHERE escenario = 'E1-skiplist' AND concentracion = 'concentrada')::numeric, 1) AS e1_sl_concentrada,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY lat) FILTER (WHERE escenario = 'E2-skiplist' AND concentracion = 'concentrada')::numeric, 1) AS e2_sl_concentrada
FROM (SELECT escenario, concentracion, repeticion, script,   --promedio ponderado
             sum(latencia_ms * transacciones) / NULLIF(sum(transacciones), 0) AS lat
      FROM carga GROUP BY 1, 2, 3, 4) s
GROUP BY script ORDER BY script;

--guardar csv
\copy (SELECT * FROM consultas_dist ORDER BY 1, 2, 3) TO 'distribuido/resultados/consultas.csv' CSV HEADER
\echo 'Detalle en distribuido/resultados/ (consultas.csv y carga.csv)'
