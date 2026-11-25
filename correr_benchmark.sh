#!/bin/bash
#correr_benchmark.sh benchmark con d2 (pedro)
#docker compose exec db bash experimentos/correr_benchmark.sh
set -e
cd "$(dirname "$0")/.."
PSQL=${PSQL:-"psql -U postgres -q"}
REPS=5
TAMANOS=${TAMANOS:-"100000 500000 1000000"}

mkdir -p experimentos/resultados
$PSQL -c "SET client_min_messages = warning" -c "DROP TABLE IF EXISTS benchmark CASCADE" > /dev/null
for n in $TAMANOS; do   #cada tamano y dataset
    for d in D2; do
        echo "== $d con $n claves ($(date +%H:%M))"
        $PSQL -v dataset=$d -v n=$n -v reps=$REPS -f experimentos/benchmark.sql
    done
done
#guardar csv
$PSQL -P pager=off -c "\copy benchmark TO 'experimentos/resultados/benchmark_repeticiones.csv' CSV HEADER"
