#generar_datos.py datos del esquema de bd1
#python3 distribuido/generar_datos.py
#zonas: 1 norte, 2 centro, 3 sur
import datetime
import os
import random

random.seed(42)   #semilla fija
N_ORG, N_ACT, N_VOL, N_PART = 30, 3000, 99999, 1000000

carpeta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "datos")
os.makedirs(carpeta, exist_ok=True)

#guardar csv
def guardar(nombre, filas):
    with open(os.path.join(carpeta, nombre), "w") as f:
        for fila in filas:
            f.write(",".join(map(str, fila)) + "\n")

def zona_de(id):   #zona por turno
    return (id - 1) % 3 + 1

#organizacion
tipos = ["ONG", "Parroquia", "Municipalidad", "Universidad"]
guardar("organizacion.csv", [(i, f"Organizacion {i}", random.choice(tipos), zona_de(i)) for i in range(1, N_ORG + 1)])

#actividad, zona de su organizacion
inicio = datetime.date(2024, 1, 1)
actividades = []
for i in range(1, N_ACT + 1):
    org = random.randint(1, N_ORG)
    actividades.append((i, f"Actividad {i}", inicio + datetime.timedelta(days=random.randint(0, 900)),
                        random.randint(10, 500), org, zona_de(org)))
guardar("actividad.csv", actividades)
por_zona = {z: [a[0] for a in actividades if a[5] == z] for z in (1, 2, 3)}

#voluntario
guardar("voluntario.csv", [(i, f"Nombre{i}", f"Apellido{i}", 40000000 + i, zona_de(i),
                            inicio + datetime.timedelta(days=random.randint(0, 900))) for i in range(1, N_VOL + 1)])

#participacion, 80% en su zona
estados = ["Asistio", "Ausente", "Pendiente"]
filas = []
for i in range(1, N_PART + 1):
    v = random.randint(1, N_VOL)
    z = zona_de(v)
    otra = z if random.random() < 0.8 else random.choice([x for x in (1, 2, 3) if x != z])
    filas.append((i, v, z, random.choice(por_zona[otra]),
                  inicio + datetime.timedelta(days=random.randint(0, 900)), random.choice(estados)))
guardar("participacion.csv", filas)
print("Listo: datos en distribuido/datos/ (semilla 42)")
