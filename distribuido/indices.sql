--indices.sql indices de cada nodo (pedro)
--variable indice: skiplist o btree
\set ON_ERROR_STOP on
SET client_min_messages = warning;
SELECT set_config('dist.indice', :'indice', false) \g /dev/null
DO $$
BEGIN
    FOR i IN 1..3 LOOP   --propio y replica
        EXECUTE format('CREATE INDEX ON frag.participacion_%s USING %s (id_voluntario)', i, current_setting('dist.indice'));
        EXECUTE format('CREATE INDEX ON frag.participacion_%s USING btree (id_actividad)', i);
    END LOOP;
END $$;
--estadisticas locales
ANALYZE organizacion, actividad, frag.voluntario_1, frag.voluntario_2, frag.voluntario_3,
        frag.participacion_1, frag.participacion_2, frag.participacion_3;
