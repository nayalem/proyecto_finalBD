#!/bin/bash
#en_vivo.sh distribuido en vivo, con e1 montado
#docker compose -f distribuido/docker-compose.yml run --rm cliente bash distribuido/en_vivo.sh [voluntario]
#caida: stop nodo_c y luego run --rm --no-deps cliente bash distribuido/en_vivo.sh caido
cd "$(dirname "$0")/.."
source distribuido/comun.sh
if [ "$1" = "caido" ]; then   #prueba de caida
    en 1 -f distribuido/en_vivo_caido.sql
else
    en 1 -v vol=${1:-0} -f distribuido/en_vivo.sql
fi
