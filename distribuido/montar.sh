#!/bin/bash
#montar.sh armar los 3 nodos (marccelo)
#bash distribuido/montar.sh E1 skiplist
set -e
cd "$(dirname "$0")/.."
ESTRATEGIA=${1:-E1}
INDICE=${2:-skiplist}
E1=false; [ "$ESTRATEGIA" = "E1" ] && E1=true
source distribuido/comun.sh
OPC="-v estrategia=$ESTRATEGIA -v e1=$E1 -v indice=$INDICE"

#generar datos si faltan
[ -f distribuido/datos/participacion.csv ] || python3 distribuido/generar_datos.py

echo "== 0. Esperamos a los 3 nodos y pausamos las replicas de una corrida anterior"
#pausar replicas, indice sin wal
for i in 1 2 3; do
    until en $i -c "SELECT 1" > /dev/null 2>&1; do sleep 2; done
    echo "SELECT format('ALTER SUBSCRIPTION %I DISABLE', subname) FROM pg_subscription WHERE subenabled \\gexec" | en $i
done
for i in 1 2 3; do   #esperar envios
    until [ "$(en $i -At -c "SELECT count(*) FROM pg_replication_slots WHERE active")" = "0" ]; do sleep 1; done
done

echo "== 1. Esquema en los 3 nodos ($ESTRATEGIA, indice $INDICE)"
for i in 1 2 3; do en $i $OPC -f distribuido/esquema.sql; done

echo "== 2. Carga de datos"
#catalogos completos
for i in 1 2 3; do
    en $i -c "\copy organizacion FROM 'distribuido/datos/organizacion.csv' CSV" \
          -c "\copy actividad FROM 'distribuido/datos/actividad.csv' CSV"
done
#fragmento propio
for i in 1 2 3; do en $i $OPC -f distribuido/cargar.sql; done

echo "== 3. Indices"
for i in 1 2 3; do en $i $OPC -f distribuido/indices.sql; done

echo "== 4. Replicas"
for i in 1 2 3; do en $i -v publicar=true -f distribuido/replicacion.sql; done
for i in 1 2 3; do
    ant=$(( (i + 1) % 3 + 1 ))   #nodo anterior
    read h p <<< "$(direccion $i $ant)"
    en $i -v publicar=false -v host_ant=$h -v port_ant=$p -f distribuido/replicacion.sql
done
#esperar copia de replicas
for i in 1 2 3; do
    until [ "$(en $i -At -c "SELECT count(*) FROM pg_subscription_rel WHERE srsubstate <> 'r'")" = "0" ]; do sleep 2; done
    en $i -c "ANALYZE organizacion, actividad, frag.voluntario_1, frag.voluntario_2, frag.voluntario_3, frag.participacion_1, frag.participacion_2, frag.participacion_3;"
done

echo "== Listo. Filas por nodo (propias / replica):"
for i in 1 2 3; do
    ant=$(( (i + 1) % 3 + 1 ))
    echo "  Nodo ${NOMBRES[$i]}: $(en $i -At -c "SELECT count(*) FROM frag.participacion_$i") participaciones propias," \
         "$(en $i -At -c "SELECT count(*) FROM frag.participacion_$ant") de replica (del nodo ${NOMBRES[$ant]})"
done
