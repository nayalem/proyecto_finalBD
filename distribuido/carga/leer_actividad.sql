--lectura de varios nodos
\set a random(1, 3000)
SELECT estado, count(*) FROM participacion WHERE id_actividad = :a GROUP BY estado;
