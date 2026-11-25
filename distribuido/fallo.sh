#!/bin/bash
#fallo.sh nodo c caido con e1 (pedro)
#1 docker compose -f distribuido/docker-compose.yml stop nodo_c
#2 docker compose -f distribuido/docker-compose.yml run --rm --no-deps cliente bash distribuido/fallo.sh
#3 docker compose -f distribuido/docker-compose.yml start nodo_c y montar.sh
set -e
cd "$(dirname "$0")/.."
source distribuido/comun.sh
mkdir -p distribuido/resultados
CSV=distribuido/resultados/fallo.csv
echo "nodo,paso,repeticion,zona,operacion,intentos,exitos,ms_promedio" > $CSV
for i in 1 2; do en $i -c "SET client_min_messages = warning" -c "DROP TABLE IF EXISTS fallo_dist"; done

for paso in 1_C_caido 2_con_replica; do
    conmutar=false; [ $paso = 2_con_replica ] && conmutar=true   #paso 2 con replica
    for rep in 1 2 3 4 5; do
        for i in 1 2; do
            en $i -v nodo=${NOMBRES[$i]} -v paso=$paso -v rep=$rep -v conmutar=$conmutar -f distribuido/fallo.sql >> $CSV
        done
    done
    echo "  paso $paso listo"
done

#resumen
echo "Resultado (zona 1 = Norte en A, 2 = Centro en B, 3 = Sur en C). Exitos de las 5 repeticiones y mediana del tiempo:"
en 1 -P footer=off -c "CREATE TEMP TABLE f (nodo TEXT, paso TEXT, repeticion INT, zona INT, operacion TEXT, intentos INT, exitos INT, ms FLOAT)" \
     -c "\copy f FROM '$CSV' CSV HEADER" \
     -c "SELECT paso, nodo, operacion, zona, sum(exitos) || ' de ' || sum(intentos) AS exitos,
                round(percentile_cont(0.5) WITHIN GROUP (ORDER BY ms)::numeric, 2) AS ms_mediana
         FROM f GROUP BY 1, 2, 3, 4 ORDER BY 1, 2, 3 DESC, 4"
echo "Ojo: las escrituras de la zona Sur quedaron en la replica. Al volver C, hay que montar de nuevo (montar.sh)."
