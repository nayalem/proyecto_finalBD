# Índice Skip List para PostgreSQL

Proyecto del curso Base de Datos II (UCSP, 2026-2). Hicimos nuestra propia Skip List en C++ y la conectamos a PostgreSQL 18.6 como un nuevo tipo de índice (etapa 1). Después la evaluamos con los datasets y cargas de la guía, y armamos un escenario distribuido con tres nodos (etapa 2).

```sql
CREATE EXTENSION skiplist;
CREATE INDEX idx_recurso ON recurso USING skiplist (recurso_id);
```

**Equipo:** Camila Mansilla · Nayalem Arune · Marccelo Tito · Rodrigo Fuentes · Pedro Flores

## Cómo correrlo (desde cero)

Solo se necesita Docker.

### Etapa 1: el índice

```bash
# 1. Levantar PostgreSQL 18.6 con la extensión ya instalada
docker compose up -d --build

# 2. Pruebas de la Skip List en memoria (sin PostgreSQL)
docker compose exec db make -C pruebas

# 3. Demo dentro de PostgreSQL: buscar, insertar y rango
docker compose exec db psql -U postgres -f sql/demo.sql

# 4. Prueba de integración: el índice devuelve lo mismo que sin índice
docker compose exec db psql -U postgres -f pruebas/prueba_integracion.sql

# 5. Primera comparación (100 000 claves)
docker compose exec db psql -U postgres -f experimentos/comparacion.sql
```

Todo lo que se muestra en la consola está sin tildes ni ñ, para que se vea bien en cualquier terminal.

Otros comandos útiles:
- Menú para probar la Skip List a mano: `docker compose exec db make -C pruebas programa` y luego `docker compose exec -it db ./pruebas/programa`
- Entrar a PostgreSQL: `docker compose exec db psql -U postgres`
- Reiniciar y comprobar que el índice sigue bien: `docker compose restart` y luego `docker compose exec db psql -U postgres -P pager=off -c "SELECT * FROM comparar('despues de reiniciar')"`
- Borrar todo y empezar de cero: `docker compose down -v && docker compose up -d --build`

### Etapa 2: benchmark (con el contenedor de la etapa 1)

```bash
docker compose exec db bash experimentos/correr_benchmark.sh rapido   # alrededor de 1 hora
docker compose exec db bash experimentos/correr_benchmark.sh          # completo: varias horas
docker compose exec db bash experimentos/correr_benchmark.sh solo_indices   # solo B-tree y Skip List: unos 15 minutos
```

Genera D1, D2 y D3 con 100 000, 500 000 y 1 000 000 de claves, mide sin índice, B-tree y Skip List 5 veces y muestra las medianas. Los resultados quedan en `experimentos/resultados/`. En modo `rapido`, el escenario sin índice hace 1000 búsquedas en vez de 10 000 (cada una recorre toda la tabla, así que el tiempo por consulta casi no cambia); los otros dos escenarios hacen siempre las 10 000. Casi todo el tiempo del modo completo (más del 98 %) se va en el escenario sin índice, que recorre la tabla entera en cada búsqueda. Por eso, si solo cambia el índice, el modo `solo_indices` vuelve a medir B-tree y Skip List y conserva las mediciones sin índice de la última corrida completa guardada en `experimentos/resultados/` (antes de usarlo hay que reconstruir la imagen con `docker compose up -d --build` para que compile la versión nueva de la extensión).

### Etapa 2: escenario distribuido (tres nodos)

```bash
# 1. Levantar los nodos A, B y C, la red con latencias y construir la imagen
docker compose -f distribuido/docker-compose.yml up -d --build

# 2. Todos los experimentos (unos 30-40 minutos): monta cada estrategia, lanza las consultas y la carga 70/30
docker compose -f distribuido/docker-compose.yml run --rm cliente bash distribuido/experimentos.sh

# 3. Prueba de fallo: apagar el nodo C, probar desde A y B, y volver a prenderlo
docker compose -f distribuido/docker-compose.yml stop nodo_c
docker compose -f distribuido/docker-compose.yml run --rm --no-deps cliente bash distribuido/fallo.sh
docker compose -f distribuido/docker-compose.yml start nodo_c
docker compose -f distribuido/docker-compose.yml run --rm cliente bash distribuido/montar.sh E1 skiplist
```

