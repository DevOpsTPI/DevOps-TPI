# 📊 Sistema de Telemetría - Todo App

## 🎯 Resumen Ejecutivo

Este proyecto incluye un **sistema completo de telemetría** usando **Prometheus + Grafana** para monitorear:

- ✅ **Peticiones HTTP** (tasa, latencia, códigos de estado)
- ✅ **Métricas de negocio** (tareas creadas, completadas, eliminadas)
- ✅ **Recursos de hardware** (CPU, memoria, red, disco) **por réplica**
- ✅ **Servicios** (Redis, Nginx)

### Red Separada ✨
La telemetría usa una **red dedicada** (`monitoring-network`) aislada del tráfico de usuarios para **NO distorsionar las métricas**.

### Soporte Completo 🚀
- ✅ **Docker Compose** - Para desarrollo local
- ✅ **Kubernetes (K3D/K3S)** - Para simular entorno productivo

---

## 📖 Documentación

| Documento | Para quién | Contenido |
|-----------|------------|-----------|
| **[QUICKSTART-K3D.md](QUICKSTART-K3D.md)** | Quieres empezar rápido | Guía de 5 minutos con comandos copy-paste |
| **[K3D-DEPLOYMENT.md](K3D-DEPLOYMENT.md)** | Usas K3D/K3S | Guía detallada paso a paso para K3D |
| **[MONITORING.md](MONITORING.md)** | Quieres documentación completa | Arquitectura, métricas, queries, troubleshooting |
| **[TELEMETRY-SUMMARY.md](TELEMETRY-SUMMARY.md)** | Necesitas un resumen | Resumen de implementación y verificación |

---

## ⚡ Quick Start

### 1️⃣ K3D (Recomendado)

```bash
# Despliegue automático (aplicación + telemetría)
chmod +x scripts/deploy-k3d.sh
./scripts/deploy-k3d.sh

# Configurar /etc/hosts
# Linux/Mac:
sudo nano /etc/hosts
# Windows (como Admin):
notepad C:\Windows\System32\drivers\etc\hosts

# Agregar:
# 127.0.0.1 grafana.localhost
# 127.0.0.1 prometheus.localhost

# Verificar
chmod +x scripts/verify-monitoring.sh
./scripts/verify-monitoring.sh
```

**Acceder:**
- App: http://localhost
- Grafana: http://grafana.localhost (admin/admin)
- Prometheus: http://prometheus.localhost

### 2️⃣ Docker Compose

```bash
# Levantar todo
docker-compose up -d

# Verificar
./scripts/verify-monitoring.sh
```

**Acceder:**
- App: http://localhost:8080
- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090

---

## 🔍 Verificación Rápida

### ✅ Prometheus conectado a Grafana?

```bash
chmod +x scripts/test-connectivity.sh
./scripts/test-connectivity.sh
```

Este script verifica **automáticamente**:
- ✅ Prometheus está corriendo
- ✅ Grafana está corriendo
- ✅ Prometheus → API (scrapea métricas)
- ✅ Grafana → Prometheus (datasource conectado)
- ✅ Todos los targets UP

### ✅ Ver métricas en acción

```bash
# Generar tráfico
for i in {1..20}; do
  curl -X POST "http://localhost/api/tasks?text=Task_$i"
  curl http://localhost/api/tasks > /dev/null
  sleep 0.5
done

# Abrir Grafana y ver el dashboard actualizarse en tiempo real
```

---

## 📊 Dashboard de Grafana

El dashboard **"Todo App - Métricas Completas"** incluye:

### Sección 1: API
- Peticiones HTTP/s (por endpoint, método, status)
- Total de peticiones HTTP
- Latencia (p50, p95)

### Sección 2: Negocio
- Estado de tareas (total vs pendientes)
- Contadores: creadas, completadas, eliminadas

### Sección 3: Infraestructura
- Uso de CPU por contenedor/pod **por réplica**
- Uso de memoria por servicio
- Tráfico de red (RX/TX)

### Sección 4: Servicios
- Redis: clientes conectados, keys
- Nginx: peticiones, conexiones activas

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                Red de Aplicación (app-network)              │
│                                                              │
│    Usuario → Web (Nginx) → API (FastAPI) → Redis           │
│                                                              │
└────────────────────────┬───────────────┬────────────────────┘
                         │               │
                         │               │
