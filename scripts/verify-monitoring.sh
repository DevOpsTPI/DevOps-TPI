#!/bin/bash
# Script de verificación del sistema de telemetría

echo "================================================"
echo "🔍 Verificación del Sistema de Telemetría"
echo "================================================"
echo ""

# Detectar entorno (Docker Compose o Kubernetes)
if command -v kubectl &> /dev/null && kubectl get pods &> /dev/null; then
    ENVIRONMENT="kubernetes"
    echo "📦 Entorno detectado: Kubernetes"
else
    ENVIRONMENT="docker-compose"
    echo "🐳 Entorno detectado: Docker Compose"
fi

echo ""
echo "================================================"
echo "1️⃣  Verificando servicios..."
echo "================================================"

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    echo ""
    echo "📊 Pods de telemetría:"
    kubectl get pods -l tier=monitoring

    echo ""
    echo "🔌 Servicios de telemetría:"
    kubectl get svc -l tier=monitoring

    echo ""
    echo "🌐 Ingress de monitoreo:"
    kubectl get ingress monitoring-ingress

else
    echo ""
    echo "🐳 Contenedores de telemetría:"
    docker-compose ps prometheus grafana redis-exporter nginx-exporter cadvisor
fi

echo ""
echo "================================================"
echo "2️⃣  Verificando conectividad..."
echo "================================================"

# Función para verificar endpoint
check_endpoint() {
    local url=$1
    local name=$2

    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|302"; then
        echo "✅ $name está accesible en $url"
        return 0
    else
        echo "❌ $name NO está accesible en $url"
        return 1
    fi
}

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    # Kubernetes URLs
    echo ""
    echo "⏳ Esperando 5 segundos para que los servicios estén listos..."
    sleep 5

    echo ""
    check_endpoint "http://prometheus.localhost" "Prometheus"
    check_endpoint "http://grafana.localhost" "Grafana"

    # Port-forward para verificar desde dentro del cluster
    echo ""
    echo "🔌 Verificando servicios internos del cluster..."
    kubectl port-forward svc/prometheus 9090:9090 &>/dev/null &
    PF_PROM_PID=$!
    sleep 2
    check_endpoint "http://localhost:9090/-/healthy" "Prometheus (interno)"
    kill $PF_PROM_PID 2>/dev/null

    kubectl port-forward svc/grafana 3000:3000 &>/dev/null &
    PF_GRAF_PID=$!
    sleep 2
    check_endpoint "http://localhost:3000/api/health" "Grafana (interno)"
    kill $PF_GRAF_PID 2>/dev/null

else
    # Docker Compose URLs
    check_endpoint "http://localhost:9090/-/healthy" "Prometheus"
    check_endpoint "http://localhost:3000/api/health" "Grafana"
    check_endpoint "http://localhost:8081" "cAdvisor"
fi

echo ""
echo "================================================"
echo "3️⃣  Verificando targets de Prometheus..."
echo "================================================"

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kubectl port-forward svc/prometheus 9090:9090 &>/dev/null &
    PF_PID=$!
    sleep 3
fi

echo ""
echo "📡 Consultando targets de Prometheus..."
TARGETS=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "$TARGETS" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    active_targets = data.get('data', {}).get('activeTargets', [])

    if not active_targets:
        print('⚠️  No se encontraron targets configurados')
        sys.exit(1)

    print(f'📊 Total de targets: {len(active_targets)}')
    print('')

    jobs = {}
    for target in active_targets:
        job = target.get('labels', {}).get('job', 'unknown')
        health = target.get('health', 'unknown')

        if job not in jobs:
            jobs[job] = {'up': 0, 'down': 0}

        if health == 'up':
            jobs[job]['up'] += 1
        else:
            jobs[job]['down'] += 1

    for job, counts in jobs.items():
        status = '✅' if counts['down'] == 0 else '❌'
        print(f'{status} Job: {job:20s} - UP: {counts[\"up\"]:2d}, DOWN: {counts[\"down\"]:2d}')

except Exception as e:
    print(f'❌ Error procesando targets: {e}')
    sys.exit(1)
" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "⚠️  No se pudieron procesar los targets (¿python3 instalado?)"
        echo ""
        echo "Mostrando targets en formato raw:"
        echo "$TARGETS" | grep -o '"job":"[^"]*"' | sort -u
    fi
else
    echo "❌ No se pudo conectar a Prometheus"
fi

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kill $PF_PID 2>/dev/null
fi