Para montar una sola estrategia: `... run --rm cliente bash distribuido/montar.sh E2 btree`. Para entrar a un nodo: `docker compose -f distribuido/docker-compose.yml exec nodo_a psql -U postgres`. Los resultados quedan en `distribuido/resultados/`.

### Pruebas en vivo (para la defensa)

```bash
# Un nodo: la Skip List frente al B-tree y sin índice, paso a paso (unos segundos)
docker compose exec db psql -U postgres -f sql/en_vivo.sql
docker compose exec db psql -U postgres -v clave=4321 -v desde=500 -v hasta=530 -f sql/en_vivo.sql   # con una clave y un rango elegidos

# Distribuido (con E1 montado): local frente a remoto, consulta a 3 nodos e inserción
docker compose -f distribuido/docker-compose.yml run --rm cliente bash distribuido/en_vivo.sh
docker compose -f distribuido/docker-compose.yml run --rm cliente bash distribuido/en_vivo.sh 12345   # sigue a ese voluntario

# Caída del nodo C y paso a la réplica
docker compose -f distribuido/docker-compose.yml stop nodo_c
docker compose -f distribuido/docker-compose.yml run --rm --no-deps cliente bash distribuido/en_vivo.sh caido
docker compose -f distribuido/docker-compose.yml start nodo_c
```

Cada paso imprime qué hay que mirar. `sql/en_vivo.sql` deja creadas las tablas `vivo_sin`, `vivo_bt` y `vivo_sl` para seguir probando a mano.

## Qué hay en el repositorio

| Carpeta | Contenido |
|---|---|
| `src/` | La Skip List en memoria: `skip_list.h` (construir, buscar, insertar, rango, mostrar) y `main.cpp` (menú) |
| `extension/` | La Skip List dentro de PostgreSQL: `skiplist.h` (el nodo), `paginas.cpp` (nodos en páginas), `operaciones.cpp` (buscar e insertar), `postgres.cpp` (lo que llama PostgreSQL), más `skiplist--1.0.sql`, `skiplist.control` y `Makefile` |
| `pruebas/` | `test_skiplist.cpp` (en memoria) y `prueba_integracion.sql` (dentro de PostgreSQL) |
| `sql/` | `demo.sql`: la demo del parcial; `en_vivo.sql`: prueba en vivo para la defensa |
| `datos/` | Generadores con semilla fija: `generar_datos.py` (datasets D1, D2, D3) y `generar_cargas.py` (cargas W1–W4). Los archivos generados quedan en `datos/generados/` (no se suben) |
| `experimentos/` | `comparacion.sql` (primera comparación, etapa 1), `benchmark.sql` (mide un dataset en los 3 escenarios), `correr_benchmark.sh` (corre todo), `resumen.sql` (tablas comparativas) y `resultados/` |
| `distribuido/` | Escenario de 3 nodos: `docker-compose.yml`, `red.py` (latencias), `generar_datos.py` (esquema de voluntariado), `esquema.sql`, `cargar.sql`, `indices.sql`, `replicacion.sql`, `montar.sh`, `consultas.sql`, `carga.sh` y `carga/` (pgbench), `fallo.sql`/`fallo.sh`, `experimentos.sh`, `resumen.sql`, `en_vivo.sh` (prueba en vivo) y `resultados/` |
| `docker/` | `Dockerfile` (PostgreSQL 18.6 + compilación de la extensión) |
| `docs/` | Propuesta, `Informe_Final.pdf` (y su fuente LaTeX en `informe_final_latex/`), el informe de la etapa 1, `Estructura_del_Proyecto.pdf` (cómo está organizado todo y quién hizo qué) e informes semanales e individuales |
| `PROYECTO FINAL SQL/`, `skip_list.cpp` | Trabajo previo del grupo (proyecto de Base de Datos I y primera versión de la Skip List); se mantienen como referencia |

## Cómo funciona

