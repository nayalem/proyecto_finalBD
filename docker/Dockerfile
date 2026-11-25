#postgresql 18.6 con la extension instalada
FROM postgres:18.6

#compiladores y python
RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential postgresql-server-dev-18 python3 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /proyecto
COPY . /proyecto

#compilar extension y pruebas
RUN make -C extension clean all install \
 && make -C pruebas test_skiplist
