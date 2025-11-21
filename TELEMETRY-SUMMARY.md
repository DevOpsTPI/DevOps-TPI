# 📊 Resumen de Implementación de Telemetría

## ✅ Implementación Completa

Se ha implementado un **sistema de telemetría completo** usando **Prometheus + Grafana** para tu aplicación Todo App, con soporte para **Docker Compose** y **Kubernetes (K3D/K3S)**.

---

## 🎯 Características Implementadas

### ✅ 1. Red Separada para Telemetría
- **Docker Compose**: Dos redes separadas (`app-network` y `monitoring-network`)
- **Kubernetes**: Namespace separado con NetworkPolicies (opcional)
- Los servicios de aplicación están en ambas redes
- Los servicios de monitoreo solo están en `monitoring-network`
- **Resultado**: La telemetría NO distorsiona las métricas de la aplicación

### ✅ 2. Métricas de la Aplicación (FastAPI)
Integradas directamente en [api/main.py](api/main.py):
- `http_requests_total` - Total de peticiones HTTP
- `http_request_duration_seconds` - Latencia de peticiones (histograma)
- `tasks_created_total` - Tareas creadas
- `tasks_completed_total` - Tareas completadas
- `tasks_deleted_total` - Tareas eliminadas
- `tasks_current` - Número actual de tareas
- `tasks_pending` - Tareas pendientes

