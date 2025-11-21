#!/bin/bash
# Script de prueba de conectividad Prometheus ↔ Grafana

echo "================================================"
echo "🔗 Test de Conectividad Prometheus ↔ Grafana"
echo "================================================"
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detectar entorno
if command -v kubectl &> /dev/null && kubectl get pods &> /dev/null 2>&1; then
    ENVIRONMENT="kubernetes"
    echo "📦 Entorno: Kubernetes/K3D"
else
    ENVIRONMENT="docker-compose"
    echo "🐳 Entorno: Docker Compose"
fi

echo ""

# Test 1: Verificar que Prometheus está corriendo
echo "================================================"
echo "Test 1: Prometheus está corriendo?"
echo "================================================"

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    PROM_POD=$(kubectl get pods -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$PROM_POD" ]; then
        PROM_STATUS=$(kubectl get pod $PROM_POD -o jsonpath='{.status.phase}')
        if [ "$PROM_STATUS" = "Running" ]; then
            echo -e "${GREEN}✅ Prometheus está corriendo${NC}"
        else
            echo -e "${RED}❌ Prometheus NO está corriendo (status: $PROM_STATUS)${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ No se encontró pod de Prometheus${NC}"
        exit 1
    fi
else
    if docker ps | grep -q prometheus; then
        echo -e "${GREEN}✅ Prometheus está corriendo${NC}"
    else
        echo -e "${RED}❌ Prometheus NO está corriendo${NC}"
        exit 1
    fi
fi

# Test 2: Verificar que Grafana está corriendo
echo ""
echo "================================================"
echo "Test 2: Grafana está corriendo?"
echo "================================================"

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    GRAF_POD=$(kubectl get pods -l app=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$GRAF_POD" ]; then
        GRAF_STATUS=$(kubectl get pod $GRAF_POD -o jsonpath='{.status.phase}')
        if [ "$GRAF_STATUS" = "Running" ]; then
            echo -e "${GREEN}✅ Grafana está corriendo${NC}"
        else
            echo -e "${RED}❌ Grafana NO está corriendo (status: $GRAF_STATUS)${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ No se encontró pod de Grafana${NC}"
        exit 1
    fi
else
    if docker ps | grep -q grafana; then
        echo -e "${GREEN}✅ Grafana está corriendo${NC}"
    else
        echo -e "${RED}❌ Grafana NO está corriendo${NC}"
        exit 1
    fi
fi

# Test 3: Prometheus puede acceder a la API
echo ""
echo "================================================"
echo "Test 3: Prometheus → API (métricas de la API)"
echo "================================================"

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kubectl port-forward svc/prometheus 9090:9090 &>/dev/null &
    PF_PROM_PID=$!
    sleep 3
fi

API_METRICS=$(curl -s "http://localhost:9090/api/v1/query?query=up{job=\"api\"}" 2>/dev/null | grep -o '"value":\[[^]]*\]' | grep -o ',"[01]"' | grep -o '[01]')

if [ "$API_METRICS" = "1" ]; then
    echo -e "${GREEN}✅ Prometheus puede scrapear métricas de la API${NC}"
else
    echo -e "${RED}❌ Prometheus NO puede scrapear métricas de la API${NC}"
    echo -e "${YELLOW}   Esto puede significar:${NC}"
    echo "   - La API no está exponiendo métricas en /metrics"
    echo "   - Prometheus no puede alcanzar la API (problema de red)"
    echo "   - El job 'api' no está configurado correctamente"
fi

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kill $PF_PROM_PID 2>/dev/null
fi

# Test 4: Grafana puede conectarse a Prometheus
echo ""
echo "================================================"
echo "Test 4: Grafana → Prometheus (datasource)"
echo "================================================"

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kubectl port-forward svc/grafana 3000:3000 &>/dev/null &
    PF_GRAF_PID=$!
    sleep 3
fi

# Verificar datasource de Grafana
DATASOURCE_STATUS=$(curl -s -u admin:admin "http://localhost:3000/api/datasources" 2>/dev/null | grep -o '"type":"prometheus"')

if [ -n "$DATASOURCE_STATUS" ]; then
    echo -e "${GREEN}✅ Grafana tiene datasource de Prometheus configurado${NC}"

    # Probar query desde Grafana
    echo ""
    echo "Probando query desde Grafana..."

    QUERY_RESULT=$(curl -s -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{"queries":[{"refId":"A","expr":"up","datasourceId":1}]}' \
        "http://localhost:3000/api/ds/query" 2>/dev/null)

    if echo "$QUERY_RESULT" | grep -q '"status":"success"'; then
        echo -e "${GREEN}✅ Grafana puede ejecutar queries en Prometheus${NC}"
    else
        echo -e "${YELLOW}⚠️  Grafana puede tener problemas ejecutando queries${NC}"
        echo "   Verifica manualmente en Grafana → Explore"
    fi
else
    echo -e "${RED}❌ Grafana NO tiene datasource de Prometheus configurado${NC}"
    echo -e "${YELLOW}   Solución:${NC}"
    echo "   1. Abrir Grafana → Configuration → Data Sources"
    echo "   2. Agregar Prometheus con URL: http://prometheus:9090"
fi

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kill $PF_GRAF_PID 2>/dev/null
fi

# Test 5: Endpoint /metrics de la API responde
echo ""
echo "================================================"
echo "Test 5: API → /metrics endpoint"
echo "================================================"

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kubectl port-forward svc/api 8000:8000 &>/dev/null &
    PF_API_PID=$!
    sleep 3
    API_URL="http://localhost:8000"
else
    API_URL="http://localhost:8000"
fi

METRICS_RESPONSE=$(curl -s "$API_URL/metrics" 2>/dev/null | head -1)

if echo "$METRICS_RESPONSE" | grep -q "HELP\|TYPE"; then
    echo -e "${GREEN}✅ Endpoint /metrics responde correctamente${NC}"

    # Contar métricas
    METRIC_COUNT=$(curl -s "$API_URL/metrics" 2>/dev/null | grep -c "^# TYPE")
    echo "   📊 Métricas disponibles: $METRIC_COUNT"

    # Verificar métricas específicas
    echo ""
    echo "   Verificando métricas específicas:"

    if curl -s "$API_URL/metrics" 2>/dev/null | grep -q "http_requests_total"; then
        echo -e "   ${GREEN}✅ http_requests_total${NC}"
    else
        echo -e "   ${RED}❌ http_requests_total${NC}"
    fi

    if curl -s "$API_URL/metrics" 2>/dev/null | grep -q "tasks_created_total"; then
        echo -e "   ${GREEN}✅ tasks_created_total${NC}"
    else
        echo -e "   ${RED}❌ tasks_created_total${NC}"
    fi

    if curl -s "$API_URL/metrics" 2>/dev/null | grep -q "tasks_current"; then
        echo -e "   ${GREEN}✅ tasks_current${NC}"
    else
        echo -e "   ${RED}❌ tasks_current${NC}"
    fi
else
    echo -e "${RED}❌ Endpoint /metrics NO responde correctamente${NC}"
    echo -e "${YELLOW}   Solución:${NC}"
    echo "   - Verificar que la API está corriendo"
    echo "   - Verificar que prometheus-client está instalado"
    echo "   - Reconstruir la imagen de la API"
fi

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kill $PF_API_PID 2>/dev/null
fi

# Test 6: Verificar todos los targets de Prometheus
echo ""
echo "================================================"
echo "Test 6: Todos los targets de Prometheus"
echo "================================================"

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kubectl port-forward svc/prometheus 9090:9090 &>/dev/null &
    PF_PROM_PID=$!
    sleep 3
fi

echo ""
echo "Consultando targets de Prometheus..."

TARGETS_JSON=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "$TARGETS_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    targets = data.get('data', {}).get('activeTargets', [])

    jobs = {}
    for target in targets:
        job = target.get('labels', {}).get('job', 'unknown')
        health = target.get('health', 'unknown')

        if job not in jobs:
            jobs[job] = {'up': 0, 'down': 0}

        if health == 'up':
            jobs[job]['up'] += 1
        else:
            jobs[job]['down'] += 1

    all_up = True
    for job, counts in jobs.items():
        if counts['down'] > 0:
            all_up = False
            print(f'❌ {job:25s} - UP: {counts[\"up\"]:2d}, DOWN: {counts[\"down\"]:2d}')
        else:
            print(f'✅ {job:25s} - UP: {counts[\"up\"]:2d}')

    if all_up:
        print('')
        print('🎉 Todos los targets están UP!')
    else:
        print('')
        print('⚠️  Algunos targets están DOWN. Revisa la configuración de Prometheus.')

except Exception as e:
    print(f'Error procesando targets: {e}')
" 2>/dev/null
else
    echo -e "${RED}❌ No se pudo consultar targets de Prometheus${NC}"
fi

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kill $PF_PROM_PID 2>/dev/null
fi

# Resumen final
echo ""
echo "================================================"
echo "📋 Resumen de Conectividad"
echo "================================================"
echo ""

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    echo "🌐 URLs de acceso (K3D):"
    echo "   - Grafana: http://grafana.localhost (o port-forward al 3000)"
    echo "   - Prometheus: http://prometheus.localhost (o port-forward al 9090)"
    echo ""
    echo "💡 Port-forward commands:"
    echo "   kubectl port-forward svc/grafana 3000:3000"
    echo "   kubectl port-forward svc/prometheus 9090:9090"
else
    echo "🌐 URLs de acceso (Docker Compose):"
    echo "   - Grafana: http://localhost:3000"
    echo "   - Prometheus: http://localhost:9090"
fi

echo ""
echo "📖 Próximos pasos:"
echo "   1. Abrir Grafana y verificar el datasource"
echo "   2. Ver el dashboard 'Todo App - Métricas Completas'"
echo "   3. Generar tráfico en la aplicación para ver métricas"
echo ""
echo "================================================"
