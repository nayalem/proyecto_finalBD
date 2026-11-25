--escritura: inscribir voluntario
\set v 3 * random(0, 33332) + :z
\set a random(1, 3000)
INSERT INTO participacion (id_voluntario, zona, id_actividad, fecha, estado)
VALUES (:v, :z, :a, current_date, 'Pendiente');
