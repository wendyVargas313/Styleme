# StyleMe - Script de inicio del backend
# Ejecutar desde la carpeta D:\Styleme con:
#   powershell -ExecutionPolicy Bypass -File iniciar_backend.ps1

$PYTHON = "C:\Users\iwend\AppData\Local\Programs\Python\Python313\python.exe"
$BACKEND = "$PSScriptRoot\styleme-backend"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   StyleMe Backend - Iniciando..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar Python
if (-not (Test-Path $PYTHON)) {
    Write-Host "[ERROR] Python 3.13 no encontrado en: $PYTHON" -ForegroundColor Red
    Write-Host "        Instala Python desde python.org" -ForegroundColor Yellow
    pause; exit 1
}
Write-Host "[OK] Python 3.13 encontrado" -ForegroundColor Green

# Verificar MongoDB
$mongo = Get-NetTCPConnection -LocalPort 27017 -ErrorAction SilentlyContinue
if (-not $mongo) {
    Write-Host "[WARN] MongoDB no detectado en puerto 27017" -ForegroundColor Yellow
    Write-Host "       Iniciando mongod..." -ForegroundColor Yellow
    Start-Process "mongod" -WindowStyle Hidden -ErrorAction SilentlyContinue
    Start-Sleep 3
}
Write-Host "[OK] MongoDB listo" -ForegroundColor Green

# Verificar modelos ML
$modelos = @("styleme_detector.pt", "modelo_color.pkl", "modelo_recomendador_outfits.pkl")
foreach ($m in $modelos) {
    if (Test-Path "$PSScriptRoot\$m") {
        Write-Host "[OK] Modelo: $m" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Falta modelo: $m" -ForegroundColor Red
    }
}

# Liberar puerto 8000 si está ocupado
$tcp = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
if ($tcp) {
    Write-Host "[INFO] Liberando puerto 8000..." -ForegroundColor Yellow
    Stop-Process -Id $tcp.OwningProcess -Force -ErrorAction SilentlyContinue
    Start-Sleep 2
}

Write-Host ""
Write-Host "Iniciando servidor en http://localhost:8000" -ForegroundColor Cyan
Write-Host "Documentacion: http://localhost:8000/docs" -ForegroundColor Cyan
Write-Host "Health check: http://localhost:8000/api/v1/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "Presiona Ctrl+C para detener el servidor" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

# Iniciar el servidor
Set-Location $BACKEND
& $PYTHON -m uvicorn main:app --host 0.0.0.0 --port 8000