```
SELECT ... WHERE recurso_id = 50
        │
PostgreSQL elige el índice skiplist
        │
postgres.cpp      recibe el pedido (CREATE INDEX, INSERT, SELECT, VACUUM)
        │
operaciones.cpp   la Skip List: buscar e insertar
        │
paginas.cpp       lee y guarda los nodos en las páginas del índice (8 KB)
```

- `src/skip_list.h` y `extension/operaciones.cpp` tienen **la misma lógica**. La diferencia es que en PostgreSQL los nodos están en disco y no en la RAM, así que en vez de `actual = actual->siguiente[i]` usamos `actual = leerNodo(indice, actual.siguiente[i])`.
- **Construcción:** CREATE INDEX junta todas las claves, las ordena y arma la lista de izquierda a derecha, enganchando cada nodo detrás del último de cada nivel (sin buscar su lugar). **Búsqueda:** baja por los niveles. **Inserción:** guarda el nodo anterior de cada nivel y enlaza el nuevo. **Rango:** después de buscar, avanza por el nivel 0.
- **VACUUM:** marca como borrados los nodos de filas eliminadas (no los saca).

## La Skip List frente al B-tree

| Operación | Skip List (caso esperado) | Peor caso |
|---|---|---|
| Búsqueda | O(log n) | O(n), muy poco probable |
| Inserción | O(log n) | O(n) |
| Rango con k resultados | O(log n + k) | O(n) |

**Ventajas**
- Es mucho más simple: no hay que rebalancear nada, los niveles salen de "tirar una moneda".
- Insertar solo cambia unos pocos enlaces cerca del nodo nuevo.
- El nivel 0 tiene todas las claves en orden, así que los rangos salen fácil.

**Limitaciones**
- Es probabilística: casi siempre es O(log n), pero no está garantizado como en el B-tree.
- Guarda una clave por nodo, mientras el B-tree guarda cientos por página. Por eso, en disco, la Skip List lee más páginas, ocupa más y es más lenta al construir e insertar.

## Etapa 1: primera comparación

`experimentos/comparacion.sql` fue la primera comparación (100 000 claves aleatorias, semilla fija, 5 repeticiones). Resultados en Docker (mediana):

| Medida | Sin índice | B-tree | Skip List |
|---|---|---|---|
| Construcción (ms) | – | 27.5 | 370.6 |
| W1 búsqueda exitosa (ms por consulta) | 3.47 | 0.0081 | 0.0069 |
| W2 búsqueda no exitosa (ms por consulta) | 3.49 | 0.0036 | 0.0061 |
| W4 rango (ms por consulta) | 4.19 | 0.036 | 0.043 |
| W3 inserción del 10% (ms en total) | 3.9 | 17.7 | 51.3 |
| Tamaño del índice (MB) | – | 2.7 | 3.8 |

## Etapa 2: evaluación del índice

**Datos** (`datos/generar_datos.py`, semilla 42), cada uno con 100 000, 500 000 y 1 000 000 de claves:
- **D1:** enteros secuenciales 1..N.
- **D2:** N enteros aleatorios distintos entre 1 y 10·N.
- **D3:** las mismas claves de D2, pero las búsquedas W1 siguen una distribución Zipf (parámetro 1.1): unas pocas claves se buscan muchísimo.

**Cargas** (`datos/generar_cargas.py`, semilla 43): W1 = 10 000 búsquedas de claves que existen; W2 = 10 000 de claves que no existen; W3 = 10 % de inserciones (en D1, claves siguientes en orden); W4 = 1000 rangos de unas 100 claves. W5 (prefijos) no aplica porque la clave es un entero.

**Cómo se mide** (`experimentos/benchmark.sql`): los tres escenarios usan exactamente los mismos datos y operaciones. Por cada repetición se copia la tabla, se crea el índice (tiempo de construcción y tamaño), se lanzan W1, W2 y W4 una consulta a la vez (con índice se obliga a usarlo), se cuentan las **páginas leídas por búsqueda** con `EXPLAIN (BUFFERS)` y al final se hace W3. Cada medición se repite **5 veces** y se reporta la **mediana**, porque no la mueve una repetición rara (por ejemplo, una que coincidió con otra tarea del equipo). Las condiciones (versión, configuración, semillas, repeticiones) quedan en `experimentos/resultados/entorno.txt`.

