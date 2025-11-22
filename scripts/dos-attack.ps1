# Script de Ataque DoS - VERSION MEJORADA
# Genera carga real observable en Grafana
# SOLO PARA TESTING

param(
    [int]$Duration = 60,
    [int]$Threads = 20,
    [string]$Target = "http://localhost"
)

$ErrorActionPreference = "Continue"

Write-Host "================================================================" -ForegroundColor Red
Write-Host "       ATAQUE DoS - CARGA EXTREMA" -ForegroundColor Red
Write-Host "================================================================" -ForegroundColor Red
Write-Host ""
Write-Host "Target: $Target" -ForegroundColor White
Write-Host "Duracion: $Duration segundos" -ForegroundColor White
Write-Host "Threads concurrentes: $Threads" -ForegroundColor White
Write-Host ""
Write-Host "Presiona ENTER para iniciar..." -ForegroundColor Yellow
Read-Host

$startTime = Get-Date

# Script que ejecuta cada thread
$attackScript = {
    param($target, $duration, $threadId)

    $endTime = (Get-Date).AddSeconds($duration)
    $count = 0

    while ((Get-Date) -lt $endTime) {
        try {
            # Alternar entre GET y POST
            if ($count % 3 -eq 0) {
                # POST - Crear tarea
                $null = Invoke-WebRequest -Uri "$target/api/tasks?text=DoS_$threadId_$count" -Method POST -UseBasicParsing -TimeoutSec 1 -ErrorAction SilentlyContinue
            } else {
                # GET - Leer tareas
                $null = Invoke-WebRequest -Uri "$target/api/tasks" -Method GET -UseBasicParsing -TimeoutSec 1 -ErrorAction SilentlyContinue
            }
            $count++
        } catch {
            # Ignorar errores y continuar atacando
        }
    }

    return $count
}

Write-Host ""
Write-Host "[INICIANDO ATAQUE]" -ForegroundColor Red
Write-Host ""

# Lanzar threads
$jobs = @()
for ($i = 0; $i -lt $Threads; $i++) {
    $job = Start-Job -ScriptBlock $attackScript -ArgumentList $Target, $Duration, $i
    $jobs += $job
    Write-Host "[Thread $i] Lanzado" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Ataque en progreso..." -ForegroundColor Yellow
Write-Host "Abre Grafana para ver las metricas subir: http://grafana.localhost" -ForegroundColor Cyan
Write-Host ""

# Monitorear progreso
$elapsed = 0
while ($elapsed -lt $Duration) {
    $running = (Get-Job -State Running).Count
    $progress = [math]::Round(($elapsed / $Duration) * 100, 1)

    $bar = ""
    $barLength = 50
    $filled = [math]::Floor(($progress / 100) * $barLength)
    for ($i = 0; $i -lt $barLength; $i++) {
        if ($i -lt $filled) {
            $bar += "█"
        } else {
            $bar += "░"
        }
    }

    Write-Host "`r[$bar] $progress% - $elapsed/$Duration seg - Threads activos: $running" -NoNewline -ForegroundColor Cyan

    Start-Sleep -Seconds 1
    $elapsed++
}

Write-Host ""
Write-Host ""
Write-Host "[FINALIZANDO] Esperando threads..." -ForegroundColor Yellow

# Esperar a que terminen todos
Wait-Job -Job $jobs | Out-Null

# Recolectar resultados
$totalRequests = 0
foreach ($job in $jobs) {
    $result = Receive-Job -Job $job
    if ($result) {
        $totalRequests += $result
    }
    Remove-Job -Job $job -Force
}

$endTime = Get-Date
$actualDuration = ($endTime - $startTime).TotalSeconds

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "       ATAQUE COMPLETADO" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Estadisticas:" -ForegroundColor Cyan
Write-Host "  - Duracion: $([math]::Round($actualDuration, 1)) segundos" -ForegroundColor White
Write-Host "  - Peticiones totales: $totalRequests" -ForegroundColor White
Write-Host "  - Peticiones/segundo: $([math]::Round($totalRequests / $actualDuration, 1))" -ForegroundColor Yellow
Write-Host "  - Threads usados: $Threads" -ForegroundColor White
Write-Host ""
Write-Host "QUE VER EN GRAFANA:" -ForegroundColor Cyan
Write-Host "  1. CPU debio subir significativamente" -ForegroundColor White
Write-Host "  2. Memoria puede haber aumentado" -ForegroundColor White
Write-Host "  3. Peticiones/seg mostro un pico alto" -ForegroundColor White
Write-Host "  4. Si fue POST, tareas creadas aumento" -ForegroundColor White
Write-Host ""
Write-Host "Grafana: http://grafana.localhost" -ForegroundColor Yellow
Write-Host ""
