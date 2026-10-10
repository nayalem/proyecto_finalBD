// operaciones.cpp — la Skip List dentro de PostgreSQL (2.3 Camila y 2.4 Pedro)
// Es la misma lógica que src/skip_list.h. La única diferencia es que en vez
// de seguir punteros, leemos el siguiente nodo de su página con leerNodo().
#include "skiplist.h"

// 2.1 (Rodrigo): tiramos una moneda; mientras salga "cara" subimos un nivel
int SkipList::generarNivel() {
    int nivel = 0;
    while (nivel < MAX_LEVEL && rand() % 2 == 0) {
        nivel++;
    }
    return nivel;
}

// ---- 2.3 BÚSQUEDA (Camila) ----

// Bajamos nivel por nivel hasta llegar a la clave (o a la que le sigue).
// No guardamos nivelActual: empezamos arriba y los niveles vacíos se saltan solos.
Ref SkipList::buscar(int32 clave) {
    Nodo actual = leerNodo(indice, CABEZA);
    for (int i = MAX_LEVEL; i >= 0; i--) {
        while (actual.siguiente[i] != NULO) {
            Nodo siguiente = leerNodo(indice, actual.siguiente[i]);   // antes era actual->siguiente[i]
            if (siguiente.clave >= clave) break;                      // nos pasaríamos: bajamos
            actual = siguiente;
        }
    }
    return actual.siguiente[0];   // desde aquí PostgreSQL sigue con las repetidas o el rango
}

// ---- 2.4 INSERCIÓN (Pedro) ----

// Igual que en memoria, pero aquí sí dejamos claves repetidas
// (varias filas de la tabla pueden tener el mismo valor).
void SkipList::insertar(int32 clave, ItemPointer fila) {
    Ref anterior[MAX_LEVEL + 1];   // el último nodo por el que pasamos en cada nivel
    Ref refActual = CABEZA;
    Nodo actual = leerNodo(indice, CABEZA);

    // Primero buscamos dónde va, anotando anterior[i] en cada nivel
    for (int i = MAX_LEVEL; i >= 0; i--) {
        while (actual.siguiente[i] != NULO) {
            Nodo siguiente = leerNodo(indice, actual.siguiente[i]);
            if (siguiente.clave >= clave) break;
            refActual = actual.siguiente[i];
            actual = siguiente;
        }
        anterior[i] = refActual;
    }

    // Armamos el nodo nuevo
    Nodo nuevo;
    memset(&nuevo, 0, sizeof(nuevo));
    nuevo.clave = clave;
    nuevo.nivel = generarNivel();
    nuevo.fila = *fila;
    for (int i = 0; i <= nuevo.nivel; i++) {
        nuevo.siguiente[i] = leerNodo(indice, anterior[i]).siguiente[i];   // nuevo -> el que seguía
    }

    // Lo guardamos y hacemos que los anteriores apunten a él
    Ref refNuevo = crearNodo(indice, &nuevo);
    for (int i = 0; i <= nuevo.nivel; i++) {
        enlazar(indice, anterior[i], i, refNuevo);   // anterior -> nuevo
    }
}