**Endpoint**: `/metrics` (http://localhost:8000/metrics)

### ✅ 3. Métricas de Infraestructura

#### Por Réplica (CPU, Memoria, Red, Disco)
- **Docker Compose**: cAdvisor standalone
- **K3D/K3S**: cAdvisor integrado en kubelet
- **Métricas**: CPU, memoria, red (RX/TX), I/O de disco
- **Por contenedor/pod**: Puedes ver métricas individuales de cada réplica

#### Redis
- Redis Exporter
- Métricas: conexiones, keys, memoria, comandos procesados

#### Nginx (Web)
- Nginx Prometheus Exporter
- Métricas: peticiones totales, conexiones activas, aceptadas

### ✅ 4. Dashboard de Grafana Personalizado
- Dashboard preconstruido: **"Todo App - Métricas Completas"**
- 12+ paneles con visualizaciones:
  - Peticiones HTTP y latencia
  - Métricas de negocio (tareas)
  - Uso de recursos (CPU, memoria, red)
  - Métricas de servicios (Redis, Nginx)

### ✅ 5. Configuración Optimizada para K3D/K3S
- Service discovery automático de pods
- RBAC configurado para Prometheus
- Acceso a cAdvisor integrado de K3S
- Configuración específica sin DaemonSet de cAdvisor

---

## 📁 Archivos Creados/Modificados

### Código de la Aplicación
- ✅ [api/main.py](api/main.py) - Integración de prometheus_client
- ✅ [api/requirements.txt](api/requirements.txt) - Agregado prometheus-client
- ✅ [web/nginx.conf](web/nginx.conf) - Habilitado stub_status
- ✅ [web/Dockerfile](web/Dockerfile) - Configuración de Nginx

### Docker Compose
- ✅ [compose.yml](compose.yml) - Servicios de telemetría y redes separadas
- ✅ [monitoring/prometheus/prometheus.yml](monitoring/prometheus/prometheus.yml) - Configuración de Prometheus
- ✅ [monitoring/grafana/datasources/prometheus.yml](monitoring/grafana/datasources/prometheus.yml) - Datasource
- ✅ [monitoring/grafana/dashboards/dashboard.yml](monitoring/grafana/dashboards/dashboard.yml) - Configuración de dashboards
- ✅ [monitoring/grafana/dashboards/todo-app-dashboard.json](monitoring/grafana/dashboards/todo-app-dashboard.json) - Dashboard personalizado

### Kubernetes
- ✅ [deploy/prometheus-rbac.yaml](deploy/prometheus-rbac.yaml) - ServiceAccount y permisos
- ✅ [deploy/prometheus-config.yaml](deploy/prometheus-config.yaml) - ConfigMap con configuración K3S
- ✅ [deploy/prometheus-deployment.yaml](deploy/prometheus-deployment.yaml) - Deployment y Service
- ✅ [deploy/grafana-deployment.yaml](deploy/grafana-deployment.yaml) - Deployment, Service y ConfigMaps
- ✅ [deploy/exporters-deployment-k3d.yaml](deploy/exporters-deployment-k3d.yaml) - Exporters optimizado para K3D
- ✅ [deploy/exporters-deployment.yaml](deploy/exporters-deployment.yaml) - Exporters para otros Kubernetes
- ✅ [deploy/monitoring-ingress.yaml](deploy/monitoring-ingress.yaml) - Ingress para Grafana y Prometheus

### Scripts
- ✅ [scripts/deploy-k3d.sh](scripts/deploy-k3d.sh) - Despliegue automático en K3D
- ✅ [scripts/verify-monitoring.sh](scripts/verify-monitoring.sh) - Verificación completa del sistema
- ✅ [scripts/test-connectivity.sh](scripts/test-connectivity.sh) - Test de conectividad específico

### Documentación
- ✅ [MONITORING.md](MONITORING.md) - Guía completa de telemetría
- ✅ [K3D-DEPLOYMENT.md](K3D-DEPLOYMENT.md) - Guía detallada para K3D
- ✅ [QUICKSTART-K3D.md](QUICKSTART-K3D.md) - Quick start de 5 minutos
- ✅ [TELEMETRY-SUMMARY.md](TELEMETRY-SUMMARY.md) - Este archivo

---

## 🚀 Cómo Usar

### Opción 1: Docker Compose

```bash
# Levantar todo (aplicación + telemetría)
docker-compose up -d

# Verificar
./scripts/verify-monitoring.sh

# Acceder
# - Aplicación: http://localhost:8080
# - Grafana: http://localhost:3000 (admin/admin)
# - Prometheus: http://localhost:9090
```

### Opción 2: K3D (Recomendado)

```bash
# Despliegue automático
chmod +x scripts/deploy-k3d.sh
./scripts/deploy-k3d.sh

# Verificar
chmod +x scripts/verify-monitoring.sh
./scripts/verify-monitoring.sh

# Acceder (después de configurar /etc/hosts)
# - Aplicación: http://localhost
# - Grafana: http://grafana.localhost (admin/admin)
# - Prometheus: http://prometheus.localhost
```

---

## 🔍 Verificación de Prometheus ↔ Grafana

### Método 1: Script Automático

```bash
chmod +x scripts/test-connectivity.sh
./scripts/test-connectivity.sh
```

Este script verifica:
- ✅ Prometheus está corriendo
- ✅ Grafana está corriendo
- ✅ Prometheus puede scrapear métricas de la API
- ✅ Grafana puede conectarse a Prometheus
- ✅ Endpoint /metrics de la API responde
- ✅ Todos los targets de Prometheus están UP

### Método 2: Verificación Manual

#### 1. Verificar que Prometheus puede acceder a la API

**K3D:**
```bash
kubectl port-forward svc/prometheus 9090:9090
```

**Docker Compose:** (ya accesible en 9090)

Luego:
```bash
# Abrir navegador: http://localhost:9090/targets
# Verificar que el job "api" está UP
```

O con curl:
```bash
curl -s http://localhost:9090/api/v1/targets | grep '"job":"api"' -A 5
```

#### 2. Verificar que Grafana puede conectarse a Prometheus

**K3D:**
```bash
kubectl port-forward svc/grafana 3000:3000
```

**Docker Compose:** (ya accesible en 3000)

Luego:
1. Abrir http://localhost:3000
2. Login: admin / admin
3. Configuration → Data Sources → Prometheus
4. Click en "Test"
5. Debe decir: **"Data source is working"** ✅

#### 3. Verificar métricas en el dashboard

1. Dashboards → "Todo App - Métricas Completas"
2. Deberías ver datos en los paneles (si hay tráfico)
3. Si no hay datos, genera tráfico:

```bash
# Crear algunas tareas
for i in {1..10}; do
  curl -X POST "http://localhost/api/tasks?text=Task_$i"
done

# Listar tareas
curl http://localhost/api/tasks
```

Espera 10-15 segundos y refresca Grafana.

---

## 📊 Métricas que Verás

### En Prometheus (http://localhost:9090)

Prueba estas queries:

**Tasa de peticiones por segundo:**
```promql
rate(http_requests_total{job="api"}[1m])
```

**Latencia p95:**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="api"}[5m]))
```

**Número de tareas actuales:**
```promql
tasks_current
```

**Uso de CPU (K3S):**
```promql
rate(container_cpu_usage_seconds_total{pod=~"api-.*|web-.*|redis-.*"}[5m]) * 100
```

**Uso de memoria (K3S):**
```promql
container_memory_usage_bytes{pod=~"api-.*|web-.*|redis-.*"} / 1024 / 1024
```

### En Grafana (http://localhost:3000)

El dashboard incluye:
- 📈 **Peticiones HTTP**: Por segundo, por endpoint
- ⏱️ **Latencia**: p50, p95, p99
- ✅ **Tareas**: Creadas, completadas, eliminadas, pendientes
- 💻 **CPU**: Por contenedor/pod, por réplica
- 💾 **Memoria**: Uso actual por servicio
- 🌐 **Red**: RX/TX por contenedor
- 🔴 **Redis**: Conexiones, keys
- 🟢 **Nginx**: Peticiones, conexiones activas

---

## 🎯 Características Específicas de K3D/K3S

### 1. cAdvisor Integrado
- K3S tiene cAdvisor **integrado en kubelet**
- NO necesitas desplegar un DaemonSet de cAdvisor separado
- Prometheus accede vía: `/api/v1/nodes/{node}/proxy/metrics/cadvisor`

### 2. Service Discovery Automático
- Prometheus usa Kubernetes API para descubrir pods
- Detecta automáticamente las 2 réplicas de API y Web
- RBAC configurado para permisos de lectura

### 3. Métricas por Réplica
- Cada réplica expone sus propias métricas
- Puedes ver métricas individuales o agregadas:

**Individual:**
```promql
http_requests_total{pod="api-xxxxx-xxxxx"}
```

**Agregada:**
```promql
sum(rate(http_requests_total[1m])) by (endpoint)
```

### 4. Networking
- Los pods se comunican por DNS interno (prometheus, grafana, api, etc.)
- No necesitas IPs específicas
- Ingress configura el acceso externo

---

## 🐛 Troubleshooting Común

### Prometheus no muestra targets UP

**Problema:** Job `api` aparece como DOWN.

**Verificar:**
```bash
# K3D
kubectl logs -l app=prometheus | grep api

