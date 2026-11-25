#generar_datos.py claves de un dataset (camila)
#python3 datos/generar_datos.py D2 100000
#d1 en orden, d2 aleatorias, d3 igual a d2
import os
import random
import sys

dataset = sys.argv[1] if len(sys.argv) > 1 else "D2"
n = int(sys.argv[2]) if len(sys.argv) > 2 else 100000
SEMILLA = 42
random.seed(SEMILLA)   #semilla fija

if dataset == "D1":
    claves = list(range(1, n + 1))   #d1 en orden
else:
    claves = random.sample(range(1, 10 * n + 1), n)   #d2 y d3

carpeta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "generados")
os.makedirs(carpeta, exist_ok=True)
with open(os.path.join(carpeta, "claves.csv"), "w") as f:   #guardar claves
    f.write("\n".join(map(str, claves)) + "\n")
with open(os.path.join(carpeta, "parametros.txt"), "w") as f:
    f.write(f"dataset={dataset}\nn={n}\nsemilla={SEMILLA}\n")
print(f"Listo: {dataset} con {n} claves en datos/generados/claves.csv")
