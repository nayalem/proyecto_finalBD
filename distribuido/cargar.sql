--cargar.sql filas del fragmento propio (marccelo)
\set ON_ERROR_STOP on
CREATE TEMP TABLE v (LIKE frag.voluntario_1);
CREATE TEMP TABLE p (LIKE frag.participacion_1);
\copy v FROM 'distribuido/datos/voluntario.csv' CSV
\copy p FROM 'distribuido/datos/participacion.csv' CSV
--por zona
\if :e1
SELECT format('INSERT INTO frag.voluntario_%s SELECT * FROM v WHERE zona = %s', :yo, :yo) \gexec
SELECT format('INSERT INTO frag.participacion_%s SELECT * FROM p WHERE zona = %s', :yo, :yo) \gexec
--por hash
\else
SELECT format('INSERT INTO frag.voluntario_%s SELECT * FROM v WHERE satisfies_hash_partition(%L::regclass, 3, %s, id_voluntario)',
              :yo, 'voluntario', :yo - 1) \gexec
SELECT format('INSERT INTO frag.participacion_%s SELECT * FROM p WHERE satisfies_hash_partition(%L::regclass, 3, %s, id_voluntario)',
              :yo, 'participacion', :yo - 1) \gexec
\endif
