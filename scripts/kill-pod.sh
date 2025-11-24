#!/bin/bash
# Script para matar un pod de la aplicación (API, Web o Redis)
# Simula un crash matando el proceso principal (PID 1)

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}==================================================${NC}"
echo -e "${CYAN}  Script para Matar Pods - Demo Auto-Recuperación${NC}"
echo -e "${CYAN}==================================================${NC}"
echo ""

# Menú de selección
echo -e "${YELLOW}Selecciona el tipo de pod a matar:${NC}"
echo -e "${GREEN}1) API${NC}"
echo -e "${GREEN}2) WEB${NC}"
echo -e "${GREEN}3) Redis${NC}"
echo -e "${RED}4) Salir${NC}"
echo ""

read -p "Ingresa tu opción (1-4): " option

app=""
case $option in
    1) app="api" ;;
    2) app="web" ;;
    3) app="redis" ;;
    4)
        echo -e "${YELLOW}Saliendo...${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Opción inválida${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${CYAN}==================================================${NC}"
echo -e "${CYAN}  Obteniendo pods de: $app${NC}"
echo -e "${CYAN}==================================================${NC}"
echo ""

# Obtener pods
pods=$(kubectl get pods -l app=$app -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$pods" ]; then
    echo -e "${RED}ERROR: No se encontraron pods para app=$app${NC}"
    echo -e "${YELLOW}Verifica que el cluster esté corriendo y los pods estén desplegados${NC}"
    exit 1
fi

# Convertir a array
podArray=($pods)

# Mostrar pods disponibles
echo -e "${YELLOW}Pods disponibles:${NC}"
for i in "${!podArray[@]}"; do
    status=$(kubectl get pod ${podArray[$i]} -o jsonpath='{.status.phase}' 2>/dev/null)
    echo -e "${GREEN}$((i + 1))) ${podArray[$i]} - Status: $status${NC}"
done
echo ""

# Seleccionar pod
read -p "Selecciona el número del pod a matar (1-${#podArray[@]}): " podIndex
podIndexNum=$((podIndex - 1))

if [ $podIndexNum -lt 0 ] || [ $podIndexNum -ge ${#podArray[@]} ]; then
    echo -e "${RED}ERROR: Selección inválida${NC}"
    exit 1
fi

selectedPod=${podArray[$podIndexNum]}

echo ""
echo -e "${CYAN}==================================================${NC}"
echo -e "${RED}  Matando pod: $selectedPod${NC}"
echo -e "${CYAN}==================================================${NC}"
echo ""

# Confirmar acción
read -p "¿Estás seguro de matar el pod '$selectedPod'? (s/n): " confirm
if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
    echo -e "${YELLOW}Operación cancelada${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}Iniciando monitoreo en segundo plano...${NC}"
echo -e "${YELLOW}Abre otra terminal y ejecuta: kubectl get pods -l app=$app --watch${NC}"
echo ""

# Mostrar estado antes
echo -e "${CYAN}Estado ANTES de matar el pod:${NC}"
kubectl get pods -l app=$app -o wide

echo ""
echo -e "${RED}Ejecutando: kubectl exec $selectedPod -- kill 1${NC}"
echo ""

# Ejecutar kill
kubectl exec $selectedPod -- kill 1 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Comando ejecutado exitosamente${NC}"
    echo -e "${YELLOW}El pod debería reiniciarse automáticamente en unos segundos...${NC}"
else
    echo -e "${YELLOW}El pod probablemente se está reiniciando (esto es esperado)${NC}"
fi

echo ""
echo -e "${CYAN}Esperando 3 segundos...${NC}"
sleep 3

echo ""
echo -e "${CYAN}Estado DESPUÉS de matar el pod:${NC}"
kubectl get pods -l app=$app -o wide

echo ""
echo -e "${CYAN}==================================================${NC}"
echo -e "${CYAN}  Monitoreo de Eventos${NC}"
echo -e "${CYAN}==================================================${NC}"
echo ""
echo -e "${YELLOW}Últimos eventos del pod:${NC}"
kubectl get events --field-selector involvedObject.name=$selectedPod --sort-by='.lastTimestamp' | tail -n 10

echo ""
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}  Demo Completada${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
echo -e "${YELLOW}Tips:${NC}"
echo -e "- Revisa Grafana para ver las métricas de disponibilidad"
echo -e "- Ejecuta 'kubectl get pods -l app=$app --watch' para ver la recuperación en tiempo real"
echo -e "- Verifica los reinicios: kubectl get pods -l app=$app"
echo ""
