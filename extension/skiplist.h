//skiplist.h nodo en disco y funciones compartidas (rodrigo)
#ifndef SKIPLIST_H
#define SKIPLIST_H

extern "C" {   //postgresql esta en c
#include "postgres.h"
#include "fmgr.h"
#include "access/amapi.h"
#include "access/genam.h"
#include "access/relscan.h"
#include "access/stratnum.h"
#include "access/tableam.h"
#include "nodes/pathnodes.h"
#include "storage/bufmgr.h"
#include "storage/lmgr.h"
#include "utils/rel.h"
#include "utils/selfuncs.h"
}

const int MAX_LEVEL = 15;   //16 niveles

//ref = pagina << 16 | posicion
typedef uint64 Ref;
const Ref NULO = 0;     //como nullptr
const Ref CABEZA = 1;   //pagina 0 posicion 1

//nodo guardado en disco
struct Nodo {
    int32           clave;
    uint16          nivel;
    uint16          borrado;   //marca de vacuum
    ItemPointerData fila;      //tid de la fila
    Ref             siguiente[MAX_LEVEL + 1];
};

//paginas.cpp
Nodo  leerNodo(Relation indice, Ref ref);
Ref   crearNodo(Relation indice, Nodo* nodo);
void  enlazar(Relation indice, Ref ref, int nivel, Ref siguiente);
Nodo* nodoEnPagina(Page pagina, Ref ref);

//operaciones.cpp
class SkipList {
private:
    Relation indice;
    int generarNivel();
public:
    SkipList(Relation indice) { this->indice = indice; }
    Ref  buscar(int32 clave);
    void insertar(int32 clave, ItemPointer fila);
};

#endif