**Carga favorable y no favorable:** las búsquedas por igualdad (W1, W2) y el acceso sesgado (D3) son favorables a la Skip List; construir, insertar y los rangos son no favorables, porque cada salto entre nodos puede ser otra página.

## Etapa 2: escenario distribuido

```
                cliente (pgbench, scripts)
           ┌───────────┼───────────┐
        nodo A      nodo B      nodo C        PostgreSQL 18.6 + skiplist + postgres_fdw
       (Norte)     (Centro)     (Sur)
           └──── red.py: A-B 20 ms · A-C 40 ms · B-C 25 ms ────┘
```

- **Esquema** (basado en nuestro proyecto de BD1, voluntariado): `organizacion` (30), `actividad` (3000), `voluntario` (99 999) y `participacion` (**1 000 000**). Cada voluntario y su participación tienen una zona: 1 = Norte, 2 = Centro, 3 = Sur. El 80 % de las veces un voluntario va a actividades de su zona.
- **Latencias:** los nodos no se hablan directo, sino a través de `red.py`, que reenvía todo esperando la mitad de la latencia en cada sentido (la latencia de la guía la tomamos como ida y vuelta). El cliente se conecta directo a cada nodo, como si cada usuario estuviera cerca de su nodo.
- **Fragmentación y asignación** (`esquema.sql`), dos estrategias:
  - **E1, por zona:** `voluntario` y `participacion` se parten por zona; Norte va a A, Centro a B y Sur a C.
  - **E2, por hash del voluntario:** se parten por `hash(id_voluntario)`, así que cada zona queda repartida en los tres nodos.
  
  En los dos casos cada nodo ve las tablas completas: su parte es local y las otras son tablas remotas (`postgres_fdw`) colgadas como particiones. PostgreSQL decide solo a qué nodo ir.
- **Replicación** (`replicacion.sql`): `organizacion` y `actividad` son pequeñas y casi no cambian, así que están completas en los tres nodos (A las publica y B y C reciben los cambios). Además, el fragmento de cada nodo se copia al siguiente (A→B, B→C, C→A) con la replicación lógica de PostgreSQL, para seguir leyendo si un nodo se cae.
- **Índices** (`indices.sql`): para buscar por voluntario se usa la Skip List o el B-tree (se comparan los dos); la clave primaria y la búsqueda por actividad usan B-tree.
- **Consultas** (`consultas.sql`): un voluntario de cada zona (local o remoto según la estrategia), la asistencia de una actividad (cada nodo devuelve solo las filas de esa actividad) y un listado de un mes con el nombre del voluntario (muchas filas por la red). Se mide el tiempo y cuántas filas llegaron de otros nodos.
- **Carga 70/30** (`carga.sh`, pgbench con semilla fija): 50 % leer un voluntario de mi zona, 10 % de otra zona, 10 % la asistencia de una actividad, 20 % inscribir y 10 % marcar asistencia. Dos clientes en cada nodo a la vez, 20 segundos, 5 repeticiones. **Cambio de carga:** en la versión `concentrada` todos los clientes piden datos de la zona Sur.
- **Fallo** (`fallo.sh`): con E1 y el nodo C apagado, A y B intentan leer y escribir en las tres zonas; después se pasa la zona Sur a su réplica (en A) y se vuelve a probar. Cada paso se repite 5 veces (20 intentos por zona y operación).

## Etapa 2: resultados (Docker, PostgreSQL 18.6)

Todo el detalle está en `experimentos/resultados/` y `distribuido/resultados/` (cada repetición, medianas y condiciones). El escenario sin índice viene de la corrida completa (10 000 búsquedas en W1 y W2); B-tree y Skip List se volvieron a medir con `solo_indices` después de agregar la construcción ordenada, en el mismo equipo.

**Benchmark con D2 (aleatorio), mediana de 5 repeticiones**

