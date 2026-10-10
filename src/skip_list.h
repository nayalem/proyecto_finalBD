// skip_list.h — la Skip List en memoria (nuestra primera versión)
// Cada nodo tiene una clave y un "siguiente" por cada nivel.
// La versión de PostgreSQL (extension/operaciones.cpp) hace lo mismo, pero con los nodos en disco.
#ifndef SKIP_LIST_H
#define SKIP_LIST_H

#include <iostream>
#include <vector>
#include <cstdlib>
using namespace std;

const int MAX_LEVEL = 15;   // niveles del 0 al 15

// 2.1 (Rodrigo): el nodo y la cabeza
struct Nodo {
    int clave;
    vector<Nodo*> siguiente;   // siguiente[i] = el que sigue en el nivel i

    Nodo(int valor, int nivel) {
        clave = valor;
        siguiente.resize(nivel + 1, nullptr);
    }
};

class SkipList {
private:
    Nodo* cabeza;
    int nivelActual;   // el nivel más alto que se está usando

    // 2.1 (Rodrigo): tiramos una moneda; mientras salga "cara" subimos un nivel
    int generarNivel() {
        int nivel = 0;
        while (nivel < MAX_LEVEL && rand() % 2 == 0) {
            nivel++;
        }
        return nivel;
    }

public:
    SkipList() {
        cabeza = new Nodo(-1, MAX_LEVEL);   // la cabeza tiene todos los niveles
        nivelActual = 0;
    }

    // Al terminar liberamos todos los nodos
    ~SkipList() {
        Nodo* actual = cabeza;
        while (actual != nullptr) {
            Nodo* borrar = actual;
            actual = actual->siguiente[0];
            delete borrar;
        }
    }

    // 2.3 BÚSQUEDA (Camila)
    // Bajamos desde el nivel más alto, avanzando mientras el siguiente sea menor
    bool buscar(int clave) {
        Nodo* actual = cabeza;
        for (int i = nivelActual; i >= 0; i--) {
            while (actual->siguiente[i] != nullptr && actual->siguiente[i]->clave < clave) {
                actual = actual->siguiente[i];
            }
        }
        actual = actual->siguiente[0];   // aquí debería estar la clave
        return actual != nullptr && actual->clave == clave;
    }

    // 2.4 INSERCIÓN (Pedro)
    // Igual que buscar, pero anotando en anterior[i] dónde nos quedamos en cada nivel.
    // Devuelve false si la clave ya estaba.
    bool insertar(int clave) {
        Nodo* actual = cabeza;
        vector<Nodo*> anterior(MAX_LEVEL + 1);

        for (int i = nivelActual; i >= 0; i--) {
            while (actual->siguiente[i] != nullptr && actual->siguiente[i]->clave < clave) {
                actual = actual->siguiente[i];
            }
            anterior[i] = actual;
        }

        actual = actual->siguiente[0];
        if (actual != nullptr && actual->clave == clave) {
            return false;   // ya existe
        }

        int nuevoNivel = generarNivel();
        if (nuevoNivel > nivelActual) {   // si el nodo es más alto, en esos niveles el anterior es la cabeza
            for (int i = nivelActual + 1; i <= nuevoNivel; i++) {
                anterior[i] = cabeza;
            }
            nivelActual = nuevoNivel;
        }

        Nodo* nuevo = new Nodo(clave, nuevoNivel);
        for (int i = 0; i <= nuevoNivel; i++) {
            nuevo->siguiente[i] = anterior[i]->siguiente[i];   // nuevo -> el que seguía
            anterior[i]->siguiente[i] = nuevo;                 // anterior -> nuevo
        }
        return true;
    }

    // 2.2 CONSTRUCCIÓN (Nayalem)
    // Construir es simplemente insertar todas las claves
    void construir(const vector<int>& datos) {
        for (int clave : datos) {
            insertar(clave);
        }
    }

    // --- Agregado en la semana 3 ---
    // 2.5 RANGO (Marccelo)
    // Buscamos el primer nodo >= desde y avanzamos por el nivel 0 hasta pasar "hasta"
    vector<int> buscarRango(int desde, int hasta) {
        vector<int> resultado;
        Nodo* actual = cabeza;
        for (int i = nivelActual; i >= 0; i--) {
            while (actual->siguiente[i] != nullptr && actual->siguiente[i]->clave < desde) {
                actual = actual->siguiente[i];
            }
        }
        actual = actual->siguiente[0];
        while (actual != nullptr && actual->clave <= hasta) {   // el nivel 0 tiene todas las claves en orden
            resultado.push_back(actual->clave);
            actual = actual->siguiente[0];
        }
        return resultado;
    }
    // --- Fin de lo agregado en la semana 3 ---

    // 2.2 (Nayalem): imprime cada nivel, del más alto al 0, para ver cómo quedó
    void mostrar() {
        cout << "\nSKIP LIST\n";
        for (int i = nivelActual; i >= 0; i--) {
            Nodo* actual = cabeza->siguiente[i];
            cout << "Nivel " << i << ": ";
            while (actual != nullptr) {
                cout << actual->clave << " -> ";
                actual = actual->siguiente[i];
            }
            cout << "NULL\n";
        }
    }
};

#endif
