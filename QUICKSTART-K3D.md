# ⚡ Quick Start - K3D con Telemetría

Guía rápida de 5 minutos para desplegar Todo App con Prometheus + Grafana en K3D.

## 🚀 Despliegue Rápido

### 1. Despliegue Automático

```bash
# Dar permisos de ejecución
chmod +x scripts/deploy-k3d.sh

# Ejecutar script de despliegue
./scripts/deploy-k3d.sh
```

Esto hará:
- ✅ Crear cluster K3D
- ✅ Construir e importar imágenes
- ✅ Desplegar aplicación (redis, api, web)
- ✅ Desplegar telemetría (Prometheus, Grafana, exporters)

### 2. Configurar acceso (hosts)

**Linux/Mac:**
```bash
sudo nano /etc/hosts
```

**Windows (como Administrador):**
```
notepad C:\Windows\System32\drivers\etc\hosts
```

Agregar:
```
127.0.0.1 grafana.localhost
127.0.0.1 prometheus.localhost
```

### 3. Verificar

```bash
# Dar permisos
chmod +x scripts/verify-monitoring.sh

# Ejecutar verificación
./scripts/verify-monitoring.sh
```

---

## 🌐 Acceso Rápido

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **App Web** | http://localhost | - |
| **API** | http://localhost/api | - |
| **Grafana** | http://grafana.localhost | admin / admin |
| **Prometheus** | http://prometheus.localhost | - |

### Alternativa: Port-Forward

Si Ingress no funciona:

```bash
# Terminal 1: Grafana
kubectl port-forward svc/grafana 3000:3000

# Terminal 2: Prometheus
kubectl port-forward svc/prometheus 9090:9090

# Acceder a:
# - Grafana: http://localhost:3000
# - Prometheus: http://localhost:9090
```

---

## ✅ Verificación Rápida

### 1. Ver pods

```bash
kubectl get pods
```

Todos deben estar `Running`:
```
redis-xxx          1/1  Running
api-xxx            1/1  Running
api-yyy            1/1  Running  # 2 réplicas
web-xxx            1/1  Running
web-yyy            1/1  Running  # 2 réplicas
prometheus-xxx     1/1  Running
grafana-xxx        1/1  Running
redis-exporter-xxx 1/1  Running
nginx-exporter-xxx 1/1  Running
```

### 2. Probar aplicación

```bash
# Health check
curl http://localhost/api/health

# Crear tarea
curl -X POST "http://localhost/api/tasks?text=Test"

# Listar tareas
curl http://localhost/api/tasks
```

### 3. Verificar Prometheus

```bash
# Port-forward
kubectl port-forward svc/prometheus 9090:9090 &

# Verificar targets (debe mostrar UP)
curl http://localhost:9090/api/v1/targets | grep '"health":"up"'

# Ver en navegador
open http://localhost:9090/targets
```

### 4. Verificar Grafana

```bash
# Port-forward
kubectl port-forward svc/grafana 3000:3000 &

# Verificar health
curl http://localhost:3000/api/health

# Acceder desde navegador
open http://localhost:3000
# Login: admin / admin
```

### 5. Verificar métricas de la API

```bash
kubectl port-forward svc/api 8000:8000 &

# Ver métricas
curl http://localhost:8000/metrics | head -20

# Buscar métrica específica
curl http://localhost:8000/metrics | grep http_requests_total
```

---

## 🎯 Verificar Conectividad Prometheus ↔ Grafana

### Desde Grafana:

1. Abrir http://grafana.localhost (o http://localhost:3000)
2. Login: `admin` / `admin`
3. Ir a **Configuration** → **Data Sources**
4. Click en **Prometheus**
5. Scroll abajo, click en **"Test"**
6. Debe aparecer: ✅ **"Data source is working"**

### Desde Prometheus:

1. Abrir http://prometheus.localhost (o http://localhost:9090)
2. Ir a **Status** → **Targets**
3. Verificar que todos los jobs estén **UP**:
   - ✅ api (2 targets)
   - ✅ web-nginx (1 target)
   - ✅ redis (1 target)
   - ✅ prometheus (1 target)
   - ✅ kubernetes-cadvisor (N targets, según nodos)

---

## 📊 Ver Dashboard en Grafana

1. Abrir Grafana: http://grafana.localhost
2. Login: `admin` / `admin`
3. Ir a **Dashboards** (icono de 4 cuadrados)
4. Click en **"Todo App - Métricas Completas"**

Deberías ver:
- 📈 Peticiones HTTP por segundo
- ⏱️ Latencia de peticiones (p50, p95)
- ✅ Tareas creadas/completadas/eliminadas
- 💻 Uso de CPU por contenedor
- 💾 Uso de memoria por contenedor
- 🌐 Tráfico de red
- 🔴 Métricas de Redis (conexiones, keys)
- 🟢 Métricas de Nginx (peticiones, conexiones)

---

## 🧪 Generar Tráfico para Ver Métricas

```bash
# Script simple para generar tráfico
for i in {1..50}; do
  curl -X POST "http://localhost/api/tasks?text=Task_$i"
  curl http://localhost/api/tasks > /dev/null
  sleep 0.5
done

# Ver las métricas actualizarse en Grafana en tiempo real
```

---

## 🐛 Problemas Comunes

### Pods en `ImagePullBackOff`

```bash
# Reconstruir e importar imágenes
docker build -t api:latest ./api
docker build -t web:latest ./web
k3d image import api:latest web:latest -c todo-app

# Reiniciar deployments
kubectl rollout restart deployment api web
```

### Prometheus targets en DOWN

```bash
# Verificar RBAC
kubectl get serviceaccount prometheus
kubectl get clusterrole prometheus
kubectl get clusterrolebinding prometheus

# Si falta alguno:
kubectl apply -f deploy/prometheus-rbac.yaml

# Reiniciar Prometheus
kubectl rollout restart deployment prometheus

# Ver logs
kubectl logs -l app=prometheus -f
```

### Ingress no funciona (404)

```bash
# Verificar Traefik
kubectl get pods -n kube-system | grep traefik

# Ver ingress
kubectl get ingress

# Si no está Traefik, reinstalar:
helm repo add traefik https://helm.traefik.io/traefik
helm install traefik traefik/traefik --namespace kube-system
```

### No puedo acceder a grafana.localhost

**Solución 1:** Verificar `/etc/hosts`

```bash
# Debe contener:
127.0.0.1 grafana.localhost
127.0.0.1 prometheus.localhost
```

**Solución 2:** Usar port-forward

```bash
kubectl port-forward svc/grafana 3000:3000
# Acceder a http://localhost:3000
```

---

## 🧹 Limpieza

### Eliminar solo los deployments

```bash
kubectl delete -f deploy/
```

### Eliminar el cluster completo

```bash
k3d cluster delete todo-app
```

---

## 📚 Documentación Completa

- **Guía detallada de K3D:** [K3D-DEPLOYMENT.md](K3D-DEPLOYMENT.md)
- **Guía de telemetría:** [MONITORING.md](MONITORING.md)
- **Troubleshooting completo:** [K3D-DEPLOYMENT.md#troubleshooting-k3d-específico](K3D-DEPLOYMENT.md#troubleshooting-k3d-específico)

---

## 🎉 ¡Listo!

Tu aplicación con telemetría completa está corriendo en K3D.

**Próximos pasos:**
1. Explorar el dashboard de Grafana
2. Crear tus propios paneles
3. Configurar alertas en Prometheus
4. Experimentar con queries PromQL

**¿Preguntas?** Consulta la documentación completa o ejecuta:

```bash
./scripts/verify-monitoring.sh
```
