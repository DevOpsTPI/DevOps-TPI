# Script de despliegue automatico para K3D en Windows
# PowerShell Script

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Despliegue Automatico en K3D (Windows)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$CLUSTER_NAME = "todo-app"

# Funcion para verificar si un comando existe
function Test-CommandExists {
    param($command)
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}

# Verificar dependencias
Write-Host "[1/10] Verificando dependencias..." -ForegroundColor Yellow

if (-not (Test-CommandExists "k3d")) {
    Write-Host "[ERROR] k3d no esta instalado." -ForegroundColor Red
    Write-Host ""
    Write-Host "Instalalo con uno de estos metodos:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Opcion 1 - Chocolatey (Recomendado):" -ForegroundColor White
    Write-Host "  choco install k3d" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Opcion 2 - Scoop:" -ForegroundColor White
    Write-Host "  scoop install k3d" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Opcion 3 - Descarga manual:" -ForegroundColor White
    Write-Host "  https://github.com/k3d-io/k3d/releases" -ForegroundColor Gray
    exit 1
}

if (-not (Test-CommandExists "kubectl")) {
    Write-Host "[ERROR] kubectl no esta instalado." -ForegroundColor Red
    Write-Host ""
    Write-Host "Instalalo con:" -ForegroundColor Yellow
    Write-Host "  choco install kubernetes-cli" -ForegroundColor Gray
    exit 1
}

if (-not (Test-CommandExists "docker")) {
    Write-Host "[ERROR] Docker no esta instalado." -ForegroundColor Red
    Write-Host ""
    Write-Host "Instala Docker Desktop desde:" -ForegroundColor Yellow
    Write-Host "  https://www.docker.com/products/docker-desktop" -ForegroundColor Gray
    exit 1
}

Write-Host "[OK] Todas las dependencias estan instaladas" -ForegroundColor Green
Write-Host ""

# Verificar si Docker esta corriendo
Write-Host "[2/10] Verificando Docker..." -ForegroundColor Yellow
try {
    docker ps | Out-Null
    Write-Host "[OK] Docker esta corriendo" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Docker no esta corriendo." -ForegroundColor Red
    Write-Host "   Por favor, inicia Docker Desktop y vuelve a ejecutar este script." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Verificar si el cluster ya existe
Write-Host "[3/10] Verificando cluster existente..." -ForegroundColor Yellow
$clusterExists = k3d cluster list 2>&1 | Select-String -Pattern $CLUSTER_NAME -Quiet

if ($clusterExists) {
    Write-Host "[WARNING] El cluster '$CLUSTER_NAME' ya existe." -ForegroundColor Yellow
    $response = Read-Host "Deseas eliminarlo y crear uno nuevo? (y/n)"

    if ($response -eq "y" -or $response -eq "Y") {
        Write-Host "Eliminando cluster existente..." -ForegroundColor Yellow
        k3d cluster delete $CLUSTER_NAME
        $clusterExists = $false
    } else {
        Write-Host "[OK] Usando cluster existente" -ForegroundColor Blue
    }
}

Write-Host ""

# Crear cluster si no existe
if (-not $clusterExists) {
    Write-Host "[4/10] Creando cluster K3D '$CLUSTER_NAME' con 3 nodos..." -ForegroundColor Yellow
    Write-Host "   - Nodo maestro (server-0): 512 MB RAM, 1 CPU - Control Plane" -ForegroundColor Gray
    Write-Host "   - Nodo agente 0 (agent-0): 1024 MB RAM, 1 CPU - Aplicacion" -ForegroundColor Gray
    Write-Host "   - Nodo agente 1 (agent-1): 1024 MB RAM, 1 CPU - Telemetria" -ForegroundColor Gray

    k3d cluster create $CLUSTER_NAME `
        --api-port 6550 `
        --port "80:80@loadbalancer" `
        --port "443:443@loadbalancer" `
        --agents 2 `
        --servers-memory 512m `
        --agents-memory 1024m `
        --k3s-arg "--kubelet-arg=cpu-manager-policy=none@server:*" `
        --k3s-arg "--kubelet-arg=cpu-manager-policy=none@agent:*"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Error al crear el cluster" -ForegroundColor Red
        exit 1
    }

    # Aplicar limites de CPU a nivel de contenedor Docker
    Write-Host ""
    Write-Host "Aplicando limites de CPU y RAM a los nodos..." -ForegroundColor Yellow
    docker update --cpus="1.0" --memory="512m" "k3d-$CLUSTER_NAME-server-0" 2>&1 | Out-Null
    docker update --cpus="1.0" --memory="1024m" "k3d-$CLUSTER_NAME-agent-0" 2>&1 | Out-Null
    docker update --cpus="1.0" --memory="1024m" "k3d-$CLUSTER_NAME-agent-1" 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Limites de recursos aplicados a todos los nodos" -ForegroundColor Green
    }

    Write-Host "[OK] Cluster creado exitosamente" -ForegroundColor Green
} else {
    Write-Host "[4/10] [OK] Usando cluster existente" -ForegroundColor Green
}

