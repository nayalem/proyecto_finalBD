-- comparacion.sql — primera comparación: sin índice vs. B-tree vs. Skip List
-- Ejecutar:  psql -U postgres -f experimentos/comparacion.sql
-- 4.1 sin índice (Rodrigo) · 4.2 B-tree (Nayalem) · 4.3 Skip List (Camila) · 4.4 repeticiones (Pedro)
-- Los tres escenarios usan exactamente los mismos datos y las mismas consultas.
-- Cada uno se repite 5 veces y mostramos la mediana (no le afecta una corrida que salió lenta).
\set ON_ERROR_STOP on
\pset pager off
SET client_min_messages = warning;
CREATE EXTENSION IF NOT EXISTS skiplist;

-- 1) Los datos: aleatorios pero con semilla fija, así salen iguales cada vez que se corre
SELECT setseed(0.42) \g /dev/null
DROP TABLE IF EXISTS base, w1, w2, w3, w4, resultados CASCADE;
-- 100 000 claves distintas elegidas al azar entre 1 y 1 000 000
CREATE TABLE base AS
    SELECT i AS k FROM generate_series(1, 1000000) AS i ORDER BY random() LIMIT 100000;
-- W1: 1000 búsquedas de claves que sí existen
CREATE TABLE w1 AS
    SELECT row_number() OVER () AS id, k FROM (SELECT k FROM base ORDER BY random() LIMIT 1000) s;
-- W2: 1000 búsquedas de claves que no existen
CREATE TABLE w2 AS
    SELECT row_number() OVER () AS id, i AS k FROM
    (SELECT i FROM generate_series(1, 1000000) AS i WHERE i NOT IN (SELECT k FROM base)
     ORDER BY random() LIMIT 1000) s;
-- W3: 10 000 claves nuevas para insertar (10% más)
CREATE TABLE w3 AS
    SELECT i AS k FROM generate_series(1, 1000000) AS i
    WHERE i NOT IN (SELECT k FROM base) AND i NOT IN (SELECT k FROM w2)
    ORDER BY random() LIMIT 10000;
-- W4: 1000 rangos de 1000 números (unas 100 claves cada uno)
CREATE TABLE w4 AS
    SELECT g AS id, d AS desde, d + 999 AS hasta
    FROM (SELECT g, 1 + (random() * 998000)::int AS d FROM generate_series(1, 1000) AS g) s;
CREATE TABLE resultados (escenario TEXT, repeticion INT, medida TEXT, valor FLOAT);

-- 2) Una corrida de un escenario: copiar la tabla, crear el índice y lanzar las consultas
CREATE OR REPLACE FUNCTION medir(escenario TEXT, rep INT) RETURNS VOID AS $$
DECLARE
    t0 TIMESTAMPTZ;
    r  RECORD;
BEGIN
    DROP TABLE IF EXISTS datos CASCADE;
    CREATE TABLE datos AS SELECT k FROM base;

    t0 := clock_timestamp();
    IF escenario = 'btree'    THEN CREATE INDEX idx ON datos USING btree (k);    END IF;
    IF escenario = 'skiplist' THEN CREATE INDEX idx ON datos USING skiplist (k); END IF;
    IF escenario <> 'sin_indice' THEN
        INSERT INTO resultados VALUES (escenario, rep, '1. construcción (ms)',
                                       extract(epoch FROM clock_timestamp() - t0) * 1000);
    END IF;
    ANALYZE datos;

    -- con índice, obligamos a PostgreSQL a usarlo
    PERFORM set_config('enable_seqscan', CASE WHEN escenario = 'sin_indice' THEN 'on' ELSE 'off' END, true);

    t0 := clock_timestamp();
    FOR r IN SELECT k FROM w1 ORDER BY id LOOP
        PERFORM count(*) FROM datos WHERE k = r.k;
    END LOOP;
    INSERT INTO resultados VALUES (escenario, rep, '2. W1 búsqueda exitosa (ms por consulta)',
                                   extract(epoch FROM clock_timestamp() - t0) * 1000 / 1000);

    t0 := clock_timestamp();
    FOR r IN SELECT k FROM w2 ORDER BY id LOOP
        PERFORM count(*) FROM datos WHERE k = r.k;
    END LOOP;
    INSERT INTO resultados VALUES (escenario, rep, '3. W2 búsqueda no exitosa (ms por consulta)',
                                   extract(epoch FROM clock_timestamp() - t0) * 1000 / 1000);

    t0 := clock_timestamp();
    FOR r IN SELECT desde, hasta FROM w4 ORDER BY id LOOP
        PERFORM count(*) FROM datos WHERE k BETWEEN r.desde AND r.hasta;
    END LOOP;
    INSERT INTO resultados VALUES (escenario, rep, '4. W4 rango (ms por consulta)',
                                   extract(epoch FROM clock_timestamp() - t0) * 1000 / 1000);

    t0 := clock_timestamp();
    INSERT INTO datos SELECT k FROM w3;
    INSERT INTO resultados VALUES (escenario, rep, '5. W3 inserción del 10% (ms en total)',
                                   extract(epoch FROM clock_timestamp() - t0) * 1000);

    IF escenario <> 'sin_indice' THEN
        INSERT INTO resultados VALUES (escenario, rep, '6. tamaño del índice (MB)',
                                       pg_relation_size('idx') / 1024.0 / 1024.0);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 3) 5 repeticiones de cada escenario
\echo 'Midiendo (5 repeticiones x 3 escenarios)...'
SELECT medir(e, rep) FROM generate_series(1, 5) AS rep,
       unnest(ARRAY['sin_indice', 'btree', 'skiplist']) AS e \g /dev/null

-- 4) Resultados: la mediana de las 5 repeticiones
\echo ''
SELECT version() AS postgresql, (SELECT count(*) FROM base) AS claves, 5 AS repeticiones;
SELECT medida,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY valor) FILTER (WHERE escenario = 'sin_indice')::numeric, 4) AS sin_indice,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY valor) FILTER (WHERE escenario = 'btree')::numeric, 4)      AS btree,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY valor) FILTER (WHERE escenario = 'skiplist')::numeric, 4)   AS skiplist
FROM resultados GROUP BY medida ORDER BY medida;

-- Guardamos cada repetición por si hay que revisarla
\copy resultados TO 'experimentos/resultados.csv' CSV HEADER
\echo 'Detalle de cada repetición en experimentos/resultados.csv'
