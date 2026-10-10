// main.cpp — menú para probar la Skip List a mano
// Compilar y ejecutar:  make -C pruebas programa && ./pruebas/programa
// Cada opción llama a la función de su responsable: mostrar (Nayalem), buscar (Camila),
// insertar (Pedro) y rango (Marccelo)
#include "skip_list.h"

int main() {
    srand(10);
    SkipList lista;
    lista.construir({10, 20, 30, 40, 50, 60});

    int opcion, clave;
    do {
        cout << "\n menu\n";
        cout << "1. Mostrar estructura\n";
        cout << "2. Buscar clave\n";
        cout << "3. Insertar clave\n";
        cout << "4. Buscar rango\n";
        cout << "5. Salir\n";
        cout << "Opcion: ";
        if (!(cin >> opcion)) break;

        switch (opcion) {
        case 1:
            lista.mostrar();
            break;
        case 2:
            cout << "Ingrese la clave a buscar: ";
            cin >> clave;
            if (lista.buscar(clave)) cout << "La clave existe.\n";
            else                     cout << "La clave no existe.\n";
            break;
        case 3:
            cout << "Ingrese la clave a insertar: ";
            cin >> clave;
            if (lista.insertar(clave)) cout << "Clave insertada correctamente.\n";
            else                       cout << "La clave ya existe.\n";
            break;
        case 4: {
            int desde, hasta;
            cout << "Desde: ";
            cin >> desde;
            cout << "Hasta: ";
            cin >> hasta;
            vector<int> r = lista.buscarRango(desde, hasta);
            cout << "Encontradas " << r.size() << " claves: ";
            for (int c : r) cout << c << " ";
            cout << "\n";
            break;
        }
        case 5:
            cout << "Fin del programa.\n";
            break;
        default:
            cout << "Opcion no valida.\n";
        }
    } while (opcion != 5);

    return 0;
}
