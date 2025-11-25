# Script para desplegar Prometheus y Grafana en k3d
# Ejecutar desde la raiz del proyecto

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Desplegando Stack de Monitoreo (Prometheus + Grafana)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que kubectl esta disponible
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: kubectl no esta instalado o no esta en el PATH" -ForegroundColor Red
    exit 1
}

# Verificar que el cluster esta corriendo
Write-Host "[1/7] Verificando cluster k3d..." -ForegroundColor Yellow
$clusterStatus = kubectl get nodes 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: No se puede conectar al cluster. Asegurate de que k3d esta corriendo." -ForegroundColor Red
    exit 1
}
Write-Host "OK Cluster activo" -ForegroundColor Green
Write-Host ""

# Desplegar Prometheus
Write-Host "[2/7] Desplegando Prometheus..." -ForegroundColor Yellow
kubectl apply -f deploy/prometheus-configmap.yaml
kubectl apply -f deploy/prometheus-rbac.yaml
kubectl apply -f deploy/prometheus-deployment.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Fallo al desplegar Prometheus" -ForegroundColor Red
    exit 1
}
Write-Host "OK Prometheus desplegado" -ForegroundColor Green
Write-Host ""

# Desplegar kube-state-metrics
Write-Host "[3/7] Desplegando kube-state-metrics..." -ForegroundColor Yellow
kubectl apply -f deploy/kube-state-metrics.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Fallo al desplegar kube-state-metrics" -ForegroundColor Red
    exit 1
}
Write-Host "OK kube-state-metrics desplegado" -ForegroundColor Green
Write-Host ""

# Actualizar deployments con exporters
Write-Host "[4/7] Actualizando deployments con exporters (Web y Redis)..." -ForegroundColor Yellow
kubectl apply -f deploy/web-deployment.yaml
kubectl apply -f deploy/redis-statefulset.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Fallo al actualizar deployments" -ForegroundColor Red
    exit 1
}
Write-Host "OK Exporters desplegados (nginx-exporter, redis-exporter)" -ForegroundColor Green
Write-Host ""

# Desplegar Grafana
Write-Host "[5/7] Desplegando Grafana..." -ForegroundColor Yellow
kubectl apply -f deploy/grafana-configmap.yaml
kubectl apply -f deploy/grafana-deployment.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Fallo al desplegar Grafana" -ForegroundColor Red
    exit 1
}
Write-Host "OK Grafana desplegado" -ForegroundColor Green
Write-Host ""

# Actualizar Ingress
Write-Host "[6/7] Actualizando Ingress para exponer Grafana y Prometheus..." -ForegroundColor Yellow
kubectl apply -f deploy/ingress.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Fallo al actualizar Ingress" -ForegroundColor Red
    exit 1
}
Write-Host "OK Ingress actualizado" -ForegroundColor Green
Write-Host ""

# Esperar a que todos los pods esten ready
Write-Host "[7/7] Esperando a que todos los pods esten listos..." -ForegroundColor Yellow
Write-Host "Esperando Prometheus..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=prometheus --timeout=120s 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ADVERTENCIA: Prometheus tardo mas de lo esperado" -ForegroundColor Yellow
}

Write-Host "Esperando kube-state-metrics..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=kube-state-metrics --timeout=120s 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ADVERTENCIA: kube-state-metrics tardo mas de lo esperado" -ForegroundColor Yellow
}

Write-Host "Esperando Grafana..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=grafana --timeout=120s 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ADVERTENCIA: Grafana tardo mas de lo esperado" -ForegroundColor Yellow
}

Write-Host "Esperando Web (con nginx-exporter)..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=web --timeout=120s 2>$null

Write-Host "Esperando Redis (con redis-exporter)..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=redis --timeout=120s 2>$null

Write-Host "OK Todos los componentes estan listos" -ForegroundColor Green
Write-Host ""

# Mostrar estado de los pods
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Estado de Pods de Monitoreo" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
kubectl get pods -l 'app in (prometheus,grafana,kube-state-metrics)'
Write-Host ""

# Mostrar URLs de acceso
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  URLs de Acceso" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Aplicacion Web:  http://localhost/" -ForegroundColor White
Write-Host "API:             http://localhost/api" -ForegroundColor White
Write-Host "Grafana:         http://localhost/grafana" -ForegroundColor Green
Write-Host "                 Usuario: admin / Password: admin" -ForegroundColor Gray
Write-Host "Prometheus:      http://localhost/prometheus" -ForegroundColor Green
Write-Host ""
Write-Host "Dashboard: 'To-Do App - Monitoreo Completo' (preconfigurado)" -ForegroundColor Cyan
Write-Host ""

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Metricas Disponibles" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "1. Estado de replicas (activo/inactivo) por servicio/nodo" -ForegroundColor White
Write-Host "2. CPU consumido (%) por servicio/replica/nodo" -ForegroundColor White
Write-Host "3. RAM consumida (%) por servicio/replica/nodo" -ForegroundColor White
Write-Host "4. Graficos de CPU por servicio/replica/nodo" -ForegroundColor White
Write-Host "5. Graficos de RAM por servicio/replica/nodo" -ForegroundColor White
Write-Host "6. Cantidad de tareas existentes" -ForegroundColor White
Write-Host "7. Peticiones realizadas a la API (req/s)" -ForegroundColor White
Write-Host ""

Write-Host "================================================" -ForegroundColor Green
Write-Host "  Despliegue Completado Exitosamente!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
