//test_skiplist.cpp pruebas de la skip list en memoria (make -C pruebas)
#include <algorithm>
#include <iomanip>
#include <random>
#include "skip_list.h"

int fallas = 0;

//imprimir resultado y ok
void verificar(string hicimos, string salio, bool ok) {
    cout << "  " << left << setw(36) << hicimos << "-> " << setw(34) << salio << (ok ? "[OK]" : "[FALLA]") << "\n";
    if (!ok) fallas++;
}

//texto existe o no
string existe(bool si) { return si ? "existe" : "no existe"; }

int main() {
    srand(10);   //semilla fija

    //prueba 1 (nayalem y camila)
    cout << "Prueba 1: ejemplo pequeno (Nayalem y Camila)\n";
    SkipList ejemplo;
    ejemplo.construir({10, 20, 30, 40, 50, 60});
    ejemplo.mostrar();
    verificar("buscar(40)", existe(ejemplo.buscar(40)), ejemplo.buscar(40));
    verificar("buscar(45)", existe(ejemplo.buscar(45)), !ejemplo.buscar(45));

    //prueba 2, solo pares
    cout << "\nPrueba 2: construir y buscar con muchas claves (Nayalem y Camila)\n";
    vector<int> pares;
    for (int i = 1; i <= 100000; i++) pares.push_back(2 * i);
    shuffle(pares.begin(), pares.end(), mt19937(42));   //desordenar
    SkipList grande;
    grande.construir(pares);
    cout << "  Construimos con los pares del 2 al 200 000, en desorden: 100 000 claves\n";
    cout << "  Ejemplo: buscar(5000) -> " << existe(grande.buscar(5000))
         << "     buscar(5001) -> " << existe(grande.buscar(5001)) << "\n";

    int encontradas = 0;
    for (int c : pares) if (grande.buscar(c)) encontradas++;
    verificar("Buscamos las 100 000 que existen", "encontradas: " + to_string(encontradas) + " de 100000", encontradas == 100000);

    encontradas = 0;
    for (int c = 1; c < 200000; c += 2) if (grande.buscar(c)) encontradas++;   //impares no existen
    verificar("Buscamos 100 000 que no existen", "encontradas: " + to_string(encontradas) + " (esperado 0)", encontradas == 0);

    //agregado semana 3
    //prueba 3 (pedro)
    cout << "\nPrueba 3: insertar (Pedro)\n";
    bool repetida = grande.insertar(5000);
    verificar("Insertar 5000 otra vez", repetida ? "la acepto (mal)" : "rechazada (ya estaba)", !repetida);

    bool antes = grande.buscar(7);
    int nuevas = 0;
    for (int c = 1; c < 20000; c += 2) if (grande.insertar(c)) nuevas++;   //impares nuevos
    cout << "  Insertamos " << nuevas << " impares nuevos (1, 3, 5 ... 19 999): ahora hay "
         << 100000 + nuevas << " claves\n";
    cout << "  Ejemplo: buscar(7) antes -> " << existe(antes) << "; despues -> " << existe(grande.buscar(7)) << "\n";

    encontradas = 0;
    for (int c = 1; c < 20000; c += 2) if (grande.buscar(c)) encontradas++;
    verificar("Buscamos las 10 000 nuevas", "encontradas: " + to_string(encontradas) + " de 10000", encontradas == 10000);

    //prueba 4 (marccelo)
    cout << "\nPrueba 4: busqueda por rango (Marccelo)\n";
    cout << "  Ejemplo: rango [100, 110] ->";
    for (int c : grande.buscarRango(100, 110)) cout << " " << c;
    cout << "\n";

    int correctos = 0, total = 0;
    for (int desde = 0; desde < 200000; desde += 997) {
        vector<int> esperado;   //armar a mano
        for (int c = desde; c <= desde + 50; c++)
            if ((c % 2 == 0 && c >= 2 && c <= 200000) || (c % 2 == 1 && c < 20000)) esperado.push_back(c);
        if (grande.buscarRango(desde, desde + 50) == esperado) correctos++;   //mismo orden
        total++;
    }
    verificar("Probamos " + to_string(total) + " rangos de 51", "correctos: " + to_string(correctos) + " de " + to_string(total), correctos == total);
    //fin semana 3

    if (fallas == 0) cout << "\nTODAS LAS PRUEBAS PASARON\n";
    else             cout << "\n" << fallas << " PRUEBA(S) FALLARON\n";
    return fallas == 0 ? 0 : 1;
}
