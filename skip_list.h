//skip_list.h skip list en memoria, primera version
#ifndef SKIP_LIST_H
#define SKIP_LIST_H

#include <iostream>
#include <vector>
#include <cstdlib>
using namespace std;

const int MAX_LEVEL = 15;   //niveles 0 a 15

//nodo con un siguiente por nivel (rodrigo)
struct Nodo {
    int clave;
    vector<Nodo*> siguiente;

    Nodo(int valor, int nivel) {
        clave = valor;
        siguiente.resize(nivel + 1, nullptr);
    }
};

class SkipList {
private:
    Nodo* cabeza;
    int nivelActual;   //nivel mas alto usado

    //nivel al azar con moneda (rodrigo)
    int generarNivel() {
        int nivel = 0;
        while (nivel < MAX_LEVEL && rand() % 2 == 0) {
            nivel++;
        }
        return nivel;
    }

public:
    SkipList() {
        cabeza = new Nodo(-1, MAX_LEVEL);   //cabeza con todos los niveles
        nivelActual = 0;
    }

    //liberar nodos
    ~SkipList() {
        Nodo* actual = cabeza;
        while (actual != nullptr) {
            Nodo* borrar = actual;
            actual = actual->siguiente[0];
            delete borrar;
        }
    }

    //busqueda (camila)
    bool buscar(int clave) {
        Nodo* actual = cabeza;
        for (int i = nivelActual; i >= 0; i--) {
            while (actual->siguiente[i] != nullptr && actual->siguiente[i]->clave < clave) {
                actual = actual->siguiente[i];   //avanzar
            }
        }
        actual = actual->siguiente[0];   //candidato
        return actual != nullptr && actual->clave == clave;
    }

    //insercion (pedro)
    //buscar anotando anteriores
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
            return false;   //ya existe
        }

        int nuevoNivel = generarNivel();
        if (nuevoNivel > nivelActual) {   //niveles nuevos desde cabeza
            for (int i = nivelActual + 1; i <= nuevoNivel; i++) {
                anterior[i] = cabeza;
            }
            nivelActual = nuevoNivel;
        }

        Nodo* nuevo = new Nodo(clave, nuevoNivel);
        for (int i = 0; i <= nuevoNivel; i++) {
            nuevo->siguiente[i] = anterior[i]->siguiente[i];   //nuevo al siguiente
            anterior[i]->siguiente[i] = nuevo;                 //anterior al nuevo
        }
        return true;
    }

    //construccion (nayalem)
    //insertar todas las claves
    void construir(const vector<int>& datos) {
        for (int clave : datos) {
            insertar(clave);
        }
    }

    //agregado semana 3
    //rango (marccelo)
    vector<int> buscarRango(int desde, int hasta) {
        vector<int> resultado;
        Nodo* actual = cabeza;
        for (int i = nivelActual; i >= 0; i--) {   //bajar hasta desde
            while (actual->siguiente[i] != nullptr && actual->siguiente[i]->clave < desde) {
                actual = actual->siguiente[i];
            }
        }
        actual = actual->siguiente[0];
        while (actual != nullptr && actual->clave <= hasta) {   //recorrer nivel 0
            resultado.push_back(actual->clave);
            actual = actual->siguiente[0];
        }
        return resultado;
    }
    //fin semana 3

    //mostrar niveles (nayalem)
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
