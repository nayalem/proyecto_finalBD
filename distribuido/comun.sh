#comun.sh direcciones y psql por nodo
HOSTS=("" ${HOST_A:-nodo_a} ${HOST_B:-nodo_b} ${HOST_C:-nodo_c})
PORTS=("" ${PORT_A:-5432} ${PORT_B:-5432} ${PORT_C:-5432})
NOMBRES=("" A B C)
RED=${RED:-red}   #nodos via red.py
export PGUSER=postgres PGPASSWORD=postgres PGDATABASE=postgres

#direccion de nodo $2 desde $1
direccion() {
    if [ "$1" = "$2" ]; then echo "${HOSTS[$2]} ${PORTS[$2]}"; else echo "$RED 50$1$2"; fi
}

#psql en un nodo
en() {
    local i=$1; shift
    read ha pa <<< "$(direccion $i 1)"; read hb pb <<< "$(direccion $i 2)"; read hc pc <<< "$(direccion $i 3)"
    psql -q -h ${HOSTS[$i]} -p ${PORTS[$i]} -v yo=$i -v host_a=$ha -v port_a=$pa -v host_b=$hb -v port_b=$pb \
         -v host_c=$hc -v port_c=$pc "$@"
}
