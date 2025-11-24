#!/bin/bash

# Script para desplegar Prometheus y Grafana en k3d
# Ejecutar desde la raíz del proyecto

set -e

# Colores
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Desplegando Stack de Monitoreo (Prometheus + Grafana)${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Verificar que kubectl está disponible
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}ERROR: kubectl no está instalado o no está en el PATH${NC}"
    exit 1
fi

# Verificar que el cluster está corriendo
echo -e "${YELLOW}[1/7] Verificando cluster k3d...${NC}"
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}ERROR: No se puede conectar al cluster. Asegúrate de que k3d está corriendo.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Cluster activo${NC}"
echo ""

# Desplegar Prometheus
echo -e "${YELLOW}[2/7] Desplegando Prometheus...${NC}"
kubectl apply -f deploy/prometheus-configmap.yaml
kubectl apply -f deploy/prometheus-rbac.yaml
kubectl apply -f deploy/prometheus-deployment.yaml
echo -e "${GREEN}✓ Prometheus desplegado${NC}"
echo ""

# Desplegar kube-state-metrics
echo -e "${YELLOW}[3/7] Desplegando kube-state-metrics...${NC}"
kubectl apply -f deploy/kube-state-metrics.yaml
echo -e "${GREEN}✓ kube-state-metrics desplegado${NC}"
echo ""

# Actualizar deployments con exporters
echo -e "${YELLOW}[4/7] Actualizando deployments con exporters (Web y Redis)...${NC}"
kubectl apply -f deploy/web-deployment.yaml
kubectl apply -f deploy/redis-statefulset.yaml
echo -e "${GREEN}✓ Exporters desplegados (nginx-exporter, redis-exporter)${NC}"
echo ""

# Desplegar Grafana
echo -e "${YELLOW}[5/7] Desplegando Grafana...${NC}"
kubectl apply -f deploy/grafana-configmap.yaml
kubectl apply -f deploy/grafana-deployment.yaml
echo -e "${GREEN}✓ Grafana desplegado${NC}"
echo ""

# Actualizar Ingress
echo -e "${YELLOW}[6/7] Actualizando Ingress para exponer Grafana y Prometheus...${NC}"
kubectl apply -f deploy/ingress.yaml
echo -e "${GREEN}✓ Ingress actualizado${NC}"
echo ""

# Esperar a que todos los pods estén ready
echo -e "${YELLOW}[7/7] Esperando a que todos los pods estén listos...${NC}"
echo -e "${GRAY}Esperando Prometheus...${NC}"
kubectl wait --for=condition=ready pod -l app=prometheus --timeout=120s 2>/dev/null || echo -e "${YELLOW}ADVERTENCIA: Prometheus tardó más de lo esperado${NC}"

echo -e "${GRAY}Esperando kube-state-metrics...${NC}"
kubectl wait --for=condition=ready pod -l app=kube-state-metrics --timeout=120s 2>/dev/null || echo -e "${YELLOW}ADVERTENCIA: kube-state-metrics tardó más de lo esperado${NC}"

echo -e "${GRAY}Esperando Grafana...${NC}"
kubectl wait --for=condition=ready pod -l app=grafana --timeout=120s 2>/dev/null || echo -e "${YELLOW}ADVERTENCIA: Grafana tardó más de lo esperado${NC}"

echo -e "${GRAY}Esperando Web (con nginx-exporter)...${NC}"
kubectl wait --for=condition=ready pod -l app=web --timeout=120s 2>/dev/null

echo -e "${GRAY}Esperando Redis (con redis-exporter)...${NC}"
kubectl wait --for=condition=ready pod -l app=redis --timeout=120s 2>/dev/null

echo -e "${GREEN}✓ Todos los componentes están listos${NC}"
echo ""

# Mostrar estado de los pods
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Estado de Pods de Monitoreo${NC}"
echo -e "${CYAN}================================================${NC}"
kubectl get pods -l 'app in (prometheus,grafana,kube-state-metrics)'
echo ""

# Mostrar URLs de acceso
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  URLs de Acceso${NC}"
echo -e "${CYAN}================================================${NC}"
echo -e "${WHITE}Aplicación Web:  http://localhost/${NC}"
echo -e "${WHITE}API:             http://localhost/api${NC}"
echo -e "${GREEN}Grafana:         http://localhost/grafana${NC}"
echo -e "${GRAY}                 Usuario: admin / Password: admin${NC}"
echo -e "${GREEN}Prometheus:      http://localhost/prometheus${NC}"
echo ""
echo -e "${CYAN}Dashboard: 'To-Do App - Monitoreo Completo' (preconfigurado)${NC}"
echo ""

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Métricas Disponibles${NC}"
echo -e "${CYAN}================================================${NC}"
echo -e "${WHITE}1. Estado de réplicas (activo/inactivo) por servicio/nodo${NC}"
echo -e "${WHITE}2. CPU consumido (%) por servicio/réplica/nodo${NC}"
echo -e "${WHITE}3. RAM consumida (%) por servicio/réplica/nodo${NC}"
echo -e "${WHITE}4. Gráficos de CPU por servicio/réplica/nodo${NC}"
echo -e "${WHITE}5. Gráficos de RAM por servicio/réplica/nodo${NC}"
echo -e "${WHITE}6. Cantidad de tareas existentes${NC}"
echo -e "${WHITE}7. Peticiones realizadas a la API (req/s)${NC}"
echo ""

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Despliegue Completado Exitosamente!${NC}"
echo -e "${GREEN}================================================${NC}"
