--escritura: marcar asistencia
\set v 3 * random(0, 33332) + :z
UPDATE participacion SET estado = 'Asistio'
WHERE id_voluntario = :v AND zona = :z AND estado = 'Pendiente';
