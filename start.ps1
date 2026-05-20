$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host "   Resume Adapter - Launcher" -ForegroundColor Cyan
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host ""

# ── Verificar Python ──────────────────────────────────────────────────────────
Write-Host "  Verificando Python..." -NoNewline
try {
    $pyVer = python --version 2>&1
    Write-Host " OK ($pyVer)" -ForegroundColor Green
} catch {
    Write-Host " NO ENCONTRADO" -ForegroundColor Red
    Write-Host "  Instala Python 3.11+ desde: https://python.org/downloads" -ForegroundColor Yellow
    Read-Host "`n  Presiona Enter para cerrar"
    exit 1
}

# ── Configurar .env ───────────────────────────────────────────────────────────
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "  [SETUP] .env creado - agrega tu API key y vuelve a ejecutar" -ForegroundColor Yellow
    Start-Process notepad ".env" -Wait
    exit 0
}
Write-Host "  .env encontrado" -ForegroundColor Green

# ── Entorno virtual Python ────────────────────────────────────────────────────
Write-Host ""
if (-not (Test-Path "venv\Scripts\python.exe")) {
    Write-Host "  [SETUP] Creando entorno virtual Python..." -ForegroundColor Yellow
    python -m venv venv
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] No se pudo crear el venv." -ForegroundColor Red
        Read-Host "`n  Presiona Enter para cerrar"
        exit 1
    }

    Write-Host "  [SETUP] Instalando dependencias (1-2 min)..." -ForegroundColor Yellow
    & venv\Scripts\pip.exe install -r backend\requirements.local.txt -q --disable-pip-version-check
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Fallo pip install." -ForegroundColor Red
        Read-Host "`n  Presiona Enter para cerrar"
        exit 1
    }
    Write-Host "  Dependencias Python instaladas" -ForegroundColor Green
} else {
    Write-Host "  Entorno virtual Python listo" -ForegroundColor Green
}

# ── Compilar frontend (solo si no existe o es primera vez) ────────────────────
if (-not (Test-Path "frontend\out\index.html")) {
    Write-Host ""
    Write-Host "  [SETUP] Compilando frontend (primera vez, 1-2 min)..." -ForegroundColor Yellow

    # Necesitamos Node.js solo para compilar
    node --version >$null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Node.js necesario para compilar el frontend." -ForegroundColor Red
        Write-Host "          Instala Node.js LTS desde: https://nodejs.org" -ForegroundColor Yellow
        Read-Host "`n  Presiona Enter para cerrar"
        exit 1
    }

    Push-Location frontend
    if (-not (Test-Path "node_modules\next")) {
        Write-Host "  [SETUP] Instalando dependencias Node..." -ForegroundColor Yellow
        npm install --silent
    }
    npm run build
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        Write-Host "  [ERROR] Fallo la compilacion del frontend." -ForegroundColor Red
        Read-Host "`n  Presiona Enter para cerrar"
        exit 1
    }
    Pop-Location
    Write-Host "  Frontend compilado" -ForegroundColor Green
} else {
    Write-Host "  Frontend listo (compilado)" -ForegroundColor Green
}

# ── Iniciar backend (sirve API + frontend estatico) ───────────────────────────
Write-Host ""
Write-Host "  Iniciando servidor..." -ForegroundColor Cyan

$serverCmd = "Set-Location '$Root'; .\venv\Scripts\Activate.ps1; uvicorn backend.main:app --host 127.0.0.1 --port 8000"
$proc = Start-Process powershell -ArgumentList "-NoExit", "-Command", $serverCmd -WindowStyle Minimized -PassThru

Write-Host "  Esperando que el servidor levante..." -ForegroundColor Gray
Start-Sleep -Seconds 4

# ── Abrir navegador ───────────────────────────────────────────────────────────
Start-Process "http://localhost:8000"

# ── Panel de control ─────────────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  ================================================" -ForegroundColor Green
Write-Host "   Resume Adapter esta corriendo!" -ForegroundColor Green
Write-Host "  ================================================" -ForegroundColor Green
Write-Host ""
Write-Host "   Abre:  http://localhost:8000" -ForegroundColor White
Write-Host "   API:   http://localhost:8000/docs" -ForegroundColor White
Write-Host ""
Write-Host "  ------------------------------------------------" -ForegroundColor DarkGray
Write-Host "   Presiona Enter para DETENER" -ForegroundColor Yellow
Write-Host "  ------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Enter"

# ── Detener ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Deteniendo servidor..." -ForegroundColor Yellow
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Get-Process -Name "uvicorn" -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host "  Listo. Hasta luego!" -ForegroundColor Green
Start-Sleep -Seconds 1
