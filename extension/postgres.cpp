// postgres.cpp — las funciones que llama PostgreSQL
// Cada vez que alguien hace CREATE INDEX, INSERT, SELECT o VACUUM,
// PostgreSQL llama a una de estas, y estas usan la SkipList.
#include "skiplist.h"
extern "C" { PG_MODULE_MAGIC; }   // le dice a PostgreSQL que esto es una extensión

// ---- 2.2 CONSTRUCCIÓN (Nayalem) ----

// PostgreSQL nos pasa las filas de la tabla una por una y las insertamos
static void recibirFila(Relation indice, ItemPointer fila, Datum* valores, bool* esNulo,
                        bool filaViva, void* contador) {
    if (esNulo[0]) return;   // los NULL no van al índice
    SkipList lista(indice);
    lista.insertar(DatumGetInt32(valores[0]), fila);
    (*(double*) contador)++;
}

// CREATE INDEX: creamos la cabeza y después metemos todas las filas (como construir())
static IndexBuildResult* construirIndice(Relation tabla, Relation indice, IndexInfo* info) {
    Nodo cabeza;
    memset(&cabeza, 0, sizeof(cabeza));
    cabeza.nivel = MAX_LEVEL;   // la cabeza tiene todos los niveles, apuntando a NULO
    crearNodo(indice, &cabeza); // queda en página 0, posición 1

    double indexadas = 0;
    double filas = table_index_build_scan(tabla, indice, info, true, true,
                                          recibirFila, &indexadas, NULL);
    IndexBuildResult* resultado = (IndexBuildResult*) palloc(sizeof(IndexBuildResult));
    resultado->heap_tuples = filas;
    resultado->index_tuples = indexadas;
    return resultado;
}

// ---- 2.4 INSERCIÓN (Pedro) ----

// INSERT: cada fila nueva de la tabla también entra al índice
static bool insertarFila(Relation indice, Datum* valores, bool* esNulo, ItemPointer fila,
                         Relation tabla, IndexUniqueCheck unico, bool sinCambios, IndexInfo* info) {
    if (esNulo[0]) return false;
    LockPage(indice, 0, ExclusiveLock);   // solo dejamos entrar un INSERT a la vez
    SkipList lista(indice);
    lista.insertar(DatumGetInt32(valores[0]), fila);
    UnlockPage(indice, 0, ExclusiveLock);
    return false;
}

// ---- 2.3 BÚSQUEDA (Camila) ----

// Lo que recordamos entre una fila y la siguiente mientras dura el SELECT
struct Busqueda {
    int64 desde, hasta;   // el rango que pide el WHERE
    bool  iniciada;
    Ref   actual;         // el próximo nodo que toca revisar
};

static IndexScanDesc iniciarBusqueda(Relation indice, int nclaves, int norden) {
    IndexScanDesc scan = RelationGetIndexScan(indice, nclaves, norden);
    scan->opaque = palloc0(sizeof(Busqueda));
    return scan;
}

// ---- 2.5 RANGO Y ELIMINACIÓN (Marccelo) ----

// Convertimos el WHERE (=, <, <=, >, >=, BETWEEN) en un rango [desde, hasta]
static void prepararBusqueda(IndexScanDesc scan, ScanKey claves, int nclaves,
                             ScanKey orden, int norden) {
    Busqueda* b = (Busqueda*) scan->opaque;
    b->desde = PG_INT32_MIN;   // sin condiciones, el rango es "todo"
    b->hasta = PG_INT32_MAX;
    b->iniciada = false;
    for (int i = 0; i < nclaves; i++) {
        if (claves[i].sk_flags & SK_ISNULL) { b->desde = 1; b->hasta = 0; continue; }   // = NULL no encuentra nada
        int64 v = DatumGetInt32(claves[i].sk_argument);
        switch (claves[i].sk_strategy) {
            case BTLessStrategyNumber:         b->hasta = Min(b->hasta, v - 1); break;   // <
            case BTLessEqualStrategyNumber:    b->hasta = Min(b->hasta, v);     break;   // <=
            case BTEqualStrategyNumber:        b->desde = Max(b->desde, v);              // =
                                               b->hasta = Min(b->hasta, v);     break;
            case BTGreaterEqualStrategyNumber: b->desde = Max(b->desde, v);     break;   // >=
            case BTGreaterStrategyNumber:      b->desde = Max(b->desde, v + 1); break;   // >
        }
    }
}

// ---- 2.3 BÚSQUEDA (Camila) ----

