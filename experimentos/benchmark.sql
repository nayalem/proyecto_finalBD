--benchmark.sql un dataset en los tres escenarios
--variables: dataset, n, reps
\set ON_ERROR_STOP on
\pset pager off
SET client_min_messages = warning;
CREATE EXTENSION IF NOT EXISTS skiplist;

--datos d2 con semilla fija
SELECT setseed(0.42) \g /dev/null
DROP TABLE IF EXISTS claves, w1, w2, w3, w4 CASCADE;
CREATE TABLE claves AS SELECT i AS k FROM generate_series(1, 10 * :n) AS i ORDER BY random() LIMIT :n;
--w1 exitosas
CREATE TABLE w1 AS SELECT row_number() OVER () AS id, k FROM (SELECT k FROM claves ORDER BY random() LIMIT 10000) s;
--w2 no exitosas
CREATE TABLE w2 AS SELECT row_number() OVER () AS id, k FROM
    (SELECT DISTINCT 10 * :n + 1 + (random() * 10 * :n)::int AS k FROM generate_series(1, 11000) LIMIT 10000) s;
--w3 inserciones del 10%
CREATE TABLE w3 AS SELECT i AS k FROM generate_series(1, 10 * :n) AS i
    WHERE NOT EXISTS (SELECT 1 FROM claves c WHERE c.k = i) ORDER BY random() LIMIT :n / 10;
--w4 rangos de 100 claves
CREATE TABLE w4 AS SELECT g AS id, d AS desde, d + 999 AS hasta
    FROM (SELECT g, 1 + (random() * (10 * :n - 1000))::int AS d FROM generate_series(1, 1000) AS g) s;

--resultados de todos los datasets
CREATE TABLE IF NOT EXISTS benchmark (dataset TEXT, n INT, escenario TEXT, repeticion INT, medida TEXT, valor FLOAT);
DELETE FROM benchmark WHERE dataset = :'dataset' AND n = :n;   --reemplazar si se repite
SELECT set_config('bench.dataset', :'dataset', false), set_config('bench.n', :'n', false) \g /dev/null

--medir una repeticion (camila)
CREATE OR REPLACE FUNCTION medir(escenario TEXT, rep INT) RETURNS VOID AS $$
DECLARE
    ds TEXT := current_setting('bench.dataset');
    n  INT  := current_setting('bench.n')::int;
    t0 TIMESTAMPTZ;
    r  RECORD;
BEGIN
    DROP TABLE IF EXISTS datos CASCADE;
    CREATE TABLE datos AS SELECT k FROM claves;

    --construccion
    t0 := clock_timestamp();
    IF escenario = 'btree'    THEN CREATE INDEX idx ON datos USING btree (k);    END IF;
    IF escenario = 'skiplist' THEN CREATE INDEX idx ON datos USING skiplist (k); END IF;
    IF escenario <> 'sin_indice' THEN
        INSERT INTO benchmark VALUES (ds, n, escenario, rep, '1. construccion (ms)',
                                      extract(epoch FROM clock_timestamp() - t0) * 1000);
        INSERT INTO benchmark VALUES (ds, n, escenario, rep, '6. tamano del indice (MB)',
                                      pg_relation_size('idx') / 1024.0 / 1024.0);
    END IF;
    ANALYZE datos;

    --obligar indice
    PERFORM set_config('enable_seqscan', CASE WHEN escenario = 'sin_indice' THEN 'on' ELSE 'off' END, true);

    --w1 exitosas
    t0 := clock_timestamp();
    FOR r IN SELECT k FROM w1 ORDER BY id LOOP
        PERFORM count(*) FROM datos WHERE k = r.k;
    END LOOP;
    INSERT INTO benchmark VALUES (ds, n, escenario, rep, '2. W1 busqueda exitosa (ms por consulta)',
                                  extract(epoch FROM clock_timestamp() - t0) * 1000 / 10000);

    --w2 no exitosas
    t0 := clock_timestamp();
    FOR r IN SELECT k FROM w2 ORDER BY id LOOP
        PERFORM count(*) FROM datos WHERE k = r.k;
    END LOOP;
    INSERT INTO benchmark VALUES (ds, n, escenario, rep, '3. W2 busqueda no exitosa (ms por consulta)',
                                  extract(epoch FROM clock_timestamp() - t0) * 1000 / 10000);

    --w4 rangos
    t0 := clock_timestamp();
    FOR r IN SELECT desde, hasta FROM w4 ORDER BY id LOOP
        PERFORM count(*) FROM datos WHERE k BETWEEN r.desde AND r.hasta;
    END LOOP;
    INSERT INTO benchmark VALUES (ds, n, escenario, rep, '4. W4 rango (ms por consulta)',
                                  extract(epoch FROM clock_timestamp() - t0) * 1000 / 1000);

    --w3 inserciones al final
    t0 := clock_timestamp();
    INSERT INTO datos SELECT k FROM w3;
    INSERT INTO benchmark VALUES (ds, n, escenario, rep, '5. W3 insercion del 10% (ms en total)',
                                  extract(epoch FROM clock_timestamp() - t0) * 1000);
END;
$$ LANGUAGE plpgsql;

--repeticiones alternadas (pedro)
SELECT medir(e, rep) FROM generate_series(1, :reps) AS rep,
       unnest(ARRAY['sin_indice', 'btree', 'skiplist']) AS e \g /dev/null

--mediana del dataset
SELECT medida,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY valor) FILTER (WHERE escenario = 'sin_indice')::numeric, 4) AS sin_indice,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY valor) FILTER (WHERE escenario = 'btree')::numeric, 4)      AS btree,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY valor) FILTER (WHERE escenario = 'skiplist')::numeric, 4)   AS skiplist
FROM benchmark WHERE dataset = :'dataset' AND n = :n GROUP BY medida ORDER BY medida;
DROP TABLE IF EXISTS datos CASCADE;
