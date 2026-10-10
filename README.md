# Índice Skip List para PostgreSQL

Proyecto del curso Base de Datos II (UCSP, 2026-2). Hicimos nuestra propia Skip List en C++ y la conectamos a PostgreSQL 18.6 como un nuevo tipo de índice:

```sql
CREATE EXTENSION skiplist;
CREATE INDEX idx_recurso ON recurso USING skiplist (recurso_id);
```

**Equipo:** Camila Mansilla · Nayalem Arune · Marccelo Tito · Rodrigo Fuentes · Pedro Flores

## Cómo correrlo (desde cero)

Solo se necesita Docker.

```bash
# 1. Levantar PostgreSQL 18.6 con la extensión ya instalada
docker compose up -d --build

# 2. Pruebas de la Skip List en memoria (sin PostgreSQL)
docker compose exec db make -C pruebas

# 3. Demo dentro de PostgreSQL: buscar, insertar y rango
docker compose exec db psql -U postgres -f sql/demo.sql

# 4. Prueba de integración: el índice devuelve lo mismo que sin índice
docker compose exec db psql -U postgres -f pruebas/prueba_integracion.sql

# 5. Comparación sin índice vs. B-tree vs. Skip List
docker compose exec db psql -U postgres -f experimentos/comparacion.sql
```

Otros comandos útiles:
- Menú para probar la Skip List a mano: `docker compose exec db make -C pruebas programa` y luego `docker compose exec -it db ./pruebas/programa`
- Entrar a PostgreSQL: `docker compose exec db psql -U postgres`
- Reiniciar y comprobar que el índice sigue bien: `docker compose restart` y luego `docker compose exec db psql -U postgres -P pager=off -c "SELECT * FROM comparar('después de reiniciar')"`
- Borrar todo y empezar de cero: `docker compose down -v && docker compose up -d --build`

## Qué hay en el repositorio

| Carpeta | Contenido |
|---|---|
| `src/` | La Skip List en memoria: `skip_list.h` (construir, buscar, insertar, rango, mostrar) y `main.cpp` (menú) |
| `extension/` | La Skip List dentro de PostgreSQL: `skiplist.h` (el nodo), `paginas.cpp` (nodos en páginas), `operaciones.cpp` (buscar e insertar), `postgres.cpp` (lo que llama PostgreSQL), más `skiplist--1.0.sql`, `skiplist.control` y `Makefile` |
| `pruebas/` | `test_skiplist.cpp` (en memoria) y `prueba_integracion.sql` (dentro de PostgreSQL) |
| `sql/` | `demo.sql`: la demo del parcial |
| `experimentos/` | `comparacion.sql`: mide los tres escenarios 5 veces y muestra la mediana |
| `docker/` | `Dockerfile` (PostgreSQL 18.6 + compilación de la extensión) |
| `docs/` | Propuesta, `Informe_General_Etapa_1.pdf`, `Estructura_del_Proyecto.pdf` (cómo está organizado todo y quién hizo qué) e informes semanales e individuales |
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
- **Construcción:** CREATE INDEX inserta las filas una por una. **Búsqueda:** baja por los niveles. **Inserción:** guarda el nodo anterior de cada nivel y enlaza el nuevo. **Rango:** después de buscar, avanza por el nivel 0.
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

## Comparación

`experimentos/comparacion.sql` es una primera comparación. Crea sus propios datos con semilla fija (`setseed(0.42)`): 100 000 claves distintas elegidas al azar entre 1 y 1 000 000. Con eso arma 1000 búsquedas de claves que existen (W1), 1000 de claves que no existen (W2), 10 000 inserciones (W3, 10% más) y 1000 rangos de unas 100 claves (W4). Los tres escenarios usan exactamente los mismos datos y consultas; cada uno se repite 5 veces y se muestra la mediana. El detalle queda en `experimentos/resultados.csv`.

Los datasets y cargas completos de las pautas (D1–D3 con 3 tamaños) se agregan en la etapa 2, con un generador propio (actividades 6.1–6.3 del plan de trabajo).

Resultados en Docker con 100 000 claves (mediana de 5 repeticiones):

| Medida | Sin índice | B-tree | Skip List |
|---|---|---|---|
| Construcción (ms) | – | 27.5 | 370.6 |
| W1 búsqueda exitosa (ms por consulta) | 3.47 | 0.0081 | 0.0069 |
| W2 búsqueda no exitosa (ms por consulta) | 3.49 | 0.0036 | 0.0061 |
| W4 rango (ms por consulta) | 4.19 | 0.036 | 0.043 |
| W3 inserción del 10% (ms en total) | 3.9 | 17.7 | 51.3 |
| Tamaño del índice (MB) | – | 2.7 | 3.8 |

En búsquedas la Skip List queda a la par del B-tree (en esta corrida, incluso un poco más rápida en las búsquedas exitosas) y unas 500 veces más rápida que sin índice. En búsquedas no exitosas y rangos queda un poco detrás. Construir e insertar le cuesta más, porque cada nodo se inserta uno por uno y cada salto entre nodos es leer una página; además ocupa más espacio, porque cada nodo guarda sus enlaces.

## Alcance y limitaciones

- **Lenguaje:** la guía pide C para la parte que va dentro de PostgreSQL; usamos C++ con autorización de la docente. Las cabeceras de PostgreSQL se incluyen dentro de `extern "C"`.
- La clave es `INTEGER`. Se soportan `=`, `<`, `<=`, `>`, `>=` y `BETWEEN`.
- No hay WAL propio: si PostgreSQL se cae de golpe hay que hacer `REINDEX`. Un reinicio normal no tiene problema.
- Solo un `INSERT` modifica el índice a la vez. Las búsquedas siguen funcionando mientras tanto.
- No soporta tablas `UNLOGGED` ni índices de varias columnas. El borrado es lógico: el espacio no se reutiliza.

## Recursos externos y uso de IA

- W. Pugh, *Skip Lists: A Probabilistic Alternative to Balanced Trees*, Communications of the ACM 33(6), 1990.
- Documentación oficial de PostgreSQL 18: *Index Access Method Interface Definition*, *Extending SQL*.
- El módulo `contrib/bloom` de PostgreSQL se consultó como ejemplo de la estructura de un índice (no se copió código).
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
