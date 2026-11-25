#!/bin/bash
#carga.sh carga 70/30 con pgbench (pedro)
#bash distribuido/carga.sh <etiqueta> <normal|concentrada>
set -e
cd "$(dirname "$0")/.."
ETIQUETA=$1
CONCENTRACION=${2:-normal}
source distribuido/comun.sh
SEGUNDOS=${SEGUNDOS:-20}
mkdir -p distribuido/resultados
CSV=distribuido/resultados/carga.csv
[ -f $CSV ] || echo "escenario,concentracion,repeticion,nodo,script,segundos,transacciones,latencia_ms" > $CSV

#70 lecturas, 30 escrituras
SCRIPTS="-f distribuido/carga/leer_mi_zona.sql@50 -f distribuido/carga/leer_otra_zona.sql@10
         -f distribuido/carga/leer_actividad.sql@10 -f distribuido/carga/insertar.sql@20
         -f distribuido/carga/actualizar.sql@10"

for rep in 1 2 3 4 5; do
    for i in 1 2 3; do
        z=$i; [ "$CONCENTRACION" = "concentrada" ] && z=3   #zona sur
        #semilla fija
        pgbench -n -h ${HOSTS[$i]} -p ${PORTS[$i]} -c 2 -j 2 -T $SEGUNDOS --random-seed=$((rep * 10 + i)) \
                -D z=$z $SCRIPTS postgres > /tmp/pgbench_$i.txt 2>&1 &
    done
    wait   #3 nodos a la vez
    for i in 1 2 3; do
        #leer salida de pgbench
        awk -v e="$ETIQUETA" -v sg=$SEGUNDOS -v c="$CONCENTRACION" -v r=$rep -v n=${NOMBRES[$i]} '
            /^SQL script/ { split($4, a, "/"); s = a[3]; sub(".sql", "", s) }
            /actually processed/ && s != "" { t = $7 }
            /latency average/ && s != "" { print e "," c "," r "," n "," s "," sg "," t "," $5 }
        ' /tmp/pgbench_$i.txt >> $CSV
    done
    echo "  $ETIQUETA ($CONCENTRACION): repeticion $rep lista"
done
