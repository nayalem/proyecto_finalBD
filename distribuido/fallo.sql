--fallo.sql nodo c caido (pedro)
--variables: paso, rep, conmutar
\set ON_ERROR_STOP on
SET client_min_messages = warning;
CREATE TABLE IF NOT EXISTS fallo_dist (nodo TEXT, paso TEXT, repeticion INT, zona INT, operacion TEXT, intentos INT, exitos INT, ms_promedio FLOAT);

--contar operaciones que funcionan
CREATE OR REPLACE FUNCTION probar(z INT, n INT, escribir BOOLEAN, rep INT) RETURNS TABLE (exitos INT, ms FLOAT) AS $$
DECLARE
    v INT;
    t0 TIMESTAMPTZ;
    total FLOAT := 0;
BEGIN
    exitos := 0;
    PERFORM setseed(rep / 10.0);   --semilla por repeticion
    FOR k IN 1..n LOOP
        v := 3 * floor(random() * 33333)::int + z;
        t0 := clock_timestamp();
        BEGIN
            IF escribir THEN
                INSERT INTO participacion (id_voluntario, zona, id_actividad, fecha, estado) VALUES (v, z, 1, current_date, 'Pendiente');
            ELSE
                PERFORM count(*) FROM participacion WHERE id_voluntario = v AND zona = z;
            END IF;
            exitos := exitos + 1;
            total := total + extract(epoch FROM clock_timestamp() - t0) * 1000;
        EXCEPTION WHEN OTHERS THEN
            NULL;   --nodo caido
        END;
    END LOOP;
    ms := CASE WHEN exitos > 0 THEN total / exitos END;
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

\if :conmutar
--pasar c a su replica en a
SELECT format('ALTER SERVER nodo_3 OPTIONS (SET host %L, SET port %L)', :'host_a', :'port_a') \gexec
\endif

INSERT INTO fallo_dist
SELECT :'nodo', :'paso', :rep, z, CASE WHEN e THEN 'escritura' ELSE 'lectura' END, 20, p.exitos, round(p.ms::numeric, 2)
FROM generate_series(1, 3) AS z, unnest(ARRAY[false, true]) AS e, probar(z, 20, e, :rep) AS p;
\pset format csv
\pset tuples_only on
SELECT * FROM fallo_dist WHERE paso = :'paso' AND nodo = :'nodo' AND repeticion = :rep;
