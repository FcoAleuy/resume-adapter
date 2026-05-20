@echo off
setlocal EnableDelayedExpansion
title Resume Adapter

cd /d "%~dp0"
cls

echo.
echo  ================================================
echo   Resume Adapter - Launcher
echo  ================================================
echo.

:: ── Verificar Python ─────────────────────────────────────────────────────────
python --version >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Python no encontrado.
    echo          Descargalo: https://python.org/downloads
    echo          Marca "Add Python to PATH" al instalar.
    goto :error
)
echo  [OK] Python encontrado

:: ── Verificar Node.js ────────────────────────────────────────────────────────
node --version >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Node.js no encontrado.
    echo          Descargalo: https://nodejs.org  (version LTS)
    goto :error
)
echo  [OK] Node.js encontrado

:: ── Configurar .env (primera vez) ───────────────────────────────────────────
if not exist ".env" (
    copy ".env.example" ".env" >nul
    echo.
    echo  [SETUP] .env creado. Agregale tu API key y vuelve a ejecutar.
    start /wait notepad ".env"
    goto :done
)
echo  [OK] .env encontrado

:: ── Frontend .env.local ──────────────────────────────────────────────────────
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
        goto :error
    )
    call venv\Scripts\activate.bat
    echo  [SETUP] Instalando dependencias del backend (1-2 min)...
    pip install -r backend\requirements.local.txt -q --disable-pip-version-check
    if errorlevel 1 (
        echo  [ERROR] Fallo pip install. Revisa tu conexion a internet.
        goto :error
    )
    echo  [OK] Dependencias backend instaladas
) else (
    call venv\Scripts\activate.bat
    echo  [OK] Entorno virtual Python listo
)

:: ── Node modules ─────────────────────────────────────────────────────────────
if not exist "frontend\node_modules\next" (
    echo.
    echo  [SETUP] Instalando dependencias del frontend (1-2 min)...
    cd frontend
    npm install --silent
    if errorlevel 1 (
        cd ..
        echo  [ERROR] Fallo npm install.
        goto :error
    )
    cd ..
    echo  [OK] Dependencias frontend instaladas
) else (
    echo  [OK] Node modules listos
)

:: ── Iniciar Backend ──────────────────────────────────────────────────────────
echo.
echo  Iniciando servidores...
echo.

start "RA-Backend" /min cmd /k "call venv\Scripts\activate.bat && uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000"
timeout /t 4 /nobreak >nul

:: ── Iniciar Frontend ─────────────────────────────────────────────────────────
start "RA-Frontend" /min cmd /k "cd frontend && npm run dev"
timeout /t 7 /nobreak >nul

:: ── Abrir navegador ──────────────────────────────────────────────────────────
start "" "http://localhost:3000"

:: ── Panel de control ─────────────────────────────────────────────────────────
cls
echo.
echo  ================================================
echo   Resume Adapter esta corriendo!
echo  ================================================
echo.
echo   App :  http://localhost:3000
echo   API :  http://localhost:8000/docs
echo.
echo   (Los logs estan en las ventanas minimizadas)
echo.
echo   Presiona cualquier tecla para DETENER todo.
echo.
pause >nul

:: ── Detener servidores ───────────────────────────────────────────────────────
echo  Deteniendo servidores...
taskkill /fi "WindowTitle eq RA-Backend" /t /f >nul 2>&1
taskkill /fi "WindowTitle eq RA-Frontend" /t /f >nul 2>&1
echo  Listo. Hasta luego!
timeout /t 2 /nobreak >nul
goto :done

:error
echo.
echo  Presiona cualquier tecla para cerrar...
pause >nul
exit /b 1

:done
exit /b 0