| Medida | Claves | Sin índice | B-tree | Skip List |
|---|---|---|---|---|
| W1 búsqueda exitosa (ms por consulta) | 100 000 | 3.45 | 0.0040 | 0.0063 |
| | 1 000 000 | 18.57 | 0.0093 | 0.0179 |
| W2 búsqueda no exitosa (ms por consulta) | 100 000 | 3.45 | 0.0032 | 0.0047 |
| | 1 000 000 | 18.80 | 0.0043 | 0.0092 |
| W4 rango (ms por consulta) | 100 000 | 4.19 | 0.0549 | 0.0505 |
| | 1 000 000 | 19.44 | 0.1156 | 0.0833 |
| Construcción (ms) | 100 000 | – | 29.0 | 78.2 |
| | 1 000 000 | – | 303.1 | 854.9 |
| W3 inserción del 10% (ms en total) | 100 000 | 4.1 | 12.5 | 44.9 |
| | 1 000 000 | 38.3 | 245.9 | 1005.9 |
| Tamaño del índice (MB) | 1 000 000 | – | 21.4 | 34.5 |
| Páginas leídas por búsqueda | 1 000 000 | 4464 | 4 | 49.5 |

- La Skip List busca **más de 1000 veces más rápido que sin índice**, pero unas **2 veces más lento que el B-tree**: cada nodo visitado es un acceso a una página (unos 49 contra 4). En **rangos** con claves aleatorias es **más rápida** que el B-tree (0.083 contra 0.116 ms con 1 millón).
- **Construcción:** antes se construía insertando clave por clave y tardaba unas 20 veces lo del B-tree (6.3 s con 1 millón). Con la **construcción ordenada** (juntar, ordenar y enlazar de izquierda a derecha) bajó a 0.85 s, unas **3 veces** lo del B-tree, y ahora crece igual que el B-tree con el volumen (unas 11 veces al pasar de 100 mil a 1 millón).
- **Insertar** es lo que más le cuesta ahora (entre 2 y 6 veces lo del B-tree). El **tamaño** es siempre 1.6 veces el del B-tree.
- Con **D1** (claves en orden) construye un 20 % e inserta un 36 % más rápido que con D2. Con **D3** (búsquedas concentradas) las búsquedas son un 40 % más rápidas en los dos índices, pero el B-tree sigue unas 1.8 veces adelante.

**Escenario distribuido: consultas desde el nodo A (mediana de 5)**

| Consulta | E1 por zona (ms) | E2 por hash (ms) | Filas por la red (E1 / E2) |
|---|---|---|---|
| Voluntario de la zona Norte | 0.02 | 0.02 | 0 / 0 |
| Voluntario de la zona Centro | 62 | 122 | 5 / 5 |
| Voluntario de la zona Sur | 123 | 0.01 | 7 / 0 |
| Asistencia de una actividad (3 nodos) | 185 | 246 | 58 / 247 |
| Participantes de un mes con su nombre | 27 998 | 7 259 | 89 658 / 22 664 |

**Carga 70/30 (los 3 nodos juntos, mediana de 5)**

| Escenario | Transacciones por segundo | Leer de mi zona (ms) | Inscribir (ms) |
|---|---|---|---|
| E1 por zona, Skip List, normal | 119.9 | 0.38 | 0.73 |
| E1 por zona, B-tree, normal | 119.9 | 0.39 | 0.75 |
| E2 por hash, Skip List, normal | 48.6 | 102.5 | 100.9 |
| E1 por zona, Skip List, concentrada en la zona Sur | 58.1 | 70.2 | 67.5 |
| E2 por hash, Skip List, concentrada en la zona Sur | 49.6 | 99.3 | 102.2 |

- Una consulta remota cuesta unas **3 idas y vueltas** (62 ms con B a 20 ms, 123 ms con C a 40 ms). Lo que más pesa es **traer muchas filas**: van de 100 en 100, así que 90 mil filas tardan 28 segundos.
- **E1** gana con la carga normal (2.5 veces más transacciones) porque casi todo es local. Si los accesos se **concentran** en una zona, E1 cae a la mitad y **E2 casi no cambia**: reparte todo, pero casi todo es remoto.
- En E2 el listado del mes trae 4 veces menos filas, porque `voluntario` y `participacion` están partidas igual (por voluntario) y cada nodo hace su parte del JOIN.
- **Skip List o B-tree en los nodos:** igual (119.9 transacciones por segundo con los dos). Las operaciones locales tardan menos de 1 ms con cualquiera; la red es lo que manda.

