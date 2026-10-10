// skiplist.h — 2.1 (Rodrigo)
// El nodo, cómo se ve en disco y la lista de funciones que comparten los .cpp.
#ifndef SKIPLIST_H
#define SKIPLIST_H

extern "C" {   // PostgreSQL está escrito en C, por eso va dentro de extern "C"
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

const int MAX_LEVEL = 15;   // igual que en memoria

// En disco no hay punteros, así que a cada nodo lo ubicamos con un número:
// (página << 16) | posición dentro de la página
typedef uint64 Ref;
const Ref NULO = 0;     // nuestro nullptr
const Ref CABEZA = 1;   // la cabeza siempre es el primer nodo (página 0, posición 1)

struct Nodo {
    int32           clave;     // el valor de la columna (ej. recurso_id)
    uint16          nivel;     // hasta qué nivel llega este nodo
    uint16          borrado;   // 1 si la fila ya se eliminó (lo marca VACUUM)
    ItemPointerData fila;      // dónde está la fila en la tabla
    Ref             siguiente[MAX_LEVEL + 1];
};

// paginas.cpp — guardar y leer nodos
Nodo  leerNodo(Relation indice, Ref ref);
Ref   crearNodo(Relation indice, Nodo* nodo);
void  enlazar(Relation indice, Ref ref, int nivel, Ref siguiente);
Nodo* nodoEnPagina(Page pagina, Ref ref);

// operaciones.cpp — la Skip List
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