echo ""
echo "================================================"
echo "4️⃣  Verificando datasource de Grafana..."
echo "================================================"

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kubectl port-forward svc/grafana 3000:3000 &>/dev/null &
    PF_GRAF_PID=$!
    sleep 3
fi

echo ""
echo "📡 Consultando datasources de Grafana..."
DATASOURCES=$(curl -s -u admin:admin http://localhost:3000/api/datasources 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "$DATASOURCES" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)

    if not data:
        print('⚠️  No se encontraron datasources configurados')
        sys.exit(1)

    print(f'📊 Total de datasources: {len(data)}')
    print('')

    for ds in data:
        name = ds.get('name', 'unknown')
        type_ds = ds.get('type', 'unknown')
        url = ds.get('url', 'unknown')
        is_default = '(default)' if ds.get('isDefault', False) else ''

        print(f'✅ {name:20s} - Type: {type_ds:15s} - URL: {url} {is_default}')

except Exception as e:
    print(f'❌ Error procesando datasources: {e}')
    sys.exit(1)
" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "⚠️  No se pudieron procesar los datasources"
    fi
else
    echo "❌ No se pudo conectar a Grafana (credenciales: admin/admin)"
fi

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kill $PF_GRAF_PID 2>/dev/null
fi

echo ""
echo "================================================"
echo "5️⃣  Verificando endpoint /metrics de la API..."
echo "================================================"

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    echo ""
    echo "🔌 Haciendo port-forward del servicio API..."
    kubectl port-forward svc/api 8000:8000 &>/dev/null &
    PF_API_PID=$!
    sleep 3
    API_URL="http://localhost:8000"
else
    API_URL="http://localhost:8000"
fi

echo ""
check_endpoint "$API_URL/metrics" "API /metrics endpoint"

echo ""
echo "📊 Muestreando algunas métricas de la API:"
METRICS=$(curl -s "$API_URL/metrics" 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "$METRICS" | grep -E "^(http_requests_total|tasks_created_total|tasks_current|http_request_duration_seconds_count)" | head -5

    if [ $? -eq 0 ]; then
        echo "✅ Métricas de la API están siendo exportadas correctamente"
    else
        echo "⚠️  No se encontraron métricas esperadas en el endpoint"
    fi
else
    echo "❌ No se pudo obtener métricas de la API"
fi

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kill $PF_API_PID 2>/dev/null
fi

echo ""
echo "================================================"
echo "6️⃣  Test de conectividad Prometheus → API"
echo "================================================"

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kubectl port-forward svc/prometheus 9090:9090 &>/dev/null &
    PF_PROM_PID=$!
    sleep 3
fi

echo ""
echo "🔍 Consultando métricas de la API desde Prometheus..."

QUERY_RESULT=$(curl -s "http://localhost:9090/api/v1/query?query=up{job=\"api\"}" 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "$QUERY_RESULT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    results = data.get('data', {}).get('result', [])

    if not results:
        print('⚠️  Prometheus no está recibiendo métricas del job \"api\"')
        print('   Esto puede significar que:')
        print('   - La API no ha sido scrapeada aún (espera 10-15 segundos)')
        print('   - Hay un problema de conectividad en la red monitoring-network')
        sys.exit(1)

    for result in results:
        metric = result.get('metric', {})
        value = result.get('value', [None, None])[1]
        instance = metric.get('instance', 'unknown')

        status = '✅' if value == '1' else '❌'
        status_text = 'UP' if value == '1' else 'DOWN'
        print(f'{status} API instance {instance}: {status_text}')

except Exception as e:
    print(f'❌ Error procesando query: {e}')
    sys.exit(1)
" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "⚠️  No se pudieron procesar los resultados"
    fi
else
    echo "❌ No se pudo consultar Prometheus"
fi

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kill $PF_PROM_PID 2>/dev/null
fi

echo ""
echo "================================================"
echo "✅ Verificación completa"
echo "================================================"
echo ""

if [ "$ENVIRONMENT" = "kubernetes" ]; then
    echo "📝 URLs de acceso (configura /etc/hosts):"
    echo "   - Grafana: http://grafana.localhost (admin/admin)"
    echo "   - Prometheus: http://prometheus.localhost"
    echo ""
    echo "💡 Para acceso directo (alternativa):"
    echo "   kubectl port-forward svc/grafana 3000:3000"
    echo "   kubectl port-forward svc/prometheus 9090:9090"
else
    echo "📝 URLs de acceso:"
    echo "   - Grafana: http://localhost:3000 (admin/admin)"
    echo "   - Prometheus: http://localhost:9090"
    echo "   - cAdvisor: http://localhost:8081"
fi

echo ""
echo "================================================"