**Fallo del nodo C (E1, 5 repeticiones de 20 intentos por caso):** con C apagado, desde A y B se lee y escribe sin problema en Norte y Centro, y la zona Sur falla 100 de 100. Al pasar la zona Sur a su réplica (en A) vuelve a funcionar 100 de 100: desde A en 1 ms (es local) y desde B en unos 94 ms.

## Alcance y limitaciones

- **Lenguaje:** la guía pide C para la parte que va dentro de PostgreSQL; usamos C++ con autorización de la docente. Las cabeceras de PostgreSQL se incluyen dentro de `extern "C"`.
- La clave es `INTEGER`. Se soportan `=`, `<`, `<=`, `>`, `>=` y `BETWEEN`.
- No hay WAL propio: si PostgreSQL se cae de golpe (por ejemplo, se apaga la computadora sin detener Docker) el índice puede quedar mal y hay que hacer `REINDEX`. Un reinicio normal no tiene problema. En el escenario distribuido basta con volver a correr `montar.sh`, que rehace todo.
- Solo un `INSERT` modifica el índice a la vez. Las búsquedas siguen funcionando mientras tanto.
- No soporta tablas `UNLOGGED` ni índices de varias columnas. El borrado es lógico: el espacio no se reutiliza.
- La construcción ordenada junta todas las claves en memoria antes de ordenarlas (unos 12 MB por millón de filas).
- La altura máxima es de 16 niveles: con más de unas 65 000 claves el nivel más alto acumula nodos y la búsqueda da más pasos.
- **Distribuido:** el paso a la réplica es manual (un `ALTER SERVER`). Lo que se escribe en la réplica mientras C está caído no vuelve solo a C: al prenderlo hay que montar de nuevo. `red.py` simula la latencia, no un límite de ancho de banda. Todos los nodos corren en la misma máquina.

## Recursos externos y uso de IA

- W. Pugh, *Skip Lists: A Probabilistic Alternative to Balanced Trees*, Communications of the ACM 33(6), 1990.
- Documentación oficial de PostgreSQL 18: *Index Access Method Interface Definition*, *Extending SQL*.
- El módulo `contrib/bloom` de PostgreSQL se consultó como ejemplo de la estructura de un índice (no se copió código).
- Documentación de PostgreSQL 18 sobre `postgres_fdw`, particionamiento, replicación lógica y `pgbench` (herramientas de PostgreSQL que usamos en la etapa 2, no código nuestro).
- **Uso de inteligencia artificial** (Anthropic, Claude): la usamos como apoyo, siempre bajo la supervisión del grupo, para
  - aprender sobre la Skip List a partir de escenarios en los que se utiliza;
  - entender de manera general cómo funciona PostgreSQL (páginas y nuevos tipos de índice);
  - revisar partes del código, ya que era extenso;
  - automatizar las pruebas (el uso más necesario);
  - revisar la ortografía y la redacción del informe en LaTeX.

  El grupo revisó y validó cada resultado, y cada integrante puede explicar las partes a su cargo.

## Avance por semana

Lo que hizo cada integrante, según el plan de trabajo, está en `docs/Estructura_del_Proyecto.pdf` y en los informes de `docs/informes/`.

- [x] Semana 1: comprensión y diseño
- [x] Semana 2: construcción y búsqueda con pruebas
- [x] Semana 3: inserción, rango y esqueleto de la extensión
- [x] Semana 4: integración con PostgreSQL
- [x] Semana 5: demo reproducible y comparación preliminar con B-tree
- [x] Semana 6: benchmark de los tres escenarios con repeticiones
- [x] Semana 7: escenario sin índice, B-tree y páginas leídas
- [x] Semana 8: generadores de datos y cargas, tablas comparativas y diseño distribuido
- [x] Semana 9: tres nodos en Docker, montaje, consultas y carga 70/30
- [x] Semana 10: prueba de fallo, experimentos distribuidos e informe final
