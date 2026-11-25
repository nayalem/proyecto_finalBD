//postgres.cpp funciones que llama postgresql
#include "skiplist.h"
extern "C" { PG_MODULE_MAGIC; }   //marca de extension

//construccion (nayalem)
//insertar cada fila de la tabla
static void recibirFila(Relation indice, ItemPointer fila, Datum* valores, bool* esNulo,
                        bool filaViva, void* contador) {
    if (esNulo[0]) return;   //null no entra
    SkipList lista(indice);
    lista.insertar(DatumGetInt32(valores[0]), fila);
    (*(double*) contador)++;
}

//create index: cabeza e inserciones
static IndexBuildResult* construirIndice(Relation tabla, Relation indice, IndexInfo* info) {
    Nodo cabeza;
    memset(&cabeza, 0, sizeof(cabeza));
    cabeza.nivel = MAX_LEVEL;   //cabeza con todos los niveles
    crearNodo(indice, &cabeza); //pagina 0 posicion 1

    double indexadas = 0;
    double filas = table_index_build_scan(tabla, indice, info, true, true,
                                          recibirFila, &indexadas, NULL);
    IndexBuildResult* resultado = (IndexBuildResult*) palloc(sizeof(IndexBuildResult));
    resultado->heap_tuples = filas;
    resultado->index_tuples = indexadas;
    return resultado;
}

//insercion (pedro)
//insert: fila nueva al indice
static bool insertarFila(Relation indice, Datum* valores, bool* esNulo, ItemPointer fila,
                         Relation tabla, IndexUniqueCheck unico, bool sinCambios, IndexInfo* info) {
    if (esNulo[0]) return false;
    LockPage(indice, 0, ExclusiveLock);   //un insert a la vez
    SkipList lista(indice);
    lista.insertar(DatumGetInt32(valores[0]), fila);
    UnlockPage(indice, 0, ExclusiveLock);
    return false;
}

//busqueda (camila)
//estado del select
struct Busqueda {
    int64 desde, hasta;   //rango del where
    bool  iniciada;
    Ref   actual;         //proximo nodo
};

//abrir busqueda
static IndexScanDesc iniciarBusqueda(Relation indice, int nclaves, int norden) {
    IndexScanDesc scan = RelationGetIndexScan(indice, nclaves, norden);
    scan->opaque = palloc0(sizeof(Busqueda));
    return scan;
}

//rango y eliminacion (marccelo)
//where a rango desde hasta
static void prepararBusqueda(IndexScanDesc scan, ScanKey claves, int nclaves,
                             ScanKey orden, int norden) {
    Busqueda* b = (Busqueda*) scan->opaque;
    b->desde = PG_INT32_MIN;   //sin condicion, todo
    b->hasta = PG_INT32_MAX;
    b->iniciada = false;
    for (int i = 0; i < nclaves; i++) {
        if (claves[i].sk_flags & SK_ISNULL) { b->desde = 1; b->hasta = 0; continue; }   //null, rango vacio
        int64 v = DatumGetInt32(claves[i].sk_argument);
        switch (claves[i].sk_strategy) {
            case BTLessStrategyNumber:         b->hasta = Min(b->hasta, v - 1); break;   //<
            case BTLessEqualStrategyNumber:    b->hasta = Min(b->hasta, v);     break;   //<=
            case BTEqualStrategyNumber:        b->desde = Max(b->desde, v);              //=
                                               b->hasta = Min(b->hasta, v);     break;
            case BTGreaterEqualStrategyNumber: b->desde = Max(b->desde, v);     break;   //>=
            case BTGreaterStrategyNumber:      b->desde = Max(b->desde, v + 1); break;   //>
        }
    }
}

//busqueda (camila)
//devolver una fila por llamada
static bool siguienteFila(IndexScanDesc scan, ScanDirection direccion) {
    Busqueda* b = (Busqueda*) scan->opaque;
    if (b->desde > b->hasta) return false;   //rango vacio
    if (!b->iniciada) {                      //primera vez, buscar
        SkipList lista(scan->indexRelation);
        b->actual = lista.buscar((int32) b->desde);
        b->iniciada = true;
        if (scan->instrument) scan->instrument->nsearches++;   //contar en explain
    }
    while (b->actual != NULO) {              //avanzar en nivel 0
        Nodo nodo = leerNodo(scan->indexRelation, b->actual);
        b->actual = nodo.siguiente[0];
        if (nodo.clave > b->hasta) break;    //fin del rango
        if (!nodo.borrado) {
            scan->xs_heaptid = nodo.fila;    //tid de la fila
            scan->xs_recheck = false;
            return true;
        }
    }
    b->actual = NULO;
    return false;
}

//cerrar busqueda
static void terminarBusqueda(IndexScanDesc scan) { pfree(scan->opaque); }

//rango y eliminacion (marccelo)
//vacuum: marcar filas borradas
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
                nodo->borrado = 1;   //borrado logico
                stats->tuples_removed++;
            }
        }
        MarkBufferDirty(buf);
        UnlockReleaseBuffer(buf);
    }
    return stats;
}

//conexion (rodrigo y nayalem)
//costo generico para el planificador
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

//obligatorias, sin trabajo
static IndexBulkDeleteResult* limpiarFinal(IndexVacuumInfo* info, IndexBulkDeleteResult* s) { return s; }
static void construirVacio(Relation indice) { elog(ERROR, "skiplist no soporta tablas UNLOGGED"); }
static bytea* opciones(Datum reloptions, bool validar) { return NULL; }
static bool validar(Oid opclass) { return true; }

extern "C" {
//ficha del indice
PG_FUNCTION_INFO_V1(skiplist_handler);
Datum skiplist_handler(PG_FUNCTION_ARGS) {
    IndexAmRoutine* am = makeNode(IndexAmRoutine);
    am->amstrategies = 5;              //< <= = >= >
    am->amsupport = 1;
    am->ambuild = construirIndice;     //create index
    am->aminsert = insertarFila;       //insert
    am->ambeginscan = iniciarBusqueda; //select
    am->amrescan = prepararBusqueda;
    am->amgettuple = siguienteFila;
    am->amendscan = terminarBusqueda;
    am->ambulkdelete = limpiar;        //vacuum
    am->amvacuumcleanup = limpiarFinal;
    am->amcostestimate = costo;        //planificador
    am->ambuildempty = construirVacio;
    am->amoptions = opciones;
    am->amvalidate = validar;
    PG_RETURN_POINTER(am);
}
}