┌────────────────────────┼───────────────┼────────────────────┐
│   Red de Telemetría (monitoring-network) - AISLADA         │
│                        │               │                     │
│                        ▼               ▼                     │
│                   Exporters        Métricas                 │
│                (Nginx, Redis)     (API /metrics)            │
│                        │               │                     │
│                        └───────┬───────┘                     │
│                                │                              │
│                                ▼                              │
│                          Prometheus ◄──── cAdvisor           │
│                                │          (CPU, RAM,          │
│                                │           Red, Disco)        │
│                                ▼                              │
│                            Grafana                           │
│                        (Visualización)                       │
│                                                              │
└───────────────────────────────────────────────────────────────┘
```

**Beneficio:** La telemetría NO interfiere con el tráfico de usuarios.

---

## 🎯 Métricas Disponibles

### API (FastAPI)
| Métrica | Tipo | Descripción |
|---------|------|-------------|
| `http_requests_total` | Counter | Peticiones HTTP (por método, endpoint, status) |
| `http_request_duration_seconds` | Histogram | Latencia de peticiones |
| `tasks_created_total` | Counter | Total de tareas creadas |
| `tasks_completed_total` | Counter | Total de tareas completadas |
| `tasks_deleted_total` | Counter | Total de tareas eliminadas |
| `tasks_current` | Gauge | Número actual de tareas |
| `tasks_pending` | Gauge | Tareas pendientes |

### Nginx (Web)
| Métrica | Tipo | Descripción |
|---------|------|-------------|
| `nginx_http_requests_total` | Counter | Total de peticiones HTTP |
| `nginx_connections_active` | Gauge | Conexiones activas |

### Redis
| Métrica | Tipo | Descripción |
|---------|------|-------------|
| `redis_connected_clients` | Gauge | Clientes conectados |
| `redis_db_keys` | Gauge | Número de keys |
| `redis_memory_used_bytes` | Gauge | Memoria usada |

### Infraestructura (cAdvisor)
| Métrica | Tipo | Descripción |
|---------|------|-------------|
| `container_cpu_usage_seconds_total` | Counter | Uso de CPU |
| `container_memory_usage_bytes` | Gauge | Uso de memoria |
| `container_network_receive_bytes_total` | Counter | Bytes recibidos |
| `container_network_transmit_bytes_total` | Counter | Bytes transmitidos |

---

## 🛠️ Scripts Útiles

| Script | Propósito |
|--------|-----------|
| `scripts/deploy-k3d.sh` | Despliegue automático completo en K3D |
| `scripts/verify-monitoring.sh` | Verificación completa del sistema |
| `scripts/test-connectivity.sh` | Test específico de conectividad |

Todos los scripts detectan automáticamente si estás en Docker Compose o Kubernetes.

---

## 🔧 Comandos Útiles

### Ver estado
```bash
# K3D
kubectl get pods
kubectl get svc
kubectl get ingress

# Docker Compose
docker-compose ps
```

### Ver logs
```bash
# K3D
kubectl logs -l app=prometheus -f
kubectl logs -l app=grafana -f
kubectl logs -l app=api -f

# Docker Compose
docker-compose logs prometheus -f
docker-compose logs grafana -f
docker-compose logs api -f
```

### Port-forward (K3D)
```bash
kubectl port-forward svc/grafana 3000:3000
kubectl port-forward svc/prometheus 9090:9090
kubectl port-forward svc/api 8000:8000
```

### Reiniciar servicios
```bash
# K3D
kubectl rollout restart deployment prometheus
kubectl rollout restart deployment grafana

# Docker Compose
docker-compose restart prometheus
docker-compose restart grafana
```

---

## 🐛 Troubleshooting Rápido

### ❌ Prometheus no scrapea la API

```bash
# Verificar endpoint /metrics
kubectl port-forward svc/api 8000:8000
curl http://localhost:8000/metrics

# Ver logs de Prometheus
kubectl logs -l app=prometheus | grep api

