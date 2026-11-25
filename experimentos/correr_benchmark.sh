#!/bin/bash
#correr_benchmark.sh benchmark completo (marccelo y pedro)
#docker compose exec db bash experimentos/correr_benchmark.sh [rapido|solo_indices]
#rapido: 1000 busquedas sin indice
#solo_indices: repetir btree y skip list
set -e
cd "$(dirname "$0")/.."
PSQL=${PSQL:-"psql -U postgres -q"}
REPS=5
SIN_INDICE=10000
ESCENARIOS="sin_indice,btree,skiplist"
MODO=${1:-completo}
if [ "$MODO" = "rapido" ]; then SIN_INDICE=1000; fi   #modo rapido
TAMANOS=${TAMANOS:-"100000 500000 1000000"}

mkdir -p experimentos/resultados
$PSQL -c "SET client_min_messages = warning" -c "DROP TABLE IF EXISTS benchmark CASCADE" > /dev/null
if [ "$MODO" = "solo_indices" ]; then
    #reusar sin indice anterior
    ESCENARIOS="btree,skiplist"
    ANTERIOR=experimentos/resultados/benchmark_repeticiones.csv
    if [ ! -f $ANTERIOR ]; then echo "Falta $ANTERIOR: primero hay que correr el benchmark completo"; exit 1; fi
    $PSQL -c "CREATE TABLE benchmark (dataset TEXT, n INT, escenario TEXT, repeticion INT, medida TEXT, valor FLOAT)" \
          -c "\copy benchmark FROM '$ANTERIOR' CSV HEADER" > /dev/null
fi
for n in $TAMANOS; do   #cada tamano y dataset
    for d in D1 D2 D3; do
        echo "== $d con $n claves ($(date +%H:%M))"
        python3 datos/generar_datos.py $d $n
        python3 datos/generar_cargas.py $d $n
        $PSQL -v dataset=$d -v n=$n -v reps=$REPS -v sin_indice=$SIN_INDICE -v escenarios=$ESCENARIOS -f experimentos/benchmark.sql
    done
done
#resumen final
$PSQL -v reps=$REPS -v sin_indice=$SIN_INDICE -v modo=$MODO -f experimentos/resumen.sql
