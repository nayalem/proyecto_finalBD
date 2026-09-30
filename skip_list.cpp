
#include <iostream>
#include <vector>
#include <cstdlib>
#include <ctime>
using namespace std;

const int MAX_LEVEL = 4;

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
	int nivelActual;
	
	int generarNivel() {
		int nivel = 0;
		
		while (nivel < MAX_LEVEL && rand() % 2 == 0) {
			nivel++;
		}
		
		return nivel;
	}
	
public:
		SkipList() {
			cabeza = new Nodo(-1, MAX_LEVEL);
			nivelActual = 0;
		}
		
		~SkipList() {
			Nodo* actual = cabeza->siguiente[0];
			
			while (actual != nullptr) {
				Nodo* borrar = actual;
				actual = actual->siguiente[0];
				delete borrar;
			}
			
			delete cabeza;
		}
		
		bool buscar(int clave) {
			Nodo* actual = cabeza;
			
			for (int i = nivelActual; i >= 0; i--) {
				while (actual->siguiente[i] != nullptr &&
					   actual->siguiente[i]->clave < clave) {
					actual = actual->siguiente[i];
				}
			}
			
			actual = actual->siguiente[0];
			
			return actual != nullptr && actual->clave == clave;
		}
		
		void insertar(int clave) {
			Nodo* actual = cabeza;
			vector<Nodo*> anterior(MAX_LEVEL + 1);
			
			// buscar pos
			for (int i = nivelActual; i >= 0; i--) {
				while (actual->siguiente[i] != nullptr &&
					   actual->siguiente[i]->clave < clave) {
					actual = actual->siguiente[i];
				}
				
				anterior[i] = actual;
			}
			
			actual = actual->siguiente[0];

			if (actual != nullptr && actual->clave == clave) {
				cout << "La clave ya existe.\n";
				return;
			}
			
			int nuevoNivel = generarNivel();
			
			if (nuevoNivel > nivelActual) {
				for (int i = nivelActual + 1; i <= nuevoNivel; i++) {
					anterior[i] = cabeza;
				}
				
				nivelActual = nuevoNivel;
			}
			
			Nodo* nuevo = new Nodo(clave, nuevoNivel);
			
			// actualizar los enlaces 
			for (int i = 0; i <= nuevoNivel; i++) {
				nuevo->siguiente[i] = anterior[i]->siguiente[i];
				anterior[i]->siguiente[i] = nuevo;
			}
			
			cout << "Clave insertada correctamente.\n";
		}
		
		void construir(vector<int> datos) {
			for (int clave : datos) {
				insertar(clave);
			}
		}
		
		void mostrar() {
			cout << "\nSKIP LIST \n";
			
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

int main() {
	srand(10);
	SkipList lista;
	
	vector<int> datos = {10, 20, 30, 40, 50, 60};
	lista.construir(datos);
	
	int opcion, clave;
	
	do {
		cout << "\n menu\n";
		cout << "1. Mostrar estructura\n";
		cout << "2. Buscar clave\n";
		cout << "3. Insertar clave\n";
		cout << "4. Salir\n";
		cout << "Opcion: ";
		cin >> opcion;
		
		switch (opcion) {
		case 1:
			lista.mostrar();
			break;
			
		case 2:
			cout << "Ingrese la clave a buscar: ";
			cin >> clave;
			
			if (lista.buscar(clave)) {
				cout << "La clave existe.\n";
			} else {
				cout << "La clave no existe.\n";
			}
			break;
			
		case 3:
			cout << "Ingrese la clave a insertar: ";
			cin >> clave;
			
			lista.insertar(clave);
			break;
			
		case 4:
			cout << "Fin del programa.\n";
			break;
			
		default:
			cout << "Opcion no valida.\n";
		}
		
	} while (opcion != 4);
	
	return 0;
}