# En K3D, verificar RBAC
kubectl get serviceaccount prometheus
```

### ❌ Grafana no muestra datos

```bash
# 1. Verificar datasource
# Grafana → Configuration → Data Sources → Test

# 2. Verificar que Prometheus tiene datos
kubectl port-forward svc/prometheus 9090:9090
# Abrir: http://localhost:9090/graph
# Query: up

# 3. Reiniciar Grafana
kubectl rollout restart deployment grafana
```

### ❌ Ingress no funciona (404)

```bash
# Verificar Traefik
kubectl get pods -n kube-system | grep traefik

# Verificar ingress
kubectl get ingress

# Usar port-forward como alternativa
kubectl port-forward svc/grafana 3000:3000
```

---

## 📚 Queries PromQL Útiles

**Tasa de peticiones por segundo:**
```promql
rate(http_requests_total{job="api"}[1m])
```

**Latencia p95:**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="api"}[5m]))
```

**Uso de CPU (K3S):**
```promql
rate(container_cpu_usage_seconds_total{pod=~"api-.*|web-.*"}[5m]) * 100
```

**Uso de memoria:**
```promql
container_memory_usage_bytes{pod=~"api-.*|web-.*"} / 1024 / 1024
```

**Tareas pendientes:**
```promql
tasks_pending
```

---

## 🎓 Próximos Pasos

1. **Explorar Prometheus:**
   - http://prometheus.localhost/targets (ver targets)
   - http://prometheus.localhost/graph (ejecutar queries)

2. **Personalizar Grafana:**
   - Crear dashboards personalizados
   - Agregar paneles adicionales
   - Configurar alertas

3. **Optimizar:**
   - Ajustar retention de Prometheus
   - Configurar alertas por Slack/Email
   - Agregar más métricas custom

4. **Profundizar:**
   - Leer [MONITORING.md](MONITORING.md) completo
   - Explorar queries PromQL avanzadas
   - Configurar Alertmanager

---

## ✅ Checklist Final

Usa esta checklist para verificar que todo funciona:

### Docker Compose
- [ ] `docker-compose ps` muestra 9 contenedores corriendo
- [ ] http://localhost:3000 (Grafana) accesible
- [ ] http://localhost:9090 (Prometheus) accesible
- [ ] http://localhost:8000/metrics (API) responde
- [ ] Prometheus → Targets → Todos UP
- [ ] Grafana → Datasource → Test → OK
- [ ] Dashboard muestra datos

### K3D
- [ ] `kubectl get pods` - todos Running
- [ ] `k3d cluster list` - cluster todo-app existe
- [ ] `/etc/hosts` configurado
- [ ] http://grafana.localhost accesible
- [ ] http://prometheus.localhost accesible
- [ ] Prometheus → Targets → Todos UP
- [ ] Grafana → Datasource → Test → OK
- [ ] Dashboard muestra datos
- [ ] `./scripts/verify-monitoring.sh` → Todo ✅

---

## 📞 ¿Necesitas Ayuda?

1. **Ejecuta los scripts de verificación:**
   ```bash
   ./scripts/verify-monitoring.sh
   ./scripts/test-connectivity.sh
   ```

2. **Consulta la documentación:**
   - **Problemas generales:** [MONITORING.md](MONITORING.md) → Troubleshooting
   - **Problemas K3D:** [K3D-DEPLOYMENT.md](K3D-DEPLOYMENT.md) → Troubleshooting
   - **Verificación:** [TELEMETRY-SUMMARY.md](TELEMETRY-SUMMARY.md)

3. **Revisa los logs:**
   ```bash
   kubectl logs -l app=prometheus
   kubectl logs -l app=grafana
   kubectl logs -l app=api
   ```

---

## 🎉 ¡Todo Listo!

Tu sistema de telemetría está **completamente funcional** y listo para:

- 📊 Monitorear el rendimiento en tiempo real
- 🔍 Detectar problemas antes de que afecten a usuarios
- 📈 Visualizar métricas de negocio
- 💻 Observar uso de recursos por réplica
- 🚀 Tomar decisiones basadas en datos

**¡Disfruta de tu sistema de observabilidad!** 🎯

---

## 📄 Licencia

Este sistema de telemetría es parte del proyecto Todo App.
