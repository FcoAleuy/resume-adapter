@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1
title Resume Adapter

cd /d "%~dp0"
cls

echo.
echo  ==================================================
echo   Resume Adapter  ^|  Launcher
echo  ==================================================
echo.

:: ── Verificar Python ──────────────────────────────────────────────────────────
python --version >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Python no encontrado.
    echo          Descargalo desde: https://python.org/downloads
    echo          Asegurate de marcar "Add Python to PATH" al instalar.
    echo.
    pause & exit /b 1
)
for /f "tokens=*" %%v in ('python --version 2^>^&1') do set PY_VER=%%v
echo  [OK] !PY_VER!

:: ── Verificar Node.js ─────────────────────────────────────────────────────────
node --version >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Node.js no encontrado.
    echo          Descargalo desde: https://nodejs.org  (version LTS)
    echo.
    pause & exit /b 1
)
for /f "tokens=*" %%v in ('node --version 2^>^&1') do set NODE_VER=%%v
echo  [OK] Node.js !NODE_VER!

:: ── Configurar .env (primera vez) ────────────────────────────────────────────
if not exist ".env" (
    echo.
    echo  [SETUP] Creando archivo de configuracion...
    copy ".env.example" ".env" >nul

    echo.
    echo  ==================================================
    echo   Se abrio el archivo .env en el Bloc de Notas.
    echo.
    echo   Necesitas completar AL MENOS UNO de estos:
    echo     OPENAI_API_KEY=sk-...   (recomendado)
    echo     GROQ_API_KEY=gsk_...    (alternativa gratuita)
    echo.
    echo   Guarda el archivo y cierra el Bloc de Notas,
    echo   luego presiona cualquier tecla para continuar.
    echo  ==================================================
    echo.
    start /wait notepad ".env"

    echo  [OK] Configuracion guardada
)

:: ── Verificar que haya al menos una API key ───────────────────────────────────
set HAS_KEY=0
for /f "tokens=1,* delims==" %%a in ('findstr /i "OPENAI_API_KEY\|GROQ_API_KEY" ".env" 2^>nul') do (
    set VAL=%%b
    set VAL=!VAL: =!
    if not "!VAL!"=="" if not "!VAL!"=="sk-..." if not "!VAL!"=="gsk_..." (
        set HAS_KEY=1
    )
)
if "!HAS_KEY!"=="0" (
    echo.
    echo  [AVISO] No se encontro una API key valida en .env
    echo          Abre .env y agrega tu OPENAI_API_KEY o GROQ_API_KEY
    echo.
    echo  Abriendo .env...
    start /wait notepad ".env"
)

:: ── Frontend .env.local ───────────────────────────────────────────────────────
if not exist "frontend\.env.local" (
    echo NEXT_PUBLIC_API_URL=http://localhost:8000> "frontend\.env.local"
    echo  [OK] frontend\.env.local creado
)

:: ── Entorno virtual Python ───────────────────────────────────────────────────
echo.
if not exist "venv\Scripts\python.exe" (
    echo  [SETUP] Creando entorno virtual Python...
    python -m venv venv
    if errorlevel 1 (
        echo  [ERROR] No se pudo crear el entorno virtual.
        pause & exit /b 1
    )
    call venv\Scripts\activate.bat
    echo  [SETUP] Instalando dependencias del backend...
    echo          (esto solo ocurre la primera vez, ~1-2 minutos)
    pip install -r backend\requirements.local.txt -q --disable-pip-version-check
    if errorlevel 1 (
        echo  [ERROR] Fallo la instalacion de dependencias Python.
        echo          Revisa tu conexion a internet e intenta de nuevo.
        pause & exit /b 1
    )
    echo  [OK] Dependencias del backend instaladas
) else (
    call venv\Scripts\activate.bat
    echo  [OK] Entorno virtual Python listo
)

:: ── Node modules ─────────────────────────────────────────────────────────────
if not exist "frontend\node_modules\next" (
    echo.
    echo  [SETUP] Instalando dependencias del frontend...
    echo          (esto solo ocurre la primera vez, ~1-2 minutos)
    pushd frontend
    npm install --silent
    if errorlevel 1 (
        echo  [ERROR] Fallo la instalacion de Node modules.
        popd & pause & exit /b 1
    )
    popd
    echo  [OK] Dependencias del frontend instaladas
) else (
    echo  [OK] Node modules listos
)

:: ── Iniciar Backend ───────────────────────────────────────────────────────────
echo.
echo  Iniciando servidores...
echo.

start "RA-Backend" /min cmd /k "title RA-Backend && cd /d "%~dp0" && call venv\Scripts\activate.bat && uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000"

:: Esperar que el backend levante
timeout /t 4 /nobreak >nul

:: ── Iniciar Frontend ──────────────────────────────────────────────────────────
start "RA-Frontend" /min cmd /k "title RA-Frontend && cd /d "%~dp0frontend" && npm run dev"

:: Esperar que Next.js compile
timeout /t 6 /nobreak >nul

:: ── Abrir navegador ───────────────────────────────────────────────────────────
start "" "http://localhost:3000"

:: ── Panel de control ─────────────────────────────────────────────────────────
cls
echo.
echo  ==================================================
echo   Resume Adapter esta corriendo
echo  ==================================================
echo.
echo   Aplicacion:  http://localhost:3000
echo   API / Docs:  http://localhost:8000/docs
echo.
echo   Los logs del backend y frontend estan en las
echo   dos ventanas minimizadas en la barra de tareas.
echo.
echo  --------------------------------------------------
echo   Presiona cualquier tecla para DETENER todo
echo  --------------------------------------------------
echo.
pause >nul

:: ── Detener servidores ────────────────────────────────────────────────────────
echo.
echo  Deteniendo servidores...
taskkill /fi "WindowTitle eq RA-Backend" /t /f >nul 2>&1
taskkill /fi "WindowTitle eq RA-Frontend" /t /f >nul 2>&1
taskkill /fi "WindowTitle eq RA-Backend - uvicorn" /t /f >nul 2>&1
echo  Servidores detenidos. Hasta luego!
timeout /t 2 /nobreak >nul
