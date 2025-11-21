# Script de verificacion del sistema de telemetria para Windows
# PowerShell Script

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Verificacion del Sistema de Telemetria" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Detectar entorno (Kubernetes o Docker Compose)
$ENVIRONMENT = "unknown"

try {
    $null = kubectl get pods 2>&1
    if ($LASTEXITCODE -eq 0) {
        $ENVIRONMENT = "kubernetes"
        Write-Host "Entorno detectado: Kubernetes" -ForegroundColor Green
    }
}
catch {
    $ENVIRONMENT = "docker-compose"
    Write-Host "Entorno detectado: Docker Compose" -ForegroundColor Green
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[1/6] Verificando servicios..." -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

if ($ENVIRONMENT -eq "kubernetes") {
    Write-Host ""
    Write-Host "Pods de telemetria:" -ForegroundColor Yellow
    kubectl get pods -l tier=monitoring

    Write-Host ""
    Write-Host "Servicios de telemetria:" -ForegroundColor Yellow
    kubectl get svc -l tier=monitoring

    Write-Host ""
    Write-Host "Ingress de monitoreo:" -ForegroundColor Yellow
    kubectl get ingress monitoring-ingress
}
else {
    Write-Host ""
    Write-Host "Contenedores de telemetria:" -ForegroundColor Yellow
    docker-compose ps prometheus grafana redis-exporter nginx-exporter cadvisor
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[2/6] Verificando targets de Prometheus..." -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

if ($ENVIRONMENT -eq "kubernetes") {
    Write-Host "Iniciando port-forward a Prometheus..." -ForegroundColor Yellow
    $promJob = Start-Job -ScriptBlock { kubectl port-forward svc/prometheus 9090:9090 2>$null }
    Start-Sleep -Seconds 3
}

Write-Host ""
Write-Host "Consultando targets de Prometheus..." -ForegroundColor Yellow

try {
    $targetsJson = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/targets" -UseBasicParsing -ErrorAction Stop

    if ($targetsJson.data.activeTargets) {
        $targets = $targetsJson.data.activeTargets
        Write-Host "[OK] Total de targets: $($targets.Count)" -ForegroundColor Green
        Write-Host ""

        $jobs = @{}
        foreach ($target in $targets) {
            $job = $target.labels.job
            if (-not $job) { $job = "unknown" }

            $health = $target.health

            if (-not $jobs.ContainsKey($job)) {
                $jobs[$job] = @{ up = 0; down = 0 }
            }

            if ($health -eq "up") {
                $jobs[$job].up++
            }
            else {
                $jobs[$job].down++
            }
        }

        foreach ($job in $jobs.Keys | Sort-Object) {
            $counts = $jobs[$job]
            if ($counts.down -eq 0) {
                Write-Host "[OK] Job: $($job.PadRight(25)) - UP: $($counts.up)" -ForegroundColor Green
            }
            else {
                Write-Host "[ERROR] Job: $($job.PadRight(25)) - UP: $($counts.up), DOWN: $($counts.down)" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "[WARNING] No se encontraron targets configurados" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[ERROR] No se pudo conectar a Prometheus" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Gray
}

if ($ENVIRONMENT -eq "kubernetes") {
    Stop-Job -Job $promJob -ErrorAction SilentlyContinue
    Remove-Job -Job $promJob -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[3/6] Verificando datasource de Grafana..." -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

if ($ENVIRONMENT -eq "kubernetes") {
    Write-Host "Iniciando port-forward a Grafana..." -ForegroundColor Yellow
    $grafJob = Start-Job -ScriptBlock { kubectl port-forward svc/grafana 3000:3000 2>$null }
    Start-Sleep -Seconds 3
}

Write-Host ""
Write-Host "Consultando datasources de Grafana..." -ForegroundColor Yellow

try {
    $credential = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:admin"))
    $headers = @{ Authorization = "Basic $credential" }

    $datasources = Invoke-RestMethod -Uri "http://localhost:3000/api/datasources" -Headers $headers -UseBasicParsing -ErrorAction Stop

    if ($datasources) {
        Write-Host "[OK] Total de datasources: $($datasources.Count)" -ForegroundColor Green
        Write-Host ""

        foreach ($ds in $datasources) {
            $defaultTag = if ($ds.isDefault) { "(default)" } else { "" }
            Write-Host "[OK] $($ds.name.PadRight(20)) - Type: $($ds.type.PadRight(15)) - URL: $($ds.url) $defaultTag" -ForegroundColor Green
        }
    }
    else {
        Write-Host "[WARNING] No se encontraron datasources configurados" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[ERROR] No se pudo conectar a Grafana (credenciales: admin/admin)" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Gray
}

if ($ENVIRONMENT -eq "kubernetes") {
    Stop-Job -Job $grafJob -ErrorAction SilentlyContinue
    Remove-Job -Job $grafJob -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[4/6] Verificando endpoint /metrics de la API..." -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

if ($ENVIRONMENT -eq "kubernetes") {
    Write-Host ""
    Write-Host "Iniciando port-forward del servicio API..." -ForegroundColor Yellow
    $apiJob = Start-Job -ScriptBlock { kubectl port-forward svc/api 8000:8000 2>$null }
    Start-Sleep -Seconds 3
    $API_URL = "http://localhost:8000"
}
else {
    $API_URL = "http://localhost:8000"
}

Write-Host ""
Write-Host "Verificando endpoint /metrics..." -ForegroundColor Yellow

try {
    $response = Invoke-WebRequest -Uri "$API_URL/metrics" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host "[OK] API /metrics endpoint esta accesible" -ForegroundColor Green
    }
}
catch {
    Write-Host "[ERROR] API /metrics endpoint NO esta accesible" -ForegroundColor Red
}

Write-Host ""
Write-Host "Muestreando algunas metricas de la API:" -ForegroundColor Yellow

try {
    $metrics = Invoke-WebRequest -Uri "$API_URL/metrics" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop

    if ($metrics.Content) {
        $lines = $metrics.Content -split "`n" | Where-Object { $_ -match "^(http_requests_total|tasks_created_total|tasks_current|http_request_duration_seconds_count)" } | Select-Object -First 5

        if ($lines) {
            $lines | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            Write-Host "[OK] Metricas de la API estan siendo exportadas correctamente" -ForegroundColor Green
        }
        else {
            Write-Host "[WARNING] No se encontraron metricas esperadas en el endpoint" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "[ERROR] No se pudo obtener metricas de la API" -ForegroundColor Red
}

if ($ENVIRONMENT -eq "kubernetes") {
    Stop-Job -Job $apiJob -ErrorAction SilentlyContinue
    Remove-Job -Job $apiJob -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[5/6] Test de conectividad Prometheus -> API" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

if ($ENVIRONMENT -eq "kubernetes") {
    $promJob = Start-Job -ScriptBlock { kubectl port-forward svc/prometheus 9090:9090 2>$null }
    Start-Sleep -Seconds 3
}

Write-Host ""
Write-Host "Consultando metricas de la API desde Prometheus..." -ForegroundColor Yellow

try {
    $queryResult = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/query?query=up{job=`"api`"}" -UseBasicParsing -ErrorAction Stop

    if ($queryResult.data.result) {
        $results = $queryResult.data.result

        foreach ($result in $results) {
            $instance = $result.metric.instance
            if (-not $instance) { $instance = "unknown" }

            $value = $result.value[1]

            if ($value -eq "1") {
                Write-Host "[OK] API instance $instance : UP" -ForegroundColor Green
            }
            else {
                Write-Host "[ERROR] API instance $instance : DOWN" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "[WARNING] Prometheus no esta recibiendo metricas del job 'api'" -ForegroundColor Yellow
        Write-Host "   Esto puede significar que:" -ForegroundColor Gray
        Write-Host "   - La API no ha sido scrapeada aun (espera 10-15 segundos)" -ForegroundColor Gray
        Write-Host "   - Hay un problema de conectividad en la red monitoring-network" -ForegroundColor Gray
    }
}
catch {
    Write-Host "[ERROR] No se pudo consultar Prometheus" -ForegroundColor Red
}

if ($ENVIRONMENT -eq "kubernetes") {
    Stop-Job -Job $promJob -ErrorAction SilentlyContinue
    Remove-Job -Job $promJob -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[6/6] Verificacion completa" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

if ($ENVIRONMENT -eq "kubernetes") {
    Write-Host "URLs de acceso (K3D):" -ForegroundColor Yellow
    Write-Host "   - Grafana: http://grafana.localhost (admin/admin)" -ForegroundColor White
    Write-Host "   - Prometheus: http://prometheus.localhost" -ForegroundColor White
    Write-Host ""
    Write-Host "Para acceso directo (alternativa):" -ForegroundColor Yellow
    Write-Host "   kubectl port-forward svc/grafana 3000:3000" -ForegroundColor Gray
    Write-Host "   kubectl port-forward svc/prometheus 9090:9090" -ForegroundColor Gray
}
else {
    Write-Host "URLs de acceso (Docker Compose):" -ForegroundColor Yellow
    Write-Host "   - Grafana: http://localhost:3000 (admin/admin)" -ForegroundColor White
    Write-Host "   - Prometheus: http://localhost:9090" -ForegroundColor White
    Write-Host "   - cAdvisor: http://localhost:8081" -ForegroundColor White
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "PROXIMOS PASOS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Abrir Prometheus: http://prometheus.localhost" -ForegroundColor White
Write-Host "   - Ve a Status -> Targets" -ForegroundColor Gray
Write-Host "   - Verifica que los jobs estan UP" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Abrir Grafana: http://grafana.localhost" -ForegroundColor White
Write-Host "   - Login: admin / admin" -ForegroundColor Gray
Write-Host "   - Ve a Dashboards -> Todo App - Metricas Completas" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Generar trafico para ver metricas:" -ForegroundColor White
Write-Host '   1..20 | ForEach-Object { Invoke-WebRequest -Uri "http://localhost/api/tasks?text=Test_$_" -Method POST }' -ForegroundColor Gray
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
