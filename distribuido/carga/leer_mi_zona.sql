--lectura local
\set v 3 * random(0, 33332) + :z
SELECT a.nombre, p.fecha, p.estado
FROM participacion p JOIN actividad a ON a.id_actividad = p.id_actividad
WHERE p.id_voluntario = :v AND p.zona = :z;
