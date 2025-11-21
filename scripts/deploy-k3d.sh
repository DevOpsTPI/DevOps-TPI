#!/bin/bash
# Script de despliegue automático para K3D

set -e  # Salir si hay errores

echo "================================================"
echo "🚀 Despliegue Automático en K3D"
echo "================================================"
echo ""

CLUSTER_NAME="todo-app"

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verificar dependencias
echo "🔍 Verificando dependencias..."
if ! command_exists k3d; then
    echo "❌ k3d no está instalado. Instálalo con:"
    echo "   wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
    exit 1
fi

if ! command_exists kubectl; then
    echo "❌ kubectl no está instalado."
    exit 1
fi

if ! command_exists docker; then
    echo "❌ Docker no está instalado."
    exit 1
fi

echo "✅ Todas las dependencias están instaladas"
echo ""

# Verificar si el cluster ya existe
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "⚠️  El cluster '$CLUSTER_NAME' ya existe."
    read -p "¿Deseas eliminarlo y crear uno nuevo? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Eliminando cluster existente..."
        k3d cluster delete $CLUSTER_NAME
    else
        echo "ℹ️  Usando cluster existente"
    fi
fi

# Crear cluster si no existe
if ! k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "🏗️  Creando cluster K3D '$CLUSTER_NAME'..."
    k3d cluster create $CLUSTER_NAME \
        --api-port 6550 \
        --port "80:80@loadbalancer" \
        --port "443:443@loadbalancer" \
        --agents 1 \
        --agents-memory 2g

    echo "✅ Cluster creado exitosamente"
else
    echo "✅ Usando cluster existente"
fi

echo ""
echo "⏳ Esperando a que el cluster esté listo..."
kubectl wait --for=condition=Ready nodes --all --timeout=60s

echo ""
echo "================================================"
echo "🐳 Construyendo e importando imágenes"
echo "================================================"

# Construir imágenes
echo ""
echo "📦 Construyendo imagen de la API..."
docker build -t api:latest ./api

echo ""
echo "📦 Construyendo imagen del Web..."
docker build -t web:latest ./web

# Importar imágenes al cluster
echo ""
echo "📥 Importando imágenes al cluster K3D..."
k3d image import api:latest -c $CLUSTER_NAME
k3d image import web:latest -c $CLUSTER_NAME

echo "✅ Imágenes importadas exitosamente"

echo ""
echo "================================================"
echo "🚀 Desplegando aplicación"
echo "================================================"

# Desplegar Redis
echo ""
echo "📊 Desplegando Redis..."
kubectl apply -f deploy/redis-deployment.yaml
kubectl apply -f deploy/redis-service.yaml

# Desplegar API
echo ""
echo "🔧 Desplegando API..."
kubectl apply -f deploy/api-deployment.yaml
kubectl apply -f deploy/api-service.yaml

# Desplegar Web
echo ""
echo "🌐 Desplegando Web..."
kubectl apply -f deploy/web-deployment.yaml
kubectl apply -f deploy/web-service.yaml

# Desplegar Ingress
echo ""
echo "🔀 Desplegando Ingress..."
kubectl apply -f deploy/ingress.yaml

echo ""
echo "⏳ Esperando a que los pods de la aplicación estén listos..."
kubectl wait --for=condition=Ready pods -l app=redis --timeout=120s
kubectl wait --for=condition=Ready pods -l app=api --timeout=120s
kubectl wait --for=condition=Ready pods -l app=web --timeout=120s

echo "✅ Aplicación desplegada exitosamente"

echo ""
echo "================================================"
echo "📊 Desplegando sistema de telemetría"
echo "================================================"

# Desplegar RBAC de Prometheus
echo ""
echo "🔐 Desplegando RBAC de Prometheus..."
kubectl apply -f deploy/prometheus-rbac.yaml

# Desplegar ConfigMap de Prometheus
echo ""
echo "⚙️  Desplegando configuración de Prometheus..."
kubectl apply -f deploy/prometheus-config.yaml

# Desplegar Prometheus
echo ""
echo "📈 Desplegando Prometheus..."
kubectl apply -f deploy/prometheus-deployment.yaml

# Desplegar Grafana
echo ""
echo "📊 Desplegando Grafana..."
kubectl apply -f deploy/grafana-deployment.yaml

# Desplegar Exporters (versión K3D sin cAdvisor standalone)
echo ""
echo "🔌 Desplegando exporters..."
kubectl apply -f deploy/exporters-deployment-k3d.yaml

# Desplegar Ingress de monitoreo
echo ""
echo "🔀 Desplegando Ingress de monitoreo..."
kubectl apply -f deploy/monitoring-ingress.yaml

echo ""
echo "⏳ Esperando a que los pods de telemetría estén listos..."
kubectl wait --for=condition=Ready pods -l app=prometheus --timeout=120s 2>/dev/null || echo "⚠️  Prometheus aún no está listo, continuando..."
kubectl wait --for=condition=Ready pods -l app=grafana --timeout=120s 2>/dev/null || echo "⚠️  Grafana aún no está listo, continuando..."
kubectl wait --for=condition=Ready pods -l tier=monitoring --timeout=120s 2>/dev/null || echo "⚠️  Algunos exporters aún no están listos, continuando..."

echo "✅ Sistema de telemetría desplegado"

echo ""
echo "================================================"
echo "✅ Despliegue completo"
echo "================================================"
echo ""

# Mostrar estado
echo "📋 Estado de los pods:"
kubectl get pods

echo ""
echo "🌐 URLs de acceso:"
echo ""
echo "  Aplicación:"
echo "    - Web:       http://localhost"
echo "    - API:       http://localhost/api"
echo ""
echo "  Telemetría (configura /etc/hosts primero):"
echo "    - Grafana:   http://grafana.localhost (admin/admin)"
echo "    - Prometheus: http://prometheus.localhost"
echo ""
echo "  Alternativa con port-forward:"
echo "    kubectl port-forward svc/grafana 3000:3000"
echo "    kubectl port-forward svc/prometheus 9090:9090"
echo ""

echo "================================================"
echo "🔧 Configuración de /etc/hosts"
echo "================================================"
echo ""
echo "Agrega estas líneas a tu archivo /etc/hosts:"
echo ""
echo "127.0.0.1 grafana.localhost"
echo "127.0.0.1 prometheus.localhost"
echo ""
echo "Linux/Mac:"
echo "  sudo nano /etc/hosts"
echo ""
echo "Windows:"
echo "  notepad C:\Windows\System32\drivers\etc\hosts"
echo ""

echo "================================================"
echo "✨ ¡Despliegue completado!"
echo "================================================"
echo ""
echo "📝 Próximos pasos:"
echo "  1. Configurar /etc/hosts (ver arriba)"
echo "  2. Acceder a la aplicación en http://localhost"
echo "  3. Acceder a Grafana en http://grafana.localhost"
echo "  4. Ejecutar script de verificación:"
echo "     ./scripts/verify-monitoring.sh"
echo ""
echo "📖 Para más información:"
echo "  - Guía de K3D: K3D-DEPLOYMENT.md"
echo "  - Guía de telemetría: MONITORING.md"
echo ""
