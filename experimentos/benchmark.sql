--benchmark.sql un dataset en los tres escenarios
--variables: dataset, n, reps, sin_indice, escenarios
\set ON_ERROR_STOP on
\pset pager off
SET client_min_messages = warning;
CREATE EXTENSION IF NOT EXISTS skiplist;
--por defecto los tres
\if :{?escenarios}
\else
    \set escenarios 'sin_indice,btree,skiplist'
\endif

--cargar datos y cargas (marccelo)
DROP TABLE IF EXISTS claves, w1, w2, w3, w4 CASCADE;
CREATE TABLE claves (k INT);
CREATE TABLE w1 (id SERIAL, k INT);
CREATE TABLE w2 (id SERIAL, k INT);
CREATE TABLE w3 (k INT);
CREATE TABLE w4 (id SERIAL, desde INT, hasta INT);
\copy claves FROM 'datos/generados/claves.csv' CSV
\copy w1(k) FROM 'datos/generados/w1.csv' CSV
\copy w2(k) FROM 'datos/generados/w2.csv' CSV
\copy w3 FROM 'datos/generados/w3.csv' CSV
\copy w4(desde, hasta) FROM 'datos/generados/w4.csv' CSV

--resultados de todos los datasets
CREATE TABLE IF NOT EXISTS benchmark (dataset TEXT, n INT, escenario TEXT, repeticion INT, medida TEXT, valor FLOAT);
--reemplazar escenarios medidos
DELETE FROM benchmark WHERE dataset = :'dataset' AND n = :n AND escenario = ANY (string_to_array(:'escenarios', ','));
SELECT set_config('bench.dataset', :'dataset', false), set_config('bench.n', :'n', false),
       set_config('bench.sin_indice', :'sin_indice', false) \g /dev/null

--medir una repeticion (camila)
CREATE OR REPLACE FUNCTION medir(escenario TEXT, rep INT) RETURNS VOID AS $$
DECLARE
    ds TEXT := current_setting('bench.dataset');
    n  INT  := current_setting('bench.n')::int;
    --limite sin indice (rodrigo)
    limite INT := CASE WHEN escenario = 'sin_indice' THEN current_setting('bench.sin_indice')::int ELSE 10000 END;
    t0 TIMESTAMPTZ;
    r  RECORD;
    plan JSON;
    paginas FLOAT := 0;
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
    FOR r IN SELECT k FROM w1 ORDER BY id LIMIT limite LOOP
        PERFORM count(*) FROM datos WHERE k = r.k;
    END LOOP;
    INSERT INTO benchmark VALUES (ds, n, escenario, rep, '2. W1 busqueda exitosa (ms por consulta)',
                                  extract(epoch FROM clock_timestamp() - t0) * 1000 / LEAST(limite, 10000));

    --w2 no exitosas
    t0 := clock_timestamp();
    FOR r IN SELECT k FROM w2 ORDER BY id LIMIT limite LOOP
        PERFORM count(*) FROM datos WHERE k = r.k;
    END LOOP;
    INSERT INTO benchmark VALUES (ds, n, escenario, rep, '3. W2 busqueda no exitosa (ms por consulta)',
                                  extract(epoch FROM clock_timestamp() - t0) * 1000 / LEAST(limite, 10000));

    --w4 rangos
    t0 := clock_timestamp();
    FOR r IN SELECT desde, hasta FROM w4 ORDER BY id LOOP
        PERFORM count(*) FROM datos WHERE k BETWEEN r.desde AND r.hasta;
    END LOOP;
    INSERT INTO benchmark VALUES (ds, n, escenario, rep, '4. W4 rango (ms por consulta)',
                                  extract(epoch FROM clock_timestamp() - t0) * 1000 / 1000);

    --paginas por busqueda (nayalem)
    FOR r IN SELECT k FROM w1 ORDER BY id LIMIT 100 LOOP
        EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) SELECT count(*) FROM datos WHERE k = $1' INTO plan USING r.k;
        paginas := paginas + (plan->0->'Plan'->>'Shared Hit Blocks')::int + (plan->0->'Plan'->>'Shared Read Blocks')::int;
    END LOOP;
    INSERT INTO benchmark VALUES (ds, n, escenario, rep, '7. paginas leidas por busqueda', paginas / 100);

    --w3 inserciones al final
    t0 := clock_timestamp();
    INSERT INTO datos SELECT k FROM w3;
    INSERT INTO benchmark VALUES (ds, n, escenario, rep, '5. W3 insercion del 10% (ms en total)',
                                  extract(epoch FROM clock_timestamp() - t0) * 1000);
END;
$$ LANGUAGE plpgsql;

--repeticiones alternadas (pedro)
SELECT medir(e, rep) FROM generate_series(1, :reps) AS rep,
       unnest(string_to_array(:'escenarios', ',')) AS e \g /dev/null

--mediana del dataset
SELECT medida,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY valor) FILTER (WHERE escenario = 'sin_indice')::numeric, 4) AS sin_indice,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY valor) FILTER (WHERE escenario = 'btree')::numeric, 4)      AS btree,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY valor) FILTER (WHERE escenario = 'skiplist')::numeric, 4)   AS skiplist
FROM benchmark WHERE dataset = :'dataset' AND n = :n GROUP BY medida ORDER BY medida;
DROP TABLE IF EXISTS datos CASCADE;
