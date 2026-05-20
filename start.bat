@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1
title Resume Adapter

:: Siempre trabajar desde la carpeta del .bat
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
    echo          Marca "Add Python to PATH" al instalar.
    echo.
    goto :error
)
for /f "tokens=*" %%v in ('python --version 2^>^&1') do set PY_VER=%%v
echo  [OK] !PY_VER!

:: ── Verificar Node.js ─────────────────────────────────────────────────────────
node --version >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Node.js no encontrado.
    echo          Descargalo desde: https://nodejs.org (version LTS^)
    echo.
    goto :error
)
for /f "tokens=*" %%v in ('node --version 2^>^&1') do set NODE_VER=%%v
echo  [OK] Node.js !NODE_VER!

:: ── Configurar .env (primera vez) ────────────────────────────────────────────
if not exist ".env" (
    copy ".env.example" ".env" >nul
    echo.
    echo  [SETUP] .env creado. Completalo con tu API key y vuelve a ejecutar.
    echo  Abriendo .env en el Bloc de Notas...
    echo.
    start /wait notepad ".env"
    goto :done
)
echo  [OK] .env encontrado

:: ── Frontend .env.local ───────────────────────────────────────────────────────
if not exist "frontend\.env.local" (
    echo NEXT_PUBLIC_API_URL=http://localhost:8000> "frontend\.env.local"
    echo  [OK] frontend\.env.local creado
)

:: ── Entorno virtual Python ────────────────────────────────────────────────────
echo.
if not exist "venv\Scripts\python.exe" (
    echo  [SETUP] Creando entorno virtual Python...
    python -m venv venv
    if errorlevel 1 ( echo  [ERROR] No se pudo crear el venv. & goto :error )

    echo  [SETUP] Instalando dependencias del backend...
    echo          (solo ocurre la primera vez, unos minutos^)
    call venv\Scripts\activate.bat
    pip install -r backend\requirements.local.txt -q --disable-pip-version-check
    if errorlevel 1 ( echo  [ERROR] Fallo pip install. Revisa tu conexion. & goto :error )
    echo  [OK] Dependencias backend instaladas
) else (
    call venv\Scripts\activate.bat
    echo  [OK] Entorno virtual Python listo
)

:: ── Node modules ──────────────────────────────────────────────────────────────
if not exist "frontend\node_modules\next" (
    echo.
    echo  [SETUP] Instalando dependencias del frontend...
    echo          (solo ocurre la primera vez, unos minutos^)
    cd frontend
    npm install --silent
    if errorlevel 1 ( cd .. & echo  [ERROR] Fallo npm install. & goto :error )
    cd ..
    echo  [OK] Dependencias frontend instaladas
) else (
    echo  [OK] Node modules listos
)

:: ── Iniciar servidores ────────────────────────────────────────────────────────
echo.
echo  Iniciando servidores...
echo.

:: Backend — hereda el directorio actual (D:\resume-adapter\)
start "RA-Backend" /min cmd /k "call venv\Scripts\activate.bat && uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000"

timeout /t 4 /nobreak >nul

:: Frontend — entra a la subcarpeta frontend
start "RA-Frontend" /min cmd /k "cd frontend && npm run dev"

timeout /t 7 /nobreak >nul

:: ── Abrir navegador ───────────────────────────────────────────────────────────
start "" "http://localhost:3000"

:: ── Panel de control ─────────────────────────────────────────────────────────
cls
echo.
echo  ==================================================
echo   Resume Adapter esta corriendo
echo  ==================================================
echo.
echo   Aplicacion :  http://localhost:3000
echo   API / Docs :  http://localhost:8000/docs
echo.
echo   Logs: mira las 2 ventanas minimizadas en la barra.
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
echo  Servidores detenidos. Hasta luego!
goto :done

:error
echo.
echo  Presiona cualquier tecla para cerrar...
pause >nul
exit /b 1

:done
exit /b 0
