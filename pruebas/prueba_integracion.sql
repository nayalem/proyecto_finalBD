-- prueba_integracion.sql — 3.3 (Camila y Marccelo)
-- Revisa que el índice devuelva lo mismo que una búsqueda sin índice
-- Ejecutar:  psql -U postgres -f pruebas/prueba_integracion.sql
-- Después de reiniciar el contenedor:  psql -U postgres -P pager=off -c "SELECT * FROM comparar('después de reiniciar')"
\set ON_ERROR_STOP on
\pset pager off
\pset footer off
SET client_min_messages = warning;
CREATE EXTENSION IF NOT EXISTS skiplist;

-- 50 000 claves entre 0 y 20 000 (hay repetidas) y algunos NULL
DROP TABLE IF EXISTS prueba;
CREATE TABLE prueba (k INTEGER);
SELECT setseed(0.1) \g /dev/null
INSERT INTO prueba SELECT (random() * 20000)::int FROM generate_series(1, 50000);
INSERT INTO prueba SELECT NULL FROM generate_series(1, 100);
CREATE INDEX idx_prueba ON prueba USING skiplist (k);
ANALYZE prueba;

-- Para 43 valores contamos las filas con =, BETWEEN, < y > (172 consultas),
-- una vez con el índice y otra recorriendo toda la tabla, y vemos cuántas coinciden.
DROP FUNCTION IF EXISTS comparar(TEXT);   -- por si quedó una versión anterior
CREATE OR REPLACE FUNCTION comparar(etiqueta TEXT)
RETURNS TABLE (escenario TEXT, filas BIGINT, usa_indice TEXT, consultas INT, iguales INT,
               k_igual_5000 TEXT, k_entre_5000_y_5100 TEXT, resultado TEXT) AS $$
DECLARE
    consulta TEXT := 'SELECT array_agg(ARRAY[
                          (SELECT count(*) FROM prueba WHERE k = v),
                          (SELECT count(*) FROM prueba WHERE k BETWEEN v AND v + 100),
                          (SELECT count(*) FROM prueba WHERE k < v),
                          (SELECT count(*) FROM prueba WHERE k > v)] ORDER BY v)
                      FROM generate_series(-500, 20500, 500) AS v';
    ejemplo1 TEXT := 'SELECT count(*) FROM prueba WHERE k = 5000';
    ejemplo2 TEXT := 'SELECT count(*) FROM prueba WHERE k BETWEEN 5000 AND 5100';
    plan TEXT;
    con_indice BIGINT[];
    sin_indice BIGINT[];
    con1 BIGINT; con2 BIGINT; sin1 BIGINT; sin2 BIGINT;
BEGIN
    SET LOCAL enable_seqscan = off;      -- obligamos a usar el índice
    SET LOCAL enable_bitmapscan = off;
    EXECUTE 'EXPLAIN SELECT * FROM prueba WHERE k = 5' INTO plan;
    EXECUTE consulta INTO con_indice;
    EXECUTE ejemplo1 INTO con1;
    EXECUTE ejemplo2 INTO con2;

    SET LOCAL enable_seqscan = on;       -- y ahora recorriendo toda la tabla
    SET LOCAL enable_indexscan = off;
    EXECUTE consulta INTO sin_indice;
    EXECUTE ejemplo1 INTO sin1;
    EXECUTE ejemplo2 INTO sin2;

    -- Armamos la fila que se muestra
    escenario := etiqueta;
    SELECT count(*) INTO filas FROM prueba;
    usa_indice := CASE WHEN plan LIKE '%idx_prueba%' THEN 'sí' ELSE 'no' END;
    SELECT count(*), count(*) FILTER (WHERE a = b) INTO consultas, iguales
    FROM unnest(con_indice, sin_indice) AS t(a, b);           -- consulta por consulta
    k_igual_5000 := con1 || ' | ' || sin1;
    k_entre_5000_y_5100 := con2 || ' | ' || sin2;
    resultado := CASE WHEN usa_indice = 'no' THEN 'FALLA (no usó el índice)'
                      WHEN iguales = consultas AND con1 = sin1 AND con2 = sin2 THEN 'PASA'
                      ELSE 'FALLA (' || (consultas - iguales) || ' distintas)' END;
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

\echo ''
\echo 'Cada escenario cuenta las filas con =, BETWEEN, < y > para 43 valores (172 consultas),'
\echo 'una vez usando el índice y otra recorriendo toda la tabla. Si todas coinciden: PASA.'
\echo 'Las columnas de ejemplo muestran: filas con índice | filas sin índice.'
\echo ''
\echo '>> 1. Creamos el índice sobre 50 000 claves (con repetidas) y 100 NULL'
SELECT * FROM comparar('1. después de construir');

\echo '>> 2. Insertamos 20 000 filas nuevas'
INSERT INTO prueba SELECT (random() * 20000)::int FROM generate_series(1, 20000);
SELECT * FROM comparar('2. después de 20 000 inserciones');

\echo '>> 3. Borramos las claves múltiplo de 7 y pasamos VACUUM'
DELETE FROM prueba WHERE k % 7 = 0;
VACUUM prueba;
SELECT * FROM comparar('3. después de DELETE + VACUUM');

-- PostgreSQL reutiliza el espacio de las filas borradas: el índice no debe confundirse
\echo '>> 4. Insertamos 10 000 filas más (PostgreSQL reutiliza el espacio de las borradas)'
INSERT INTO prueba SELECT (random() * 20000)::int FROM generate_series(1, 10000);
SELECT * FROM comparar('4. insertar después de VACUUM');
