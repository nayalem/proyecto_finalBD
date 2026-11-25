#!/bin/bash
#experimentos.sh todos los experimentos distribuidos
#docker compose -f distribuido/docker-compose.yml run --rm cliente bash distribuido/experimentos.sh
set -e
cd "$(dirname "$0")/.."
source distribuido/comun.sh
mkdir -p distribuido/resultados
rm -f distribuido/resultados/carga.csv
en 1 -c "SET client_min_messages = warning" -c "DROP TABLE IF EXISTS consultas_dist"

for escenario in E1-skiplist E1-btree E2-skiplist; do   #cada configuracion
    estrategia=${escenario%-*}; indice=${escenario#*-}
    echo "######## $escenario ($(date +%H:%M))"
    bash distribuido/montar.sh $estrategia $indice
    en 1 -v estrategia=$escenario -f distribuido/consultas.sql
    bash distribuido/carga.sh $escenario normal
    [ "$indice" = "skiplist" ] && bash distribuido/carga.sh $escenario concentrada
done

echo "######## Resumen"
en 1 -f distribuido/resumen.sql
bash distribuido/montar.sh E1 skiplist > /dev/null   #dejar e1 montado
echo "Quedo montado E1-skiplist. Para la prueba de fallo ver distribuido/fallo.sh"
