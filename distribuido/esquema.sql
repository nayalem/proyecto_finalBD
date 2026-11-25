--esquema.sql armar un nodo para e1 o e2
--variables: yo, estrategia, indice, host_x, port_x
\set ON_ERROR_STOP on
SET client_min_messages = warning;
SELECT set_config('dist.yo', :'yo', false), set_config('dist.estrategia', :'estrategia', false),
       set_config('dist.hosts', :'host_a' || ',' || :'host_b' || ',' || :'host_c', false),
       set_config('dist.ports', :'port_a' || ',' || :'port_b' || ',' || :'port_c', false) \g /dev/null

--limpiar corrida anterior
SELECT format('ALTER SUBSCRIPTION %I DISABLE', subname) FROM pg_subscription WHERE subenabled \gexec
SELECT format('ALTER SUBSCRIPTION %I SET (slot_name = NONE)', subname) FROM pg_subscription \gexec
SELECT format('DROP SUBSCRIPTION %I', subname) FROM pg_subscription \gexec
SELECT format('DROP PUBLICATION %I', pubname) FROM pg_publication \gexec
SELECT pg_drop_replication_slot(slot_name) FROM pg_replication_slots WHERE NOT active \g /dev/null
DROP SCHEMA IF EXISTS frag CASCADE;
DROP TABLE IF EXISTS participacion, voluntario, actividad, organizacion CASCADE;
DROP SEQUENCE IF EXISTS seq_participacion;
DROP EXTENSION IF EXISTS postgres_fdw CASCADE;   --borra remotas
CREATE EXTENSION IF NOT EXISTS skiplist;
CREATE EXTENSION postgres_fdw;                   --tablas remotas
--unir y agrupar en cada nodo
ALTER DATABASE postgres SET enable_partitionwise_aggregate = on;
ALTER DATABASE postgres SET enable_partitionwise_join = on;

--catalogos completos en cada nodo (nayalem)
CREATE TABLE organizacion (id_organizacion INT PRIMARY KEY, nombre TEXT, tipo TEXT, zona SMALLINT);
CREATE TABLE actividad (id_actividad INT PRIMARY KEY, nombre TEXT, fecha DATE, cupo_maximo INT,
                        id_organizacion INT REFERENCES organizacion, zona SMALLINT);

--fragmentacion en 3 (camila)
--3 fragmentos por nodo, propio y replica
CREATE SCHEMA frag;
DO $$
BEGIN
    FOR i IN 1..3 LOOP
        EXECUTE format('CREATE TABLE frag.voluntario_%s (id_voluntario INT PRIMARY KEY, nombres TEXT, apellidos TEXT,
                        dni INT, zona SMALLINT, fecha_registro DATE)', i);
        EXECUTE format('CREATE TABLE frag.participacion_%s (id_participacion BIGINT PRIMARY KEY, id_voluntario INT,
                        zona SMALLINT, id_actividad INT, fecha DATE, estado TEXT)', i);
    END LOOP;
END $$;

--tablas completas particionadas
--por zona
\if :e1
CREATE TABLE voluntario (LIKE frag.voluntario_1) PARTITION BY LIST (zona);
CREATE TABLE participacion (LIKE frag.participacion_1) PARTITION BY LIST (zona);
--por hash
\else
CREATE TABLE voluntario (LIKE frag.voluntario_1) PARTITION BY HASH (id_voluntario);
CREATE TABLE participacion (LIKE frag.participacion_1) PARTITION BY HASH (id_voluntario);
\endif

--particiones locales y remotas
DO $$
DECLARE
    yo     INT    := current_setting('dist.yo')::int;
    hosts  TEXT[] := string_to_array(current_setting('dist.hosts'), ',');
    ports  TEXT[] := string_to_array(current_setting('dist.ports'), ',');
    limite TEXT;
BEGIN
    FOR i IN 1..3 LOOP
        --e1 zona i, e2 hash i-1
        limite := CASE WHEN current_setting('dist.estrategia') = 'E1' THEN format('IN (%s)', i)
                       ELSE format('WITH (MODULUS 3, REMAINDER %s)', i - 1) END;
        IF i = yo THEN   --fragmento local
            EXECUTE format('ALTER TABLE voluntario ATTACH PARTITION frag.voluntario_%s FOR VALUES %s', i, limite);
            EXECUTE format('ALTER TABLE participacion ATTACH PARTITION frag.participacion_%s FOR VALUES %s', i, limite);
        ELSE             --fragmento remoto
            EXECUTE format('CREATE SERVER nodo_%s FOREIGN DATA WRAPPER postgres_fdw
                            OPTIONS (host %L, port %L, dbname ''postgres'', batch_size ''1000'')', i, hosts[i], ports[i]);
            EXECUTE format('CREATE USER MAPPING FOR postgres SERVER nodo_%s OPTIONS (user ''postgres'', password ''postgres'')', i);
            EXECUTE format('CREATE FOREIGN TABLE voluntario_remoto_%s PARTITION OF voluntario FOR VALUES %s
                            SERVER nodo_%s OPTIONS (schema_name ''frag'', table_name ''voluntario_%s'')', i, limite, i, i);
            EXECUTE format('CREATE FOREIGN TABLE participacion_remoto_%s PARTITION OF participacion FOR VALUES %s
                            SERVER nodo_%s OPTIONS (schema_name ''frag'', table_name ''participacion_%s'')', i, limite, i, i);
        END IF;
    END LOOP;
END $$;

--ids sin choque entre nodos
SELECT format('CREATE SEQUENCE seq_participacion START %s INCREMENT 3', 1000000 + :yo) \gexec
ALTER TABLE participacion ALTER COLUMN id_participacion SET DEFAULT nextval('seq_participacion');
