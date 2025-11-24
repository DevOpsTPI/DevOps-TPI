# Script para matar un pod de la aplicación (API, Web o Redis)
# Simula un crash matando el proceso principal (PID 1)

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Script para Matar Pods - Demo Auto-Recuperación" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Menú de selección
Write-Host "Selecciona el tipo de pod a matar:" -ForegroundColor Yellow
Write-Host "1) API" -ForegroundColor Green
Write-Host "2) WEB" -ForegroundColor Green
Write-Host "3) Redis" -ForegroundColor Green
Write-Host "4) Salir" -ForegroundColor Red
Write-Host ""

$option = Read-Host "Ingresa tu opción (1-4)"

$app = ""
switch ($option) {
    "1" { $app = "api" }
    "2" { $app = "web" }
    "3" { $app = "redis" }
    "4" {
        Write-Host "Saliendo..." -ForegroundColor Yellow
        exit 0
    }
    default {
        Write-Host "Opción inválida" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Obteniendo pods de: $app" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Obtener pods
$pods = kubectl get pods -l app=$app -o jsonpath='{.items[*].metadata.name}' 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($pods)) {
    Write-Host "ERROR: No se encontraron pods para app=$app" -ForegroundColor Red
    Write-Host "Verifica que el cluster esté corriendo y los pods estén desplegados" -ForegroundColor Yellow
    exit 1
}

# Convertir a array
$podArray = $pods -split " "

# Mostrar pods disponibles
Write-Host "Pods disponibles:" -ForegroundColor Yellow
for ($i = 0; $i -lt $podArray.Length; $i++) {
    $status = kubectl get pod $podArray[$i] -o jsonpath='{.status.phase}' 2>$null
    Write-Host "$($i + 1)) $($podArray[$i]) - Status: $status" -ForegroundColor Green
}
Write-Host ""

# Seleccionar pod
$podIndex = Read-Host "Selecciona el número del pod a matar (1-$($podArray.Length))"
$podIndexNum = [int]$podIndex - 1

if ($podIndexNum -lt 0 -or $podIndexNum -ge $podArray.Length) {
    Write-Host "ERROR: Selección inválida" -ForegroundColor Red
    exit 1
}

$selectedPod = $podArray[$podIndexNum]

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Matando pod: $selectedPod" -ForegroundColor Red
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Confirmar acción
Write-Host "¿Estás seguro de matar el pod '$selectedPod'? (S/N)" -ForegroundColor Yellow
$confirm = Read-Host
if ($confirm -ne "S" -and $confirm -ne "s") {
    Write-Host "Operación cancelada" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Iniciando monitoreo en segundo plano..." -ForegroundColor Cyan
Write-Host "Abre otra terminal y ejecuta: kubectl get pods -l app=$app --watch" -ForegroundColor Yellow
Write-Host ""

# Mostrar estado antes
Write-Host "Estado ANTES de matar el pod:" -ForegroundColor Cyan
kubectl get pods -l app=$app -o wide

Write-Host ""
Write-Host "Ejecutando: kubectl exec $selectedPod -- kill 1" -ForegroundColor Red
Write-Host ""

# Ejecutar kill
kubectl exec $selectedPod -- kill 1 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "Comando ejecutado exitosamente" -ForegroundColor Green
    Write-Host "El pod debería reiniciarse automáticamente en unos segundos..." -ForegroundColor Yellow
} else {
    Write-Host "El pod probablemente se está reiniciando (esto es esperado)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Esperando 3 segundos..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "Estado DESPUÉS de matar el pod:" -ForegroundColor Cyan
kubectl get pods -l app=$app -o wide

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Monitoreo de Eventos" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Últimos eventos del pod:" -ForegroundColor Yellow
kubectl get events --field-selector involvedObject.name=$selectedPod --sort-by='.lastTimestamp' | Select-Object -Last 10

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "  Demo Completada" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Tips:" -ForegroundColor Yellow
Write-Host "- Revisa Grafana para ver las métricas de disponibilidad" -ForegroundColor White
Write-Host "- Ejecuta 'kubectl get pods -l app=$app --watch' para ver la recuperación en tiempo real" -ForegroundColor White
Write-Host "- Verifica los reinicios: kubectl get pods -l app=$app" -ForegroundColor White
Write-Host ""
