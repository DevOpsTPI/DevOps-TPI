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
    echo "🏗️  Creando cluster K3D '$CLUSTER_NAME' con 4 nodos..."
    echo "   - Nodo maestro (server-0): 512 MB RAM, 1 CPU - Control Plane"
    echo "   - Nodo agente 0 (agent-0): 512 MB RAM, 1 CPU - Aplicacion"
    echo "   - Nodo agente 1 (agent-1): 512 MB RAM, 1 CPU - Aplicacion"
    echo "   - Nodo agente 2 (agent-2): 512 MB RAM, 1 CPU - Aplicacion"

    k3d cluster create $CLUSTER_NAME \
        --api-port 6550 \
        --port "80:80@loadbalancer" \
        --port "443:443@loadbalancer" \
        --agents 3 \
        --servers-memory 512m \
        --agents-memory 512m \
        --k3s-arg "--kubelet-arg=cpu-manager-policy=none@server:*" \
        --k3s-arg "--kubelet-arg=cpu-manager-policy=none@agent:*"

    # Aplicar limites de CPU a nivel de contenedor Docker
    echo ""
    echo "⚙️  Aplicando limites de CPU y RAM a los nodos..."
    docker update --cpus="1.0" --memory="512m" "k3d-$CLUSTER_NAME-server-0"
    docker update --cpus="1.0" --memory="512m" "k3d-$CLUSTER_NAME-agent-0"
    docker update --cpus="1.0" --memory="512m" "k3d-$CLUSTER_NAME-agent-1"
    docker update --cpus="1.0" --memory="512m" "k3d-$CLUSTER_NAME-agent-2"

    echo "✅ Limites de recursos aplicados a todos los nodos"
    echo "✅ Cluster creado exitosamente"
else
    echo "✅ Usando cluster existente"
fi

echo ""
echo "⏳ Esperando a que el cluster esté listo..."
kubectl wait --for=condition=Ready nodes --all --timeout=60s

echo ""
echo "================================================"
echo "🏷️  Configurando nodos (labels y taints)"
echo "================================================"
echo ""

# Aplicar taint al nodo maestro
echo "⚙️  Aplicando taint al nodo maestro (no scheduling de apps)..."
kubectl taint nodes k3d-$CLUSTER_NAME-server-0 node-role.kubernetes.io/control-plane=true:NoSchedule --overwrite 2>/dev/null
echo "✅ Taint aplicado al nodo maestro"

# Etiquetar nodos agentes
echo ""
echo "🏷️  Etiquetando nodos agentes..."
kubectl label nodes k3d-$CLUSTER_NAME-agent-0 node-type=application --overwrite 2>/dev/null
echo "✅ Nodo agent-0 etiquetado como 'application'"

kubectl label nodes k3d-$CLUSTER_NAME-agent-1 node-type=application --overwrite 2>/dev/null
echo "✅ Nodo agent-1 etiquetado como 'application'"

kubectl label nodes k3d-$CLUSTER_NAME-agent-2 node-type=application --overwrite 2>/dev/null
echo "✅ Nodo agent-2 etiquetado como 'application'"

echo ""
echo "📋 Verificando configuración de nodos:"
kubectl get nodes -L node-type --show-labels=false

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

# Desplegar Redis primero (sin Sentinel)
echo ""
echo "📊 Desplegando Redis..."
kubectl apply -f deploy/redis-configmap.yaml
kubectl apply -f deploy/redis-statefulset.yaml
kubectl apply -f deploy/redis-service.yaml

echo ""
echo "⏳ Esperando a que Redis esté listo..."
kubectl wait --for=condition=Ready pods -l app=redis --timeout=120s

# Ahora desplegar Sentinel
echo ""
echo "📊 Desplegando Redis Sentinel..."
kubectl apply -f deploy/redis-sentinel-statefulset.yaml
kubectl apply -f deploy/redis-sentinel-service.yaml

echo ""
echo "⏳ Esperando a que Sentinel esté listo..."
kubectl wait --for=condition=Ready pods -l app=redis-sentinel --timeout=120s

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

echo "================================================"
echo "✨ ¡Despliegue completado!"
echo "================================================"
echo ""
echo "📝 Próximos pasos:"
echo "  1. Acceder a la aplicación en http://localhost"
echo "  2. Probar la API en http://localhost/api"
echo ""
echo "📖 Para más información:"
echo "  - Guía de K3D: K3D-DEPLOYMENT.md"
echo ""
