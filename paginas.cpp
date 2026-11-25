//paginas.cpp conexion con paginas (rodrigo y nayalem)
#include "skiplist.h"

//tamano segun nivel
static Size tamanoNodo(int nivel) {
    return offsetof(Nodo, siguiente) + (nivel + 1) * sizeof(Ref);
}

//ubicar nodo en pagina abierta
Nodo* nodoEnPagina(Page pagina, Ref ref) {
    return (Nodo*) PageGetItem(pagina, PageGetItemId(pagina, ref & 0xFFFF));   //posicion
}

//leer nodo de pagina
Nodo leerNodo(Relation indice, Ref ref) {
    Nodo nodo;
    memset(&nodo, 0, sizeof(nodo));
    Buffer buf = ReadBuffer(indice, ref >> 16);   //pedir pagina
    LockBuffer(buf, BUFFER_LOCK_SHARE);           //bloquear lectura
    Nodo* enPagina = nodoEnPagina(BufferGetPage(buf), ref);
    memcpy(&nodo, enPagina, tamanoNodo(enPagina->nivel));
    UnlockReleaseBuffer(buf);   //soltar pagina
    return nodo;
}

//cambiar un enlace
void enlazar(Relation indice, Ref ref, int nivel, Ref siguiente) {
    Buffer buf = ReadBuffer(indice, ref >> 16);
    LockBuffer(buf, BUFFER_LOCK_EXCLUSIVE);       //bloquear escritura
    nodoEnPagina(BufferGetPage(buf), ref)->siguiente[nivel] = siguiente;
    MarkBufferDirty(buf);                         //marcar cambio
    UnlockReleaseBuffer(buf);
}

//guardar nodo nuevo al final
Ref crearNodo(Relation indice, Nodo* nodo) {
    Size tamano = tamanoNodo(nodo->nivel);
    BlockNumber paginas = RelationGetNumberOfBlocks(indice);
    Buffer buf = InvalidBuffer;

    if (paginas > 0) {   //probar ultima pagina
        buf = ReadBuffer(indice, paginas - 1);
        LockBuffer(buf, BUFFER_LOCK_EXCLUSIVE);
        if (PageGetFreeSpace(BufferGetPage(buf)) < MAXALIGN(tamano)) {
            UnlockReleaseBuffer(buf);
            buf = InvalidBuffer;
        }
    }
    if (buf == InvalidBuffer) {   //agregar pagina nueva
        buf = ExtendBufferedRel(BMR_REL(indice), MAIN_FORKNUM, NULL, EB_LOCK_FIRST);
        PageInit(BufferGetPage(buf), BLCKSZ, 0);
    }
    OffsetNumber posicion = PageAddItem(BufferGetPage(buf), (Item) nodo, tamano,
                                        InvalidOffsetNumber, false, false);
    Ref ref = ((Ref) BufferGetBlockNumber(buf) << 16) | posicion;   //pagina y posicion
    MarkBufferDirty(buf);
    UnlockReleaseBuffer(buf);
    return ref;
}
