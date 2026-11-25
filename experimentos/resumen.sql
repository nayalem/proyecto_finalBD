--resumen.sql tablas comparativas (marccelo)
--psql -U postgres -v reps=5 -v sin_indice=10000 -f experimentos/resumen.sql
\set ON_ERROR_STOP on
\if :{?modo}
\else
    \set modo completo
\endif
\pset pager off
\pset footer off

--mediana por dataset, tamano y medida
DROP VIEW IF EXISTS medianas;
CREATE VIEW medianas AS
SELECT dataset, n, medida,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY valor) FILTER (WHERE escenario = 'sin_indice')::numeric, 4) AS sin_indice,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY valor) FILTER (WHERE escenario = 'btree')::numeric, 4)      AS btree,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY valor) FILTER (WHERE escenario = 'skiplist')::numeric, 4)   AS skiplist
FROM benchmark GROUP BY dataset, n, medida;

--guardar entorno
\o experimentos/resultados/entorno.txt
SELECT version() AS postgresql;
SELECT name, setting, unit FROM pg_settings
WHERE name IN ('shared_buffers', 'work_mem', 'max_parallel_workers_per_gather', 'jit') ORDER BY name;
SELECT :'modo' AS modo, :reps AS repeticiones, 'mediana' AS medida_central, :sin_indice AS busquedas_sin_indice,
       '42 (datos), 43 (cargas)' AS semillas, 1.1 AS zipf_d3, now() AS fecha;
\o

\echo ''
\echo '=== Resultados (mediana de las repeticiones) ==='
\echo 'skiplist_vs_btree: cuantas veces lo que tarda/ocupa la Skip List respecto al B-tree (menos de 1 = mejor)'
SELECT dataset, n AS claves, medida, sin_indice, btree, skiplist,
       round(skiplist / NULLIF(btree, 0), 2) AS skiplist_vs_btree
FROM medianas ORDER BY medida, dataset, n;

\echo ''
\echo '=== Como crece al aumentar los datos (D2, aleatorio) ==='
SELECT medida,
       max(skiplist) FILTER (WHERE n = 100000)  AS sl_100k,
       max(skiplist) FILTER (WHERE n = 500000)  AS sl_500k,
       max(skiplist) FILTER (WHERE n = 1000000) AS sl_1m,
       max(btree)    FILTER (WHERE n = 100000)  AS bt_100k,
       max(btree)    FILTER (WHERE n = 500000)  AS bt_500k,
       max(btree)    FILTER (WHERE n = 1000000) AS bt_1m
FROM medianas WHERE dataset = 'D2' GROUP BY medida ORDER BY medida;

--guardar csv
\copy benchmark TO 'experimentos/resultados/benchmark_repeticiones.csv' CSV HEADER
\copy (SELECT * FROM medianas ORDER BY dataset, n, medida) TO 'experimentos/resultados/benchmark_medianas.csv' CSV HEADER
\echo ''
\echo 'Guardado en experimentos/resultados/ (benchmark_repeticiones.csv, benchmark_medianas.csv y entorno.txt)'