// PostgreSQL la llama una y otra vez: cada llamada devuelve una fila (false = ya no hay más)
static bool siguienteFila(IndexScanDesc scan, ScanDirection direccion) {
    Busqueda* b = (Busqueda*) scan->opaque;
    if (b->desde > b->hasta) return false;   // rango vacío
    if (!b->iniciada) {                      // la primera vez bajamos por los niveles
        SkipList lista(scan->indexRelation);
        b->actual = lista.buscar((int32) b->desde);
        b->iniciada = true;
        if (scan->instrument) scan->instrument->nsearches++;   // para que EXPLAIN lo cuente
    }
    while (b->actual != NULO) {              // después solo avanzamos por el nivel 0
        Nodo nodo = leerNodo(scan->indexRelation, b->actual);
        b->actual = nodo.siguiente[0];
        if (nodo.clave > b->hasta) break;    // ya nos pasamos del rango
        if (!nodo.borrado) {
            scan->xs_heaptid = nodo.fila;    // le decimos a PostgreSQL qué fila es
            scan->xs_recheck = false;
            return true;
        }
    }
    b->actual = NULO;
    return false;
}

static void terminarBusqueda(IndexScanDesc scan) { pfree(scan->opaque); }

// ---- 2.5 RANGO Y ELIMINACIÓN (Marccelo) ----

// VACUUM: recorremos todas las páginas y marcamos los nodos de filas eliminadas
static IndexBulkDeleteResult* limpiar(IndexVacuumInfo* info, IndexBulkDeleteResult* stats,
                                      IndexBulkDeleteCallback filaEliminada, void* estado) {
    if (stats == NULL) stats = (IndexBulkDeleteResult*) palloc0(sizeof(IndexBulkDeleteResult));
    BlockNumber paginas = RelationGetNumberOfBlocks(info->index);
    for (BlockNumber p = 0; p < paginas; p++) {
        Buffer buf = ReadBuffer(info->index, p);
        LockBuffer(buf, BUFFER_LOCK_EXCLUSIVE);
        Page pagina = BufferGetPage(buf);
        for (OffsetNumber pos = 1; pos <= PageGetMaxOffsetNumber(pagina); pos++) {
            Ref ref = ((Ref) p << 16) | pos;
            Nodo* nodo = nodoEnPagina(pagina, ref);
            if (ref != CABEZA && !nodo->borrado && filaEliminada(&nodo->fila, estado)) {
                nodo->borrado = 1;   // no lo sacamos, solo lo marcamos como borrado
                stats->tuples_removed++;
            }
        }
        MarkBufferDirty(buf);
        UnlockReleaseBuffer(buf);
    }
    return stats;
}

// ---- 3.1 CONEXIÓN (Rodrigo y Nayalem) ----

// El planificador pregunta cuánto cuesta usar el índice; usamos el cálculo genérico de PostgreSQL
static void costo(PlannerInfo* root, IndexPath* path, double loopCount, Cost* inicial,
                  Cost* total, Selectivity* selectividad, double* correlacion, double* paginas) {
    GenericCosts c;
    memset(&c, 0, sizeof(c));
    genericcostestimate(root, path, loopCount, &c);
    *inicial = c.indexStartupCost;
    *total = c.indexTotalCost;
    *selectividad = c.indexSelectivity;
    *correlacion = c.indexCorrelation;
    *paginas = c.numIndexPages;
}

// PostgreSQL exige que existan, pero no necesitamos que hagan nada
static IndexBulkDeleteResult* limpiarFinal(IndexVacuumInfo* info, IndexBulkDeleteResult* s) { return s; }
static void construirVacio(Relation indice) { elog(ERROR, "skiplist no soporta tablas UNLOGGED"); }
static bytea* opciones(Datum reloptions, bool validar) { return NULL; }
static bool validar(Oid opclass) { return true; }

extern "C" {
// La "ficha" del índice: le dice a PostgreSQL qué función llamar en cada caso
PG_FUNCTION_INFO_V1(skiplist_handler);
Datum skiplist_handler(PG_FUNCTION_ARGS) {
    IndexAmRoutine* am = makeNode(IndexAmRoutine);   // empieza todo en 0 / NULL
    am->amstrategies = 5;              // <, <=, =, >=, >
    am->amsupport = 1;
    am->ambuild = construirIndice;     // CREATE INDEX
    am->aminsert = insertarFila;       // INSERT
    am->ambeginscan = iniciarBusqueda; // SELECT
    am->amrescan = prepararBusqueda;
    am->amgettuple = siguienteFila;
    am->amendscan = terminarBusqueda;
    am->ambulkdelete = limpiar;        // VACUUM
    am->amvacuumcleanup = limpiarFinal;
    am->amcostestimate = costo;        // planificador
    am->ambuildempty = construirVacio;
    am->amoptions = opciones;
    am->amvalidate = validar;
    PG_RETURN_POINTER(am);
}
}
