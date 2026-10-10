// test_skiplist.cpp — pruebas automáticas de la Skip List en memoria
// Ejecutar:  make -C pruebas
// Prueba 1 y 2: construir (2.2 Nayalem) y buscar (2.3 Camila) · Prueba 3: inserción (2.4 Pedro) · Prueba 4: rango (2.5 Marccelo)
#include <algorithm>
#include <iomanip>
#include <random>
#include "skip_list.h"

int fallas = 0;

// Imprime una línea: qué hicimos, qué salió y si está bien
void verificar(string hicimos, string salio, bool ok) {
    cout << "  " << left << setw(36) << hicimos << "-> " << setw(34) << salio << (ok ? "[OK]" : "[FALLA]") << "\n";
    if (!ok) fallas++;
}

string existe(bool si) { return si ? "existe" : "no existe"; }

int main() {
    srand(10);

    cout << "Prueba 1: ejemplo pequeño (Nayalem y Camila)\n";
    SkipList ejemplo;
    ejemplo.construir({10, 20, 30, 40, 50, 60});
    ejemplo.mostrar();
    verificar("buscar(40)", existe(ejemplo.buscar(40)), ejemplo.buscar(40));
    verificar("buscar(45)", existe(ejemplo.buscar(45)), !ejemplo.buscar(45));

    // Usamos solo números pares (en desorden): así sabemos que los impares NO están
    cout << "\nPrueba 2: construir y buscar con muchas claves (Nayalem y Camila)\n";
    vector<int> pares;
    for (int i = 1; i <= 100000; i++) pares.push_back(2 * i);
    shuffle(pares.begin(), pares.end(), mt19937(42));   // semilla fija
    SkipList grande;
    grande.construir(pares);
    cout << "  Construimos con los pares del 2 al 200 000, en desorden: 100 000 claves\n";
    cout << "  Ejemplo: buscar(5000) -> " << existe(grande.buscar(5000))
         << "     buscar(5001) -> " << existe(grande.buscar(5001)) << "\n";

    int encontradas = 0;
    for (int c : pares) if (grande.buscar(c)) encontradas++;
    verificar("Buscamos las 100 000 que existen", "encontradas: " + to_string(encontradas) + " de 100000", encontradas == 100000);

    encontradas = 0;
    for (int c = 1; c < 200000; c += 2) if (grande.buscar(c)) encontradas++;
    verificar("Buscamos 100 000 que no existen", "encontradas: " + to_string(encontradas) + " (esperado 0)", encontradas == 0);

    // --- Agregado en la semana 3 ---
    cout << "\nPrueba 3: insertar (Pedro)\n";
    bool repetida = grande.insertar(5000);
    verificar("Insertar 5000 otra vez", repetida ? "la acepto (mal)" : "rechazada (ya estaba)", !repetida);

    bool antes = grande.buscar(7);
    int nuevas = 0;
    for (int c = 1; c < 20000; c += 2) if (grande.insertar(c)) nuevas++;   // impares nuevos
    cout << "  Insertamos " << nuevas << " impares nuevos (1, 3, 5 ... 19 999): ahora hay "
         << 100000 + nuevas << " claves\n";
    cout << "  Ejemplo: buscar(7) antes -> " << existe(antes) << "; después -> " << existe(grande.buscar(7)) << "\n";

    encontradas = 0;
    for (int c = 1; c < 20000; c += 2) if (grande.buscar(c)) encontradas++;
    verificar("Buscamos las 10 000 nuevas", "encontradas: " + to_string(encontradas) + " de 10000", encontradas == 10000);

    // Ahora están los pares hasta 200 000 y los impares hasta 19 999
    cout << "\nPrueba 4: búsqueda por rango (Marccelo)\n";
    cout << "  Ejemplo: rango [100, 110] ->";
    for (int c : grande.buscarRango(100, 110)) cout << " " << c;
    cout << "\n";

    int correctos = 0, total = 0;
    for (int desde = 0; desde < 200000; desde += 997) {
        vector<int> esperado;   // lo armamos a mano para comparar
        for (int c = desde; c <= desde + 50; c++)
            if ((c % 2 == 0 && c >= 2 && c <= 200000) || (c % 2 == 1 && c < 20000)) esperado.push_back(c);
        if (grande.buscarRango(desde, desde + 50) == esperado) correctos++;   // mismas claves y en orden
        total++;
    }
    verificar("Probamos " + to_string(total) + " rangos de 51", "correctos: " + to_string(correctos) + " de " + to_string(total), correctos == total);
    // --- Fin de lo agregado en la semana 3 ---

    if (fallas == 0) cout << "\nTODAS LAS PRUEBAS PASARON\n";
    else             cout << "\n" << fallas << " PRUEBA(S) FALLARON\n";
    return fallas == 0 ? 0 : 1;
}
