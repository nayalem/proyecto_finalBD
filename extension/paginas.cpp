// paginas.cpp — 3.1 CONEXIÓN (Rodrigo y Nayalem): la parte de Rodrigo
// Aquí guardamos los nodos en las páginas del índice y los leemos de vuelta.
// Siempre es lo mismo: pedir la página, bloquearla, leer o cambiar, soltarla.
#include "skiplist.h"

// Un nodo de nivel 2 solo guarda 3 enlaces, no los 16 (así ocupa menos)
static Size tamanoNodo(int nivel) {
    return offsetof(Nodo, siguiente) + (nivel + 1) * sizeof(Ref);
}

// Ubica el nodo dentro de una página que ya tenemos abierta
Nodo* nodoEnPagina(Page pagina, Ref ref) {
    return (Nodo*) PageGetItem(pagina, PageGetItemId(pagina, ref & 0xFFFF));   // la parte de abajo es la posición
}

// Lee un nodo de su página. Es lo que reemplaza a seguir un puntero.
Nodo leerNodo(Relation indice, Ref ref) {
    Nodo nodo;
    memset(&nodo, 0, sizeof(nodo));
    Buffer buf = ReadBuffer(indice, ref >> 16);   // la parte de arriba es la página
    LockBuffer(buf, BUFFER_LOCK_SHARE);           // solo vamos a leer
    Nodo* enPagina = nodoEnPagina(BufferGetPage(buf), ref);
    memcpy(&nodo, enPagina, tamanoNodo(enPagina->nivel));
    UnlockReleaseBuffer(buf);
    return nodo;
}

// Cambia un enlace: el nodo "ref" ahora apunta a "siguiente" en ese nivel
void enlazar(Relation indice, Ref ref, int nivel, Ref siguiente) {
    Buffer buf = ReadBuffer(indice, ref >> 16);
    LockBuffer(buf, BUFFER_LOCK_EXCLUSIVE);       // vamos a escribir
    nodoEnPagina(BufferGetPage(buf), ref)->siguiente[nivel] = siguiente;
    MarkBufferDirty(buf);                         // avisamos que la página cambió
    UnlockReleaseBuffer(buf);
}

// Guarda un nodo nuevo al final del índice (nuestro "new Nodo")
Ref crearNodo(Relation indice, Nodo* nodo) {
    Size tamano = tamanoNodo(nodo->nivel);
    BlockNumber paginas = RelationGetNumberOfBlocks(indice);
    Buffer buf = InvalidBuffer;

    if (paginas > 0) {   // primero vemos si entra en la última página
        buf = ReadBuffer(indice, paginas - 1);
        LockBuffer(buf, BUFFER_LOCK_EXCLUSIVE);
        if (PageGetFreeSpace(BufferGetPage(buf)) < MAXALIGN(tamano)) {
            UnlockReleaseBuffer(buf);
            buf = InvalidBuffer;
        }
    }
    if (buf == InvalidBuffer) {   // si no entra, agregamos una página nueva
        buf = ExtendBufferedRel(BMR_REL(indice), MAIN_FORKNUM, NULL, EB_LOCK_FIRST);
        PageInit(BufferGetPage(buf), BLCKSZ, 0);
    }
    OffsetNumber posicion = PageAddItem(BufferGetPage(buf), (Item) nodo, tamano,
                                        InvalidOffsetNumber, false, false);
    Ref ref = ((Ref) BufferGetBlockNumber(buf) << 16) | posicion;
    MarkBufferDirty(buf);
    UnlockReleaseBuffer(buf);
    return ref;
}
