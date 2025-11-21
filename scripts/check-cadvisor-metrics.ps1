# Script para verificar metricas de cAdvisor en K3S
# Este script ayuda a diagnosticar que metricas estan disponibles en Prometheus

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Verificacion de Metricas de cAdvisor en K3S" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Iniciar port-forward a Prometheus
Write-Host "Iniciando port-forward a Prometheus..." -ForegroundColor Yellow
$promJob = Start-Job -ScriptBlock { kubectl port-forward svc/prometheus 9090:9090 2>$null }
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[1/3] Verificando metricas de CPU disponibles" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

try {
    Write-Host "Consultando: container_cpu_usage_seconds_total" -ForegroundColor Yellow
    $cpuQuery = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/query?query=container_cpu_usage_seconds_total" -UseBasicParsing -ErrorAction Stop

    if ($cpuQuery.data.result) {
        $sampleMetric = $cpuQuery.data.result[0]
        Write-Host "[OK] Metricas de CPU encontradas: $($cpuQuery.data.result.Count) series" -ForegroundColor Green
        Write-Host ""
        Write-Host "Ejemplo de labels disponibles:" -ForegroundColor Yellow
        $sampleMetric.metric.PSObject.Properties | ForEach-Object {
            Write-Host "  $($_.Name) = $($_.Value)" -ForegroundColor Gray
        }
        Write-Host ""

        # Filtrar metricas relevantes para nuestras apps
        Write-Host "Metricas relevantes para API y WEB:" -ForegroundColor Yellow
        $appMetrics = $cpuQuery.data.result | Where-Object {
            $_.metric.pod -match "^(api-|web-)" -or $_.metric.container -match "^(api|web)$"
        }

        if ($appMetrics) {
            Write-Host "[OK] Encontradas $($appMetrics.Count) metricas de CPU para nuestras apps" -ForegroundColor Green
            foreach ($metric in $appMetrics | Select-Object -First 3) {
                Write-Host "  - Pod: $($metric.metric.pod), Container: $($metric.metric.container), Namespace: $($metric.metric.namespace)" -ForegroundColor Gray
            }
        } else {
            Write-Host "[WARNING] No se encontraron metricas para pods api- o web-" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[ERROR] No se encontraron metricas de CPU" -ForegroundColor Red
    }
} catch {
    Write-Host "[ERROR] No se pudo consultar metricas de CPU" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Gray
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[2/3] Verificando metricas de Memoria disponibles" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

try {
    Write-Host "Consultando: container_memory_usage_bytes" -ForegroundColor Yellow
    $memQuery = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/query?query=container_memory_usage_bytes" -UseBasicParsing -ErrorAction Stop

    if ($memQuery.data.result) {
        Write-Host "[OK] Metricas de Memoria encontradas: $($memQuery.data.result.Count) series" -ForegroundColor Green
        Write-Host ""

        # Filtrar metricas relevantes para nuestras apps
        $appMetrics = $memQuery.data.result | Where-Object {
            $_.metric.pod -match "^(api-|web-)" -or $_.metric.container -match "^(api|web)$"
        }

        if ($appMetrics) {
            Write-Host "[OK] Encontradas $($appMetrics.Count) metricas de Memoria para nuestras apps" -ForegroundColor Green
            foreach ($metric in $appMetrics | Select-Object -First 3) {
                $valueMB = [math]::Round($metric.value[1] / 1MB, 2)
                Write-Host "  - Pod: $($metric.metric.pod), Container: $($metric.metric.container), Uso: $valueMB MB" -ForegroundColor Gray
            }
        } else {
            Write-Host "[WARNING] No se encontraron metricas para pods api- o web-" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[ERROR] No se encontraron metricas de Memoria" -ForegroundColor Red
    }
} catch {
    Write-Host "[ERROR] No se pudo consultar metricas de Memoria" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Gray
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[3/3] Sugerencias de queries para Grafana" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Para CPU por contenedor (%):" -ForegroundColor Yellow
Write-Host '  rate(container_cpu_usage_seconds_total{pod=~"api-.*|web-.*", container!="", container!="POD"}[5m]) * 100' -ForegroundColor White
Write-Host ""

Write-Host "Para Memoria por contenedor (bytes):" -ForegroundColor Yellow
Write-Host '  container_memory_usage_bytes{pod=~"api-.*|web-.*", container!="", container!="POD"}' -ForegroundColor White
Write-Host ""

Write-Host "Para filtrar solo por API:" -ForegroundColor Yellow
Write-Host '  container_memory_usage_bytes{pod=~"api-.*", container!="", container!="POD"}' -ForegroundColor White
Write-Host ""

# Detener port-forward
Stop-Job -Job $promJob -ErrorAction SilentlyContinue
Remove-Job -Job $promJob -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Verificacion completa" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "PROXIMOS PASOS:" -ForegroundColor Yellow
Write-Host "1. Si viste metricas arriba, el dashboard necesita queries actualizadas" -ForegroundColor White
Write-Host "2. Voy a actualizar el archivo del dashboard con los queries correctos" -ForegroundColor White
Write-Host "3. Despues vuelve a importar el dashboard en Grafana" -ForegroundColor White
Write-Host ""
