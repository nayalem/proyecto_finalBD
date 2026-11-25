--en_vivo_caido.sql caida del nodo c en vivo
\set QUIET on
\pset pager off
\pset footer off
SET client_min_messages = warning;
SET statement_timeout = '30s';   --no esperar siempre

\echo
\echo '=== 1. Con el nodo C apagado, leemos un voluntario de la zona Sur (sus datos estan en C) ==='
\echo 'Puede tardar unos segundos en fallar: red.py intenta llegar a C y no lo encuentra.'
\timing on
SELECT count(*) AS participaciones FROM participacion WHERE id_voluntario = 3 AND zona = 3;
\timing off
\echo '-> Fallo: sin el nodo C no hay forma de llegar a esos datos.'

\echo
\echo '=== 2. Las zonas Norte (en A) y Centro (en B) siguen funcionando ==='
SELECT 'Norte' AS zona, count(*) AS participaciones FROM participacion WHERE id_voluntario = 1 AND zona = 1
UNION ALL SELECT 'Centro', count(*) FROM participacion WHERE id_voluntario = 2 AND zona = 2;

\echo
\echo '=== 3. Pasamos la zona Sur a su replica, que esta en A (anillo A -> B -> C -> A) ==='
SELECT format('ALTER SERVER nodo_3 OPTIONS (SET host %L, SET port %L)', :'host_a', :'port_a') \gexec
\echo 'El servidor remoto nodo_3 ahora apunta a A, que tiene la copia del fragmento de C.'
\timing on
SELECT count(*) AS participaciones FROM participacion WHERE id_voluntario = 3 AND zona = 3;
\timing off
\echo '-> Funciona otra vez, y desde A es local (unos ms).'

\echo
\echo '=== 4. Dejamos nodo_3 apuntando otra vez a C ==='
SELECT format('ALTER SERVER nodo_3 OPTIONS (SET host %L, SET port %L)', :'host_c', :'port_c') \gexec
\echo 'Ahora hay que prender C:  docker compose -f distribuido/docker-compose.yml start nodo_c'