Write-Host ""
Write-Host "Esperando a que el cluster este listo..." -ForegroundColor Yellow

kubectl wait --for=condition=Ready nodes --all --timeout=60s 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARNING] Timeout esperando nodos. Continuando de todas formas..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[4.5/10] Configurando nodos (labels y taints)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Aplicar taint al nodo maestro
Write-Host "Aplicando taint al nodo maestro (no scheduling de apps)..." -ForegroundColor Yellow
kubectl taint nodes k3d-$CLUSTER_NAME-server-0 node-role.kubernetes.io/control-plane=true:NoSchedule --overwrite 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Taint aplicado al nodo maestro" -ForegroundColor Green
}

# Etiquetar nodos agentes
Write-Host ""
Write-Host "Etiquetando nodos agentes..." -ForegroundColor Yellow

kubectl label nodes k3d-$CLUSTER_NAME-agent-0 node-type=application --overwrite 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Nodo agent-0 etiquetado como 'application'" -ForegroundColor Green
}

kubectl label nodes k3d-$CLUSTER_NAME-agent-1 node-type=monitoring --overwrite 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Nodo agent-1 etiquetado como 'monitoring'" -ForegroundColor Green
}

Write-Host ""
Write-Host "Verificando configuracion de nodos:" -ForegroundColor Yellow
kubectl get nodes -L node-type --show-labels=false

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[5/10] Construyendo e importando imagenes" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Verificar que estamos en la raiz del proyecto
if (-not (Test-Path ".\api\Dockerfile") -or -not (Test-Path ".\web\Dockerfile")) {
    Write-Host "[ERROR] No se encontraron los Dockerfiles." -ForegroundColor Red
    Write-Host "   Asegurate de ejecutar este script desde la raiz del proyecto TPI." -ForegroundColor Yellow
    exit 1
}

# Construir imagenes
Write-Host ""
Write-Host "Construyendo imagen de la API..." -ForegroundColor Yellow
docker build -t api:latest .\api

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error al construir imagen de la API" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Construyendo imagen del Web..." -ForegroundColor Yellow
docker build -t web:latest .\web

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error al construir imagen del Web" -ForegroundColor Red
    exit 1
}

# Importar imagenes al cluster
Write-Host ""
Write-Host "Importando imagenes al cluster K3D..." -ForegroundColor Yellow
k3d image import api:latest web:latest -c $CLUSTER_NAME

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error al importar imagenes" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Imagenes importadas exitosamente" -ForegroundColor Green

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[6/10] Desplegando aplicacion" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Verificar que existen los manifiestos
if (-not (Test-Path ".\deploy")) {
    Write-Host "[ERROR] No se encontro la carpeta deploy/" -ForegroundColor Red
    exit 1
}

# Desplegar Redis
Write-Host ""
Write-Host "Desplegando Redis..." -ForegroundColor Yellow
kubectl apply -f .\deploy\redis-deployment.yaml
kubectl apply -f .\deploy\redis-service.yaml

# Desplegar API
Write-Host ""
Write-Host "Desplegando API..." -ForegroundColor Yellow
kubectl apply -f .\deploy\api-deployment.yaml
kubectl apply -f .\deploy\api-service.yaml

# Desplegar Web
Write-Host ""
Write-Host "Desplegando Web..." -ForegroundColor Yellow
kubectl apply -f .\deploy\web-deployment.yaml
kubectl apply -f .\deploy\web-service.yaml

# Desplegar Ingress
Write-Host ""
Write-Host "Desplegando Ingress..." -ForegroundColor Yellow
kubectl apply -f .\deploy\ingress.yaml

Write-Host ""
Write-Host "Esperando a que los pods de la aplicacion esten listos..." -ForegroundColor Yellow

Start-Sleep -Seconds 5

kubectl wait --for=condition=Ready pods -l app=redis --timeout=120s 2>$null
kubectl wait --for=condition=Ready pods -l app=api --timeout=120s 2>$null
kubectl wait --for=condition=Ready pods -l app=web --timeout=120s 2>$null

Write-Host "[OK] Aplicacion desplegada exitosamente" -ForegroundColor Green

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[7/10] Desplegando sistema de telemetria" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Desplegar RBAC de Prometheus
Write-Host ""
Write-Host "Desplegando RBAC de Prometheus..." -ForegroundColor Yellow
kubectl apply -f .\deploy\prometheus-rbac.yaml

# Desplegar ConfigMap de Prometheus
Write-Host ""
Write-Host "Desplegando configuracion de Prometheus..." -ForegroundColor Yellow
kubectl apply -f .\deploy\prometheus-config.yaml

