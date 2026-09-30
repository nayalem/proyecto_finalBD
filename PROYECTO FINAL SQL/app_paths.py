import sys
from pathlib import Path


def carpeta_aplicacion():
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


def carpeta_recursos():
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        return Path(sys._MEIPASS)
    return Path(__file__).resolve().parent


APP_DIR = carpeta_aplicacion()
RESOURCE_DIR = carpeta_recursos()
DB_PATH = APP_DIR / "voluntariado.db"
TXT_SEED_PATH = APP_DIR / "datos_voluntariado_seed.txt"


def ruta_sqls():
    sqls_externo = APP_DIR / "sqls"
    if sqls_externo.exists():
        return sqls_externo
    return RESOURCE_DIR / "sqls"
