#red.py simula latencia entre nodos (rodrigo)
#python3 distribuido/red.py
import asyncio
import os

LATENCIA = {("A", "B"): 20, ("A", "C"): 40, ("B", "C"): 25}   #ms ida y vuelta
NODOS = {"A": (os.environ.get("HOST_A", "nodo_a"), int(os.environ.get("PORT_A", 5432))),
         "B": (os.environ.get("HOST_B", "nodo_b"), int(os.environ.get("PORT_B", 5432))),
         "C": (os.environ.get("HOST_C", "nodo_c"), int(os.environ.get("PORT_C", 5432)))}
NUMERO = {"A": 1, "B": 2, "C": 3}

#mitad por sentido
def demora(x, y):
    return LATENCIA.get((x, y), LATENCIA.get((y, x))) / 2 / 1000

#reenviar con demora
async def pasar(lector, escritor, segundos):
    cola = asyncio.Queue()

    async def recibir():
        while True:
            datos = await lector.read(65536)
            await cola.put((asyncio.get_running_loop().time() + segundos, datos))   #hora de salida
            if not datos:
                return

    async def enviar():
        while True:
            hora, datos = await cola.get()
            await asyncio.sleep(max(0, hora - asyncio.get_running_loop().time()))   #esperar
            if not datos:
                escritor.close()
                return
            escritor.write(datos)
            await escritor.drain()

    await asyncio.gather(recibir(), enviar(), return_exceptions=True)

#conexion de un nodo a otro
def ruta(origen, destino):
    async def atender(lector, escritor):
        try:
            l2, e2 = await asyncio.open_connection(*NODOS[destino])
        except OSError:   #nodo caido
            escritor.close()
            return
        s = demora(origen, destino)
        await asyncio.gather(pasar(lector, e2, s), pasar(l2, escritor, s), return_exceptions=True)
    return atender

#un puerto por par de nodos
async def main():
    for x in NODOS:
        for y in NODOS:
            if x != y:
                puerto = 5000 + 10 * NUMERO[x] + NUMERO[y]   #a-b 5012
                await asyncio.start_server(ruta(x, y), "0.0.0.0", puerto)
    print("Red lista: A-B 20 ms, A-C 40 ms, B-C 25 ms (ida y vuelta)", flush=True)
    await asyncio.Event().wait()

asyncio.run(main())
