#generar_cargas.py cargas w1 a w4 (pedro)
#python3 datos/generar_cargas.py D2 100000
#w5 no aplica, clave entera
import os
import random
import sys

dataset = sys.argv[1] if len(sys.argv) > 1 else "D2"
n = int(sys.argv[2]) if len(sys.argv) > 2 else 100000
SEMILLA = 43
ZIPF = 1.1   #sesgo de d3
random.seed(SEMILLA)

carpeta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "generados")
claves = [int(x) for x in open(os.path.join(carpeta, "claves.csv"))]
maximo = n if dataset == "D1" else 10 * n
existen = set(claves)

def nuevas(cantidad):   #claves nuevas
    lista = []
    while len(lista) < cantidad:
        c = random.randint(1, 2 * maximo)
        if c not in existen:
            existen.add(c)
            lista.append(c)
    return lista

#w1 exitosas
if dataset == "D3":
    pesos = [1 / (r ** ZIPF) for r in range(1, n + 1)]   #zipf
    w1 = random.choices(claves, weights=pesos, k=10000)
else:
    w1 = random.choices(claves, k=10000)                 #uniforme

#w3 inserciones, antes de w2
if dataset == "D1":
    w3 = list(range(n + 1, n + n // 10 + 1))
    existen.update(w3)
else:
    w3 = nuevas(n // 10)

#w2 no exitosas
w2 = nuevas(10000)

#w4 rangos de 100 claves
ancho = 100 * maximo // n
w4 = [(d, d + ancho - 1) for d in (random.randint(1, maximo - ancho) for _ in range(1000))]

#guardar csv
def guardar(nombre, filas):
    with open(os.path.join(carpeta, nombre), "w") as f:
        for fila in filas:
            f.write((",".join(map(str, fila)) if isinstance(fila, tuple) else str(fila)) + "\n")

guardar("w1.csv", w1)
guardar("w2.csv", w2)
guardar("w3.csv", w3)
guardar("w4.csv", w4)
with open(os.path.join(carpeta, "parametros.txt"), "a") as f:
    f.write(f"semilla_cargas={SEMILLA}\nzipf={ZIPF} (solo D3)\nancho_rango={ancho}\n")
print(f"Listo: cargas W1-W4 de {dataset} en datos/generados/")