# Desplegar Prometheus
Write-Host ""
Write-Host "Desplegando Prometheus..." -ForegroundColor Yellow
kubectl apply -f .\deploy\prometheus-deployment.yaml

# Desplegar Grafana
Write-Host ""
Write-Host "Desplegando Grafana..." -ForegroundColor Yellow
kubectl apply -f .\deploy\grafana-deployment.yaml

# Desplegar Exporters (version K3D sin cAdvisor standalone)
Write-Host ""
Write-Host "Desplegando exporters..." -ForegroundColor Yellow
kubectl apply -f .\deploy\exporters-deployment-k3d.yaml

# Desplegar Ingress de monitoreo
Write-Host ""
Write-Host "Desplegando Ingress de monitoreo..." -ForegroundColor Yellow
kubectl apply -f .\deploy\monitoring-ingress.yaml

Write-Host ""
Write-Host "Esperando a que los pods de telemetria esten listos..." -ForegroundColor Yellow

Start-Sleep -Seconds 5

kubectl wait --for=condition=Ready pods -l app=prometheus --timeout=120s 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARNING] Prometheus aun no esta listo, continuando..." -ForegroundColor Yellow
}

kubectl wait --for=condition=Ready pods -l app=grafana --timeout=120s 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARNING] Grafana aun no esta listo, continuando..." -ForegroundColor Yellow
}

kubectl wait --for=condition=Ready pods -l tier=monitoring --timeout=120s 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARNING] Algunos exporters aun no estan listos, continuando..." -ForegroundColor Yellow
}

Write-Host "[OK] Sistema de telemetria desplegado" -ForegroundColor Green

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[8/10] Despliegue completo" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Mostrar estado
Write-Host "Estado de los pods:" -ForegroundColor Yellow
kubectl get pods

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[9/10] URLs de acceso" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Aplicacion:" -ForegroundColor White
Write-Host "    - Web:       http://localhost" -ForegroundColor Gray
Write-Host "    - API:       http://localhost/api" -ForegroundColor Gray
Write-Host ""
Write-Host "  Telemetria (configura hosts primero):" -ForegroundColor White
Write-Host "    - Grafana:   http://grafana.localhost (admin/admin)" -ForegroundColor Gray
Write-Host "    - Prometheus: http://prometheus.localhost" -ForegroundColor Gray
Write-Host ""
Write-Host "  Alternativa con port-forward:" -ForegroundColor White
Write-Host "    kubectl port-forward svc/grafana 3000:3000" -ForegroundColor Gray
Write-Host "    kubectl port-forward svc/prometheus 9090:9090" -ForegroundColor Gray
Write-Host ""

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "[10/10] Configuracion del archivo hosts" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Para acceder a Grafana y Prometheus por nombre, agrega estas lineas" -ForegroundColor Yellow
Write-Host "al archivo hosts de Windows:" -ForegroundColor Yellow
Write-Host ""
Write-Host "127.0.0.1 grafana.localhost" -ForegroundColor White
Write-Host "127.0.0.1 prometheus.localhost" -ForegroundColor White
Write-Host ""
Write-Host "Ubicacion del archivo:" -ForegroundColor Yellow
Write-Host "  C:\Windows\System32\drivers\etc\hosts" -ForegroundColor Gray
Write-Host ""
Write-Host "Editalo como Administrador con:" -ForegroundColor Yellow
Write-Host "  notepad C:\Windows\System32\drivers\etc\hosts" -ForegroundColor Gray
Write-Host ""
Write-Host "O ejecuta este comando como Administrador:" -ForegroundColor Yellow
Write-Host ""
$hostsCommand = @"
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value `"
127.0.0.1 grafana.localhost
127.0.0.1 prometheus.localhost`"
"@
Write-Host $hostsCommand -ForegroundColor Gray
Write-Host ""

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Despliegue completado exitosamente!" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Proximos pasos:" -ForegroundColor Yellow
Write-Host "  1. Configurar archivo hosts (ver arriba)" -ForegroundColor White
Write-Host "  2. Acceder a la aplicacion en http://localhost" -ForegroundColor White
Write-Host "  3. Acceder a Grafana en http://grafana.localhost" -ForegroundColor White
Write-Host "  4. Ejecutar script de verificacion:" -ForegroundColor White
Write-Host "     .\scripts\verify-monitoring.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "Para mas informacion:" -ForegroundColor Yellow
Write-Host "  - Guia de K3D: K3D-DEPLOYMENT.md" -ForegroundColor White
Write-Host "  - Guia de telemetria: MONITORING.md" -ForegroundColor White
Write-Host "  - Guia Windows: WINDOWS-GUIDE.md" -ForegroundColor White
Write-Host ""
