# 📊 Sistema de Telemetría - Todo App

## Descripción General

Este proyecto integra un sistema completo de telemetría usando **Prometheus** y **Grafana** para monitorear el uso de recursos y el rendimiento de la aplicación en tiempo real.

### Características Principales

✅ **Red Separada para Telemetría**: Los servicios de monitoreo utilizan una red aislada (`monitoring-network`) para evitar interferencia con el tráfico de usuarios
✅ **Métricas de Aplicación**: Seguimiento de peticiones HTTP, latencia, tareas creadas/completadas/eliminadas
✅ **Métricas de Infraestructura**: CPU, memoria, red y disco de cada contenedor/pod
✅ **Métricas de Servicios**: Redis (conexiones, keys), Nginx (peticiones, conexiones activas)
✅ **Dashboard Personalizado**: Visualización completa en Grafana con paneles específicos para la aplicación

---

## 📋 Tabla de Contenidos

- [Arquitectura](#arquitectura)
- [Componentes](#componentes)
- [Métricas Disponibles](#métricas-disponibles)
- [Despliegue con Docker Compose](#despliegue-con-docker-compose)
- [Despliegue en Kubernetes](#despliegue-en-kubernetes)
- [Acceso a las Interfaces](#acceso-a-las-interfaces)
- [Configuración Avanzada](#configuración-avanzada)

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                    Red de Aplicación                        │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐         │
│  │   Web    │◄────►│   API    │◄────►│  Redis   │         │
│  │ (Nginx)  │      │ (FastAPI)│      │          │         │
│  └────┬─────┘      └────┬─────┘      └────┬─────┘         │
└───────┼─────────────────┼─────────────────┼───────────────┘
        │                 │                 │
        │                 │                 │
┌───────┼─────────────────┼─────────────────┼───────────────┐
│       │   Red de Telemetría (AISLADA)    │               │
│       ▼                 ▼                 ▼               │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐           │
│  │  Nginx   │    │   API    │    │  Redis   │           │
│  │ Exporter │    │ /metrics │    │ Exporter │           │
│  └────┬─────┘    └────┬─────┘    └────┬─────┘           │
│       │               │               │                   │
│       └───────────────┼───────────────┘                   │
│                       ▼                                    │
│              ┌─────────────────┐                          │
│              │   Prometheus    │◄──┐                      │
│              │ (Recolección)   │   │                      │
│              └────────┬────────┘   │                      │
│                       │             │                      │
│                       ▼        ┌────┴──────┐              │
│              ┌─────────────┐  │ cAdvisor  │              │
│              │   Grafana   │  │(CPU, RAM, │              │
│              │(Visualiza-  │  │ Red, Disk)│              │
│              │    ción)    │  └───────────┘              │
│              └─────────────┘                              │
└───────────────────────────────────────────────────────────┘
```

### Separación de Redes

**¿Por qué dos redes?**

1. **`app-network` (172.20.0.0/16)**: Comunicación entre servicios de la aplicación (web, api, redis)
2. **`monitoring-network` (172.21.0.0/16)**: Exclusiva para telemetría, evita que las herramientas de monitoreo distorsionen las métricas de uso

Los servicios de aplicación (web, api, redis) están conectados a **ambas redes** para permitir:
- Comunicación de aplicación en `app-network`
- Exposición de métricas en `monitoring-network`

Los servicios de telemetría (Prometheus, Grafana, exporters, cAdvisor) **solo** están en `monitoring-network`.

---

## 🛠️ Componentes

### 1. Prometheus
- **Puerto**: 9090
- **Función**: Recolecta y almacena métricas de todos los servicios
- **Scrape Interval**: 10-15 segundos
- **Storage**: Volumen persistente para histórico de métricas

### 2. Grafana
- **Puerto**: 3000
- **Función**: Visualización de métricas con dashboards interactivos
- **Credenciales por defecto**:
  - Usuario: `admin`
  - Contraseña: `admin`
- **Datasource**: Prometheus (preconfigurado)

### 3. Redis Exporter
- **Puerto**: 9121
- **Función**: Exporta métricas de Redis (conexiones, keys, comandos, memoria)

### 4. Nginx Prometheus Exporter
- **Puerto**: 9113
- **Función**: Exporta métricas de Nginx (peticiones, conexiones activas, aceptadas, manejadas)

### 5. cAdvisor
- **Puerto**: 8080 (8081 en Docker Compose)
- **Función**: Métricas de recursos de contenedores (CPU, memoria, red, I/O de disco)

---

## 📈 Métricas Disponibles

### Métricas de la API (FastAPI)

| Métrica | Tipo | Descripción |
|---------|------|-------------|
| `http_requests_total` | Counter | Total de peticiones HTTP por método, endpoint y status |
| `http_request_duration_seconds` | Histogram | Latencia de peticiones HTTP (p50, p95, p99) |
| `tasks_created_total` | Counter | Total de tareas creadas |
| `tasks_completed_total` | Counter | Total de tareas marcadas como completadas |
| `tasks_deleted_total` | Counter | Total de tareas eliminadas |
| `tasks_current` | Gauge | Número actual de tareas en el sistema |
| `tasks_pending` | Gauge | Número de tareas pendientes (no completadas) |

### Métricas de Nginx (Web)

| Métrica | Tipo | Descripción |
|---------|------|-------------|
| `nginx_http_requests_total` | Counter | Total de peticiones HTTP procesadas |
| `nginx_connections_active` | Gauge | Conexiones activas actuales |
| `nginx_connections_accepted` | Counter | Conexiones aceptadas |
| `nginx_connections_handled` | Counter | Conexiones manejadas con éxito |

### Métricas de Redis

| Métrica | Tipo | Descripción |
|---------|------|-------------|
| `redis_connected_clients` | Gauge | Número de clientes conectados |
| `redis_db_keys` | Gauge | Número de keys en la base de datos |
| `redis_memory_used_bytes` | Gauge | Memoria usada por Redis |
| `redis_commands_processed_total` | Counter | Total de comandos procesados |

### Métricas de Contenedores (cAdvisor)

| Métrica | Tipo | Descripción |
|---------|------|-------------|
| `container_cpu_usage_seconds_total` | Counter | Uso acumulado de CPU |
| `container_memory_usage_bytes` | Gauge | Uso actual de memoria |
| `container_network_receive_bytes_total` | Counter | Bytes recibidos por red |
| `container_network_transmit_bytes_total` | Counter | Bytes transmitidos por red |
| `container_fs_reads_bytes_total` | Counter | Bytes leídos de disco |
| `container_fs_writes_bytes_total` | Counter | Bytes escritos a disco |

---

## 🚀 Despliegue con Docker Compose

### Requisitos Previos

- Docker y Docker Compose instalados
- Archivo `.env` configurado (copiar de `.env.example`)

### Pasos de Despliegue

1. **Levantar todos los servicios** (aplicación + telemetría):

```bash
docker-compose up -d
```

2. **Verificar que todos los contenedores están corriendo**:

```bash
docker-compose ps
```

Deberías ver 9 contenedores:
- `redis` - Base de datos
- `fastapi` - API Backend
- `web` - Frontend Nginx
- `prometheus` - Recolector de métricas
- `grafana` - Visualización
- `redis-exporter` - Exporter de Redis
- `nginx-exporter` - Exporter de Nginx
- `cadvisor` - Métricas de contenedores

3. **Ver logs de telemetría**:

```bash
# Logs de Prometheus
docker-compose logs -f prometheus

# Logs de Grafana
docker-compose logs -f grafana
```

### Reconstruir con Nuevas Métricas

Si modificas el código de la API para agregar nuevas métricas:

```bash
docker-compose up -d --build api
```

---

## ☸️ Despliegue en Kubernetes

### ⚡ Despliegue Rápido en K3D

**Para K3D/K3S**, usa el script de despliegue automático:

```bash
# Despliegue completo (aplicación + telemetría)
chmod +x scripts/deploy-k3d.sh
./scripts/deploy-k3d.sh

# Verificación
chmod +x scripts/verify-monitoring.sh
./scripts/verify-monitoring.sh
```

**Documentación completa de K3D:** Ver [K3D-DEPLOYMENT.md](K3D-DEPLOYMENT.md) y [QUICKSTART-K3D.md](QUICKSTART-K3D.md)

---

### Requisitos Previos (Despliegue Manual)

- Cluster de Kubernetes (k3d, minikube, o producción)
- `kubectl` configurado
- Traefik como Ingress Controller

**Para K3D:** El cluster debe crearse con puerto 80 expuesto:
```bash
k3d cluster create todo-app \
  --api-port 6550 \
  --port "80:80@loadbalancer" \
  --agents 1
```

### Pasos de Despliegue

1. **Desplegar la aplicación principal** (si no está ya desplegada):

```bash
kubectl apply -f deploy/redis-deployment.yaml
kubectl apply -f deploy/redis-service.yaml
kubectl apply -f deploy/api-deployment.yaml
kubectl apply -f deploy/api-service.yaml
kubectl apply -f deploy/web-deployment.yaml
kubectl apply -f deploy/web-service.yaml
kubectl apply -f deploy/ingress.yaml
```

2. **Desplegar el sistema de telemetría**:

```bash
# RBAC para Prometheus (necesario para service discovery)
kubectl apply -f deploy/prometheus-rbac.yaml

# ConfigMap de Prometheus
kubectl apply -f deploy/prometheus-config.yaml

# Prometheus
kubectl apply -f deploy/prometheus-deployment.yaml

# Grafana con datasources y dashboards
kubectl apply -f deploy/grafana-deployment.yaml

# Exporters (usar versión K3D si estás en K3D/K3S)
# Para K3D/K3S (sin cAdvisor standalone):
kubectl apply -f deploy/exporters-deployment-k3d.yaml

# Para otros Kubernetes (con cAdvisor standalone):
# kubectl apply -f deploy/exporters-deployment.yaml

# Ingress para acceso a Grafana y Prometheus
kubectl apply -f deploy/monitoring-ingress.yaml
```

**Nota K3D/K3S:** K3S tiene cAdvisor integrado en kubelet, por eso usamos `exporters-deployment-k3d.yaml` que no incluye un DaemonSet de cAdvisor separado.

3. **Verificar el despliegue**:

```bash
# Ver todos los pods
kubectl get pods

# Ver servicios
kubectl get svc

# Ver ingress
kubectl get ingress
```

4. **Verificar logs**:

```bash
# Logs de Prometheus
kubectl logs -l app=prometheus -f

# Logs de Grafana
kubectl logs -l app=grafana -f
```

### Actualizar Configuración de Prometheus

Si necesitas modificar la configuración de Prometheus:

```bash
# Editar el ConfigMap
kubectl edit configmap prometheus-config

# Reiniciar Prometheus para aplicar cambios
kubectl rollout restart deployment prometheus
```

---

## 🌐 Acceso a las Interfaces

### Docker Compose

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **Aplicación Web** | http://localhost:8080 | - |
| **API** | http://localhost:8000 | - |
| **Grafana** | http://localhost:3000 | admin / admin |
| **Prometheus** | http://localhost:9090 | - |
| **cAdvisor** | http://localhost:8081 | - |

### Kubernetes (Local con k3d)

Primero, configura tu archivo `/etc/hosts` (Linux/Mac) o `C:\Windows\System32\drivers\etc\hosts` (Windows):

```
127.0.0.1 localhost
127.0.0.1 grafana.localhost
127.0.0.1 prometheus.localhost
```

Luego accede:

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **Aplicación Web** | http://localhost | - |
| **API** | http://localhost/api | - |
| **Grafana** | http://grafana.localhost | admin / admin |
| **Prometheus** | http://prometheus.localhost | - |

---

## 📊 Usando el Dashboard de Grafana

### Acceso Inicial

1. Abre http://localhost:3000 (Docker Compose) o http://grafana.localhost (K8s)
2. Login con `admin` / `admin`
3. Cambia la contraseña (opcional pero recomendado)

### Dashboard Preconfigurado

El dashboard **"Todo App - Métricas Completas"** está preinstalado y contiene:

#### Sección 1: Métricas de la API
- **Peticiones HTTP por segundo**: Rate de peticiones por endpoint y método
- **Total de Peticiones HTTP**: Gauge con el total acumulado
- **Latencia de Peticiones**: Percentiles p50 y p95 de latencia

#### Sección 2: Métricas de Negocio
- **Estado de Tareas**: Gráfico de tareas totales vs pendientes
- **Tareas Creadas**: Contador total
- **Tareas Completadas**: Contador total
- **Tareas Eliminadas**: Contador total

#### Sección 3: Métricas de Infraestructura
- **Uso de CPU por Contenedor**: Porcentaje de uso de CPU de cada servicio
- **Uso de Memoria por Contenedor**: Bytes de memoria usados
- **Tráfico de Red**: RX/TX por contenedor

#### Sección 4: Métricas de Servicios
- **Métricas de Redis**: Clientes conectados, número de keys
- **Métricas de Nginx**: Peticiones totales, conexiones activas

### Crear Dashboards Personalizados

1. Click en **"+"** → **"Dashboard"**
2. Click en **"Add new panel"**
3. En la query, selecciona **Prometheus** como datasource
4. Escribe tu query PromQL, por ejemplo:
   ```promql
   rate(http_requests_total{job="api"}[5m])
   ```
5. Personaliza la visualización (gráfico de líneas, gauge, stat, etc.)
6. Click en **"Apply"** y **"Save dashboard"**

### Queries PromQL Útiles

**Tasa de peticiones por segundo:**
```promql
rate(http_requests_total{job="api"}[1m])
```

**Latencia p95 de la API:**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="api"}[5m]))
```

**Uso de CPU por contenedor:**
```promql
rate(container_cpu_usage_seconds_total{name=~"fastapi|web|redis"}[5m]) * 100
```

**Uso de memoria en MB:**
```promql
container_memory_usage_bytes{name=~"fastapi|web|redis"} / 1024 / 1024
```

**Número de tareas pendientes:**
```promql
tasks_pending
```

**Tasa de creación de tareas:**
```promql
rate(tasks_created_total[5m])
```

---

## 🔍 Explorando Prometheus

### Acceso a la Interfaz

- Docker Compose: http://localhost:9090
- Kubernetes: http://prometheus.localhost

### Verificar Targets

1. Ve a **Status** → **Targets**
2. Verifica que todos los jobs estén en estado **UP**:
   - `api` - Métricas de FastAPI
   - `web-nginx` - Métricas de Nginx
   - `redis` - Métricas de Redis
   - `cadvisor` - Métricas de contenedores
   - `prometheus` - Métricas propias de Prometheus

### Ejecutar Queries

1. Ve a **Graph**
2. Escribe una query, ejemplo: `http_requests_total`
3. Click en **Execute**
4. Cambia entre vista de tabla y gráfico

### Alertas (Configuración Avanzada)

Prometheus puede configurarse para enviar alertas. Ejemplo de regla de alerta:

```yaml
# monitoring/prometheus/alerts.yml
groups:
  - name: api_alerts
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Alta tasa de errores 5xx en la API"
          description: "La API está retornando más de 5% de errores 5xx"
```

---

## ⚙️ Configuración Avanzada

### Ajustar Intervalo de Scrape

Edita `monitoring/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 10s  # Cambiar a 5s para mayor frecuencia
  evaluation_interval: 10s
```

Reinicia Prometheus:

```bash
# Docker Compose
docker-compose restart prometheus

# Kubernetes
kubectl rollout restart deployment prometheus
```

### Agregar Nuevas Métricas en la API

1. Abre [api/main.py](api/main.py)
2. Define una nueva métrica después de las existentes:

```python
from prometheus_client import Counter

# Nueva métrica
api_errors_total = Counter(
    'api_errors_total',
    'Total de errores en la API',
    ['endpoint', 'error_type']
)
```

3. Úsala en tu código:

```python
@app.get("/example")
def example():
    try:
        # tu lógica
        pass
    except Exception as e:
        api_errors_total.labels(endpoint="/example", error_type=type(e).__name__).inc()
        raise
```

4. Reconstruye y redeploy:

```bash
docker-compose up -d --build api
```

### Persistencia de Datos

**Docker Compose**: Los datos se guardan en volúmenes Docker (`prometheus-data`, `grafana-data`)

**Kubernetes**: Por defecto usa `emptyDir` (se pierde al reiniciar el pod). Para producción, usa PersistentVolumeClaims:

```yaml
# En prometheus-deployment.yaml
volumes:
  - name: prometheus-storage
    persistentVolumeClaim:
      claimName: prometheus-pvc
```

### Configurar Retención de Datos

Por defecto, Prometheus retiene datos por 15 días. Para cambiar:

```yaml
# En prometheus-deployment.yaml
args:
  - '--storage.tsdb.retention.time=30d'  # 30 días
  - '--storage.tsdb.retention.size=10GB'  # O limitar por tamaño
```

---

## 🔐 Seguridad en Producción

### Proteger Grafana

1. **Cambiar contraseña de admin** inmediatamente
2. **Deshabilitar registro de usuarios** (ya configurado):
   ```yaml
   - GF_USERS_ALLOW_SIGN_UP=false
   ```
3. **Usar autenticación externa** (OAuth, LDAP):
   ```yaml
   - GF_AUTH_GOOGLE_ENABLED=true
   - GF_AUTH_GOOGLE_CLIENT_ID=xxx
   - GF_AUTH_GOOGLE_CLIENT_SECRET=xxx
   ```

### Proteger Prometheus

1. **No exponerlo públicamente** (mantener en red interna)
2. **Usar autenticación básica** con nginx/traefik como proxy
3. **Limitar acceso por IP** en el Ingress

### Network Policies en Kubernetes

Limita el acceso a los servicios de telemetría:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: monitoring-access
spec:
  podSelector:
    matchLabels:
      tier: monitoring
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: monitoring
    - podSelector:
        matchLabels:
          app: api
    - podSelector:
        matchLabels:
          app: web
```

---

## 🐛 Troubleshooting

### Prometheus no recolecta métricas de la API

**Problema**: Target `api` aparece como "DOWN" en Prometheus

**Solución**:
1. Verifica que el endpoint `/metrics` responde:
   ```bash
   curl http://localhost:8000/metrics
   ```
2. Revisa logs de Prometheus:
   ```bash
   docker-compose logs prometheus
   ```
3. Verifica que la API esté en la red `monitoring-network`

### Grafana no muestra datos

**Problema**: Los paneles muestran "No data"

**Solución**:
1. Verifica la conexión a Prometheus:
   - Grafana → Configuration → Data Sources → Prometheus
   - Click en "Test" - debe decir "Data source is working"
2. Verifica el rango de tiempo (arriba a la derecha)
3. Ejecuta queries manualmente en Prometheus para verificar que hay datos

### cAdvisor no funciona en Windows

**Problema**: cAdvisor falla al iniciar en Windows con Docker Desktop

**Solución**:
- cAdvisor tiene soporte limitado en Windows
- En Docker Desktop para Windows, considera usar solo las métricas de la aplicación
- Alternativamente, usa WSL2 con Docker dentro de Linux

### Nginx Exporter no puede acceder a nginx_status

**Problema**: `nginx-exporter` muestra error "connection refused"

**Solución**:
1. Verifica que nginx tiene stub_status habilitado:
   ```bash
   docker exec web curl http://localhost/nginx_status
   ```
2. Si falla, revisa que [web/nginx.conf](web/nginx.conf) está copiado correctamente
3. Reconstruye el contenedor web:
   ```bash
   docker-compose up -d --build web
   ```

### Métricas de réplicas en Kubernetes

**Problema**: En K8s con múltiples réplicas de la API, las métricas son inconsistentes

**Solución**:
- Esto es esperado: cada réplica tiene sus propias métricas
- Usa agregaciones en PromQL:
  ```promql
  sum(rate(http_requests_total[5m])) by (endpoint)
  ```

---

## 📚 Referencias

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Python Client](https://github.com/prometheus/client_python)
- [Redis Exporter](https://github.com/oliver006/redis_exporter)
- [Nginx Prometheus Exporter](https://github.com/nginxinc/nginx-prometheus-exporter)
- [cAdvisor](https://github.com/google/cadvisor)

---

## 🎯 Próximos Pasos

1. **Alertas**: Configurar Alertmanager para notificaciones (email, Slack, PagerDuty)
2. **Logs Centralizados**: Integrar ELK Stack o Loki para logs
3. **Tracing Distribuido**: Agregar Jaeger o Tempo para trazas de peticiones
4. **SLOs/SLIs**: Definir objetivos de nivel de servicio basados en las métricas

---

**¡El sistema de telemetría está listo para usar!** 🚀

Para cualquier pregunta o problema, consulta la sección de Troubleshooting o abre un issue en el repositorio.