# Docker Compose
docker logs prometheus | grep api
```

**Soluciones:**
1. Verificar que el pod/contenedor de API está corriendo
2. Verificar que el endpoint /metrics responde:
   ```bash
   kubectl port-forward svc/api 8000:8000
   curl http://localhost:8000/metrics
   ```
3. En K3D, verificar RBAC:
   ```bash
   kubectl get serviceaccount prometheus
   kubectl get clusterrolebinding prometheus
   ```

### Grafana no muestra datos

**Problema:** Paneles muestran "No data".

**Verificar:**
1. Datasource conectado:
   - Grafana → Configuration → Data Sources → Test
2. Rango de tiempo correcto (arriba a la derecha)
3. Prometheus tiene datos:
   - Abrir Prometheus → Graph
   - Ejecutar query: `up`
   - Debe mostrar targets

**Solución:**
```bash
# Reiniciar Grafana
kubectl rollout restart deployment grafana  # K3D
docker-compose restart grafana              # Docker Compose
```

### Métricas de CPU/Memoria vacías en K3D

**Problema:** Paneles de recursos no muestran datos.

**Causa:** Queries del dashboard usan labels de Docker, no Kubernetes.

**Solución:** Editar queries en Grafana:

**Antes:**
```promql
container_memory_usage_bytes{name="fastapi"}
```

**Después:**
```promql
container_memory_usage_bytes{pod=~"api-.*", container!=""}
```

O usar:
```promql
container_memory_usage_bytes{container="api"}
```

---

## 📚 Documentación

| Documento | Descripción |
|-----------|-------------|
| [MONITORING.md](MONITORING.md) | Guía completa de telemetría (arquitectura, métricas, configuración) |
| [K3D-DEPLOYMENT.md](K3D-DEPLOYMENT.md) | Guía paso a paso para K3D/K3S |
| [QUICKSTART-K3D.md](QUICKSTART-K3D.md) | Quick start de 5 minutos para K3D |
| [TELEMETRY-SUMMARY.md](TELEMETRY-SUMMARY.md) | Este resumen |

---

## ✅ Checklist de Verificación

Usa esta checklist para verificar que todo funciona:

### Docker Compose
- [ ] Contenedores corriendo: `docker-compose ps`
- [ ] Prometheus accesible: http://localhost:9090
- [ ] Grafana accesible: http://localhost:3000
- [ ] API /metrics: http://localhost:8000/metrics
- [ ] Prometheus targets UP: http://localhost:9090/targets
- [ ] Grafana datasource: OK (Test button)
- [ ] Dashboard muestra datos

### K3D
- [ ] Cluster creado: `k3d cluster list`
- [ ] Imágenes importadas: `k3d image list -c todo-app`
- [ ] Pods corriendo: `kubectl get pods`
- [ ] RBAC aplicado: `kubectl get serviceaccount prometheus`
- [ ] Prometheus targets UP (port-forward)
- [ ] Grafana datasource OK (port-forward)
- [ ] Dashboard muestra datos
- [ ] Ingress funciona: http://grafana.localhost

---

## 🎉 ¡Listo para Usar!

Tu sistema de telemetría está completamente configurado y listo para:

1. **Monitorear** el rendimiento de tu aplicación en tiempo real
2. **Observar** el uso de recursos por réplica
3. **Detectar** cuellos de botella y problemas de performance
4. **Visualizar** métricas de negocio (tareas creadas, completadas, etc.)
5. **Escalar** basándote en datos reales de uso

---

## 📞 Soporte

Si tienes problemas:

1. Ejecuta los scripts de verificación:
   ```bash
   ./scripts/verify-monitoring.sh
   ./scripts/test-connectivity.sh
   ```

2. Revisa los logs:
   ```bash
   # K3D
   kubectl logs -l app=prometheus
   kubectl logs -l app=grafana
   kubectl logs -l app=api

   # Docker Compose
   docker-compose logs prometheus
   docker-compose logs grafana
   docker-compose logs api
   ```

3. Consulta la documentación:
   - [MONITORING.md](MONITORING.md) - Sección Troubleshooting
   - [K3D-DEPLOYMENT.md](K3D-DEPLOYMENT.md) - Sección Troubleshooting K3D Específico

---

**¡Disfruta de tu sistema de telemetría!** 🚀📊
