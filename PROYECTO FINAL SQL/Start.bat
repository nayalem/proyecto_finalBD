@echo off

rem Establecer el directorio del entorno virtual
set VIRTUAL_ENV="venv"

rem Verificar si el directorio venv existe
if not exist %VIRTUAL_ENV% (
    rem Crear el entorno virtual    
    python -m venv %VIRTUAL_ENV%
    if errorlevel 1 (
        echo Error: No se pudo crear el entorno virtual.
        pause
        exit /b 1
    )
)

rem Activar el entorno virtual
call %VIRTUAL_ENV%\Scripts\activate

rem Instalar las dependencias   
python -m pip install --upgrade pip
python -m pip install pipwin 

python -m pip install pyinstaller

python -m pip install -r "%~dp0requirements.txt"

python "%~dp0menu_inicio.py"

pause
