from script_creacion import BaseDatos
from app_paths import ruta_sqls


def crear_database():
    bd = BaseDatos()
    sql_dir = ruta_sqls()
    scripts = [
        sql_dir / "database.sql",
        sql_dir / "indices.sql",
        sql_dir / "vistas_reportes.sql",
        sql_dir / "triggers.sql",
    ]
    faltantes = [str(ruta) for ruta in scripts if not ruta.exists()]
    if faltantes:
        raise FileNotFoundError("No se encontraron archivos SQL:\n" + "\n".join(faltantes))

    try:
        bd.inicializar(scripts)
    finally:
        bd.cerrar()
    return "Estructura de base de datos creada o actualizada."


if __name__ == "__main__":
    print(crear_database())
