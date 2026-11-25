//operaciones.cpp skip list en postgresql (camila busqueda, pedro insercion)
#include "skiplist.h"

//nivel al azar con moneda (rodrigo)
int SkipList::generarNivel() {
    int nivel = 0;
    while (nivel < MAX_LEVEL && rand() % 2 == 0) {
        nivel++;
    }
    return nivel;
}

//busqueda (camila)
//bajar niveles hasta la clave
Ref SkipList::buscar(int32 clave) {
    Nodo actual = leerNodo(indice, CABEZA);
    for (int i = MAX_LEVEL; i >= 0; i--) {
        while (actual.siguiente[i] != NULO) {
            Nodo siguiente = leerNodo(indice, actual.siguiente[i]);   //leer en vez de puntero
            if (siguiente.clave >= clave) break;                      //bajar nivel
            actual = siguiente;
        }
    }
    return actual.siguiente[0];   //primera clave mayor o igual
}

//insercion (pedro)
//insertar con repetidas
void SkipList::insertar(int32 clave, ItemPointer fila) {
    Ref anterior[MAX_LEVEL + 1];   //ultimo nodo por nivel
    Ref refActual = CABEZA;
    Nodo actual = leerNodo(indice, CABEZA);

    for (int i = MAX_LEVEL; i >= 0; i--) {   //buscar lugar
        while (actual.siguiente[i] != NULO) {
            Nodo siguiente = leerNodo(indice, actual.siguiente[i]);
            if (siguiente.clave >= clave) break;
            refActual = actual.siguiente[i];
            actual = siguiente;
        }
        anterior[i] = refActual;
    }

    Nodo nuevo;   //armar nodo
    memset(&nuevo, 0, sizeof(nuevo));
    nuevo.clave = clave;
    nuevo.nivel = generarNivel();
    nuevo.fila = *fila;
    for (int i = 0; i <= nuevo.nivel; i++) {
        nuevo.siguiente[i] = leerNodo(indice, anterior[i]).siguiente[i];   //nuevo al siguiente
    }

    Ref refNuevo = crearNodo(indice, &nuevo);
    for (int i = 0; i <= nuevo.nivel; i++) {
        enlazar(indice, anterior[i], i, refNuevo);   //anterior al nuevo
    }
}

//construccion ordenada
//enganchar al final de cada nivel
void SkipList::construirOrdenado(Par* pares, int64 n) {
    Ref ultimo[MAX_LEVEL + 1];
    for (int i = 0; i <= MAX_LEVEL; i++) {
        ultimo[i] = CABEZA;   //empezar en cabeza
    }
    for (int64 k = 0; k < n; k++) {
        Nodo nuevo;
        memset(&nuevo, 0, sizeof(nuevo));
        nuevo.clave = pares[k].clave;
        nuevo.nivel = generarNivel();
        nuevo.fila = pares[k].fila;
        Ref refNuevo = crearNodo(indice, &nuevo);
        for (int i = 0; i <= nuevo.nivel; i++) {
            enlazar(indice, ultimo[i], i, refNuevo);   //ultimo al nuevo
            ultimo[i] = refNuevo;
        }
    }
}
