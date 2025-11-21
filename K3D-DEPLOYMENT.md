# 🚀 Guía de Despliegue en K3D/K3S

Esta guía te ayudará a desplegar la aplicación Todo App con el sistema de telemetría completo en K3D (K3S en Docker).

## 📋 Tabla de Contenidos

- [Requisitos Previos](#requisitos-previos)
- [Configuración Inicial de K3D](#configuración-inicial-de-k3d)
- [Despliegue de la Aplicación](#despliegue-de-la-aplicación)
- [Despliegue del Sistema de Telemetría](#despliegue-del-sistema-de-telemetría)
- [Verificación](#verificación)
- [Acceso a las Interfaces](#acceso-a-las-interfaces)
- [Troubleshooting K3D Específico](#troubleshooting-k3d-específico)

---

## 🔧 Requisitos Previos

### Instalación de K3D

**Linux/Mac:**
```bash
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

**Windows (PowerShell con Chocolatey):**
```powershell
choco install k3d
```

**Verificar instalación:**
```bash
k3d version
kubectl version --client
```

### Herramientas Necesarias

- **Docker Desktop** (Windows/Mac) o Docker Engine (Linux)
- **kubectl** (viene con Docker Desktop o instalar por separado)
- **k3d** v5.0+

---

## 🏗️ Configuración Inicial de K3D

### 1. Crear el Cluster K3D

Vamos a crear un cluster K3D con configuración optimizada para nuestra aplicación:

```bash
# Crear cluster con puerto 80 mapeado (para Traefik Ingress)
k3d cluster create todo-app \
  --api-port 6550 \
  --port "80:80@loadbalancer" \
  --port "443:443@loadbalancer" \
  --agents 1 \
  --k3s-arg "--disable=traefik@server:0"
```

**Parámetros explicados:**
- `todo-app`: Nombre del cluster
- `--api-port 6550`: Puerto para la API de Kubernetes
- `--port "80:80@loadbalancer"`: Mapea puerto 80 del host al loadbalancer (para Traefik)
- `--agents 1`: Crea 1 nodo worker (además del nodo servidor)
- `--disable=traefik`: Deshabilitamos el Traefik por defecto de K3S porque desplegaremos nuestra propia versión

**Alternativa: Usar el Traefik integrado de K3S**

Si prefieres usar el Traefik que viene con K3S, crea el cluster sin el flag `--disable`:

```bash
k3d cluster create todo-app \
  --api-port 6550 \
  --port "80:80@loadbalancer" \
  --port "443:443@loadbalancer" \
  --agents 1
```

### 2. Verificar el Cluster

```bash
# Ver información del cluster
k3d cluster list

# Ver nodos
kubectl get nodes

# Ver pods del sistema
kubectl get pods -n kube-system
```

Deberías ver algo como:
```
NAME                      STATUS   ROLES                  AGE
k3d-todo-app-server-0     Ready    control-plane,master   1m
k3d-todo-app-agent-0      Ready    <none>                 1m
```

### 3. Instalar Traefik Ingress Controller (si lo deshabilitaste)

Si deshabilitaste Traefik, instálalo manualmente:

```bash
# Agregar el repositorio de Helm de Traefik
helm repo add traefik https://helm.traefik.io/traefik
helm repo update

# Instalar Traefik
helm install traefik traefik/traefik \
  --namespace kube-system \
  --set ports.web.exposedPort=80 \
  --set ports.websecure.exposedPort=443
```

Verificar:
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
```

---

## 🚀 Despliegue de la Aplicación

### 1. Construir Imágenes Docker Localmente

K3D puede usar imágenes locales. Primero construye las imágenes:

```bash
# Construir imagen de Redis (si tienes Dockerfile personalizado)
# Si usas redis:alpine estándar, puedes omitir esto
docker build -t redis:local ./redis

# Construir imagen de API
docker build -t api:latest ./api

# Construir imagen de Web
docker build -t web:latest ./web
```

### 2. Importar Imágenes al Cluster K3D

Importa las imágenes construidas al cluster:

```bash
k3d image import api:latest -c todo-app
k3d image import web:latest -c todo-app
```

**Nota:** No necesitas importar `redis:alpine` si usas la imagen oficial, K3D la descargará automáticamente.

### 3. Desplegar Servicios de la Aplicación

```bash
# Desplegar Redis
kubectl apply -f deploy/redis-deployment.yaml
kubectl apply -f deploy/redis-service.yaml

# Desplegar API
kubectl apply -f deploy/api-deployment.yaml
kubectl apply -f deploy/api-service.yaml

# Desplegar Web
kubectl apply -f deploy/web-deployment.yaml
kubectl apply -f deploy/web-service.yaml

# Desplegar Ingress
kubectl apply -f deploy/ingress.yaml
```

### 4. Verificar Despliegue de la Aplicación

```bash
# Ver todos los pods
kubectl get pods

# Deberías ver:
# - redis-xxxxxxxxxx-xxxxx (1/1 Running)
# - api-xxxxxxxxxx-xxxxx (2/2 Running) - 2 réplicas
# - web-xxxxxxxxxx-xxxxx (2/2 Running) - 2 réplicas

# Ver servicios
kubectl get svc

# Ver ingress
kubectl get ingress
```

### 5. Probar la Aplicación

```bash
# Probar el endpoint de la API
curl http://localhost/api/health

# Abrir el navegador
# http://localhost (debería mostrar la aplicación web)
```

---

## 📊 Despliegue del Sistema de Telemetría

### 1. Desplegar RBAC para Prometheus

Prometheus necesita permisos para acceder a la API de Kubernetes (service discovery):

```bash
kubectl apply -f deploy/prometheus-rbac.yaml
```

Esto crea:
- Un ServiceAccount `prometheus`
- Un ClusterRole con permisos de lectura
- Un ClusterRoleBinding

### 2. Desplegar ConfigMap de Prometheus

```bash
kubectl apply -f deploy/prometheus-config.yaml
```

Este ConfigMap incluye configuración específica para K3S:
- Service discovery de pods (para detectar réplicas de la API)
- Acceso a cAdvisor integrado en kubelet
- Configuración para exporters

### 3. Desplegar Prometheus

```bash
kubectl apply -f deploy/prometheus-deployment.yaml
```

Verificar:
```bash
kubectl get pods -l app=prometheus
kubectl logs -l app=prometheus -f
```

### 4. Desplegar Grafana

```bash
kubectl apply -f deploy/grafana-deployment.yaml
```

Verificar:
```bash
kubectl get pods -l app=grafana
kubectl logs -l app=grafana -f
```

### 5. Desplegar Exporters (Redis y Nginx)

**IMPORTANTE:** Para K3D, usa el archivo específico que NO incluye cAdvisor standalone:

```bash
kubectl apply -f deploy/exporters-deployment-k3d.yaml
```

**¿Por qué?** K3S ya tiene cAdvisor integrado en kubelet. Prometheus accederá a él directamente a través de la API de Kubernetes.

Verificar:
```bash
kubectl get pods -l tier=monitoring
kubectl get svc -l tier=monitoring
```

### 6. Desplegar Ingress de Monitoreo

```bash
kubectl apply -f deploy/monitoring-ingress.yaml
```

Verificar:
```bash
kubectl get ingress monitoring-ingress
```

---

## ✅ Verificación

### Método 1: Script Automático

Ejecuta el script de verificación:

```bash
# Dar permisos de ejecución
chmod +x scripts/verify-monitoring.sh

# Ejecutar
./scripts/verify-monitoring.sh
```

El script verificará:
- ✅ Pods y servicios corriendo
- ✅ Conectividad a Prometheus y Grafana
- ✅ Targets de Prometheus (UP/DOWN)
- ✅ Datasource de Grafana
- ✅ Endpoint `/metrics` de la API
- ✅ Conectividad Prometheus ↔ API

### Método 2: Verificación Manual

#### 1. Verificar Pods

```bash
kubectl get pods
```

Todos los pods deben estar en estado `Running` con `1/1` o `2/2` (réplicas):

```
NAME                              READY   STATUS    RESTARTS   AGE
redis-xxxxxxxxxx-xxxxx            1/1     Running   0          5m
api-xxxxxxxxxx-xxxxx              1/1     Running   0          5m
api-xxxxxxxxxx-yyyyy              1/1     Running   0          5m
web-xxxxxxxxxx-xxxxx              1/1     Running   0          5m
web-xxxxxxxxxx-yyyyy              1/1     Running   0          5m
prometheus-xxxxxxxxxx-xxxxx       1/1     Running   0          3m
grafana-xxxxxxxxxx-xxxxx          1/1     Running   0          3m
redis-exporter-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
nginx-exporter-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

#### 2. Verificar Servicios

```bash
kubectl get svc
```

Deberías ver servicios ClusterIP para todos los componentes:

```
NAME             TYPE        CLUSTER-IP      PORT(S)
redis            ClusterIP   10.43.x.x       6379/TCP
api              ClusterIP   10.43.x.x       8000/TCP
web              ClusterIP   10.43.x.x       80/TCP
prometheus       ClusterIP   10.43.x.x       9090/TCP
grafana          ClusterIP   10.43.x.x       3000/TCP
redis-exporter   ClusterIP   10.43.x.x       9121/TCP
nginx-exporter   ClusterIP   10.43.x.x       9113/TCP
```

#### 3. Verificar Ingress

```bash
kubectl get ingress
```

Deberías ver 2 ingress:

```
NAME                 CLASS     HOSTS                ADDRESS
app-ingress          traefik   localhost            x.x.x.x
monitoring-ingress   traefik   grafana.localhost    x.x.x.x
                               prometheus.localhost
```

#### 4. Probar Endpoints

**Aplicación:**
```bash
curl http://localhost/api/health
curl http://localhost/api/tasks
```

**Prometheus:**
```bash
# Usar port-forward
kubectl port-forward svc/prometheus 9090:9090 &

# En otra terminal
curl http://localhost:9090/-/healthy
```

**Grafana:**
```bash
# Usar port-forward
kubectl port-forward svc/grafana 3000:3000 &

# En otra terminal
curl http://localhost:3000/api/health
```

#### 5. Verificar Targets de Prometheus

```bash
# Port-forward
kubectl port-forward svc/prometheus 9090:9090

# Abrir navegador
# http://localhost:9090/targets
```

Deberías ver estos jobs en estado **UP**:
- ✅ `api` - 2 targets (2 réplicas)
- ✅ `web-nginx` - 1 target
- ✅ `redis` - 1 target
- ✅ `prometheus` - 1 target
- ✅ `kubernetes-cadvisor` - 2 targets (nodos)
- ✅ `kubernetes-nodes` - 2 targets

#### 6. Verificar Métricas de la API

```bash
kubectl port-forward svc/api 8000:8000

curl http://localhost:8000/metrics | grep http_requests_total
```

Deberías ver métricas Prometheus:
```
# HELP http_requests_total Total de peticiones HTTP
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/health",status="200"} 15.0
...
```

---

## 🌐 Acceso a las Interfaces

### Opción 1: Usando Ingress (Recomendado)

#### Configurar `/etc/hosts` (Linux/Mac) o `C:\Windows\System32\drivers\etc\hosts` (Windows)

Agregar estas líneas:

```
127.0.0.1 localhost
127.0.0.1 grafana.localhost
127.0.0.1 prometheus.localhost
```

#### Acceder desde el navegador:

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **Aplicación Web** | http://localhost | - |
| **API** | http://localhost/api | - |
| **Grafana** | http://grafana.localhost | admin / admin |
| **Prometheus** | http://prometheus.localhost | - |

### Opción 2: Usando Port-Forward

Si Ingress no funciona o prefieres acceso directo:

```bash
# Grafana
kubectl port-forward svc/grafana 3000:3000

# Prometheus
kubectl port-forward svc/prometheus 9090:9090

# API
kubectl port-forward svc/api 8000:8000

# Web
kubectl port-forward svc/web 8080:80
```

Luego accede:
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- API: http://localhost:8000
- Web: http://localhost:8080

---

## 🔍 Troubleshooting K3D Específico

### 1. Pods en estado `ImagePullBackOff`

**Problema:** El pod no puede descargar la imagen.

**Causa:** Imágenes locales no importadas al cluster.

**Solución:**
```bash
# Construir la imagen localmente
docker build -t api:latest ./api

# Importar al cluster K3D
k3d image import api:latest -c todo-app

# Reiniciar deployment
kubectl rollout restart deployment api
```

### 2. Prometheus no puede acceder a targets

**Problema:** Targets aparecen como "DOWN" en Prometheus.

**Causa:** Falta RBAC o ServiceAccount.

**Solución:**
```bash
# Verificar que el ServiceAccount existe
kubectl get serviceaccount prometheus

# Si no existe, aplicar RBAC
kubectl apply -f deploy/prometheus-rbac.yaml

# Reiniciar Prometheus
kubectl rollout restart deployment prometheus

# Ver logs
kubectl logs -l app=prometheus -f
```

### 3. cAdvisor no muestra métricas en Prometheus

**Problema:** Job `kubernetes-cadvisor` aparece como DOWN.

**Causa:** Configuración incorrecta de acceso a kubelet.

**Solución:**

En K3S, kubelet expone cAdvisor en el endpoint `/metrics/cadvisor`. Verifica la configuración:

```bash
# Ver configuración de Prometheus
kubectl get configmap prometheus-config -o yaml

# Verificar que existe el job kubernetes-cadvisor
# con el path correcto: /api/v1/nodes/$1/proxy/metrics/cadvisor
```

Si el problema persiste, verifica los logs de Prometheus:
```bash
kubectl logs -l app=prometheus | grep cadvisor
```

### 4. Ingress no funciona (404 Not Found)

**Problema:** Al acceder a http://localhost aparece 404.

**Causa:** Traefik no está corriendo o no está configurado correctamente.

**Solución:**

```bash
# Verificar que Traefik está corriendo
kubectl get pods -n kube-system | grep traefik

# Si no está, instalarlo
helm install traefik traefik/traefik --namespace kube-system

# Verificar ingress
kubectl get ingress

# Ver logs de Traefik
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
```

### 5. No puedo acceder a grafana.localhost

**Problema:** El navegador no resuelve grafana.localhost.

**Solución 1: Editar hosts**

Asegúrate de haber editado el archivo `/etc/hosts` (Linux/Mac) o `C:\Windows\System32\drivers\etc\hosts` (Windows):

```
127.0.0.1 grafana.localhost
127.0.0.1 prometheus.localhost
```

**Solución 2: Usar port-forward**

```bash
kubectl port-forward svc/grafana 3000:3000
# Acceder a http://localhost:3000
```

### 6. API returna errores de conexión a Redis

**Problema:** Logs de la API muestran "connection refused" a Redis.

**Causa:** Redis no está corriendo o el servicio no existe.

**Solución:**

```bash
# Verificar que Redis está corriendo
kubectl get pods -l app=redis

# Verificar servicio de Redis
kubectl get svc redis

# Si no existe, aplicar
kubectl apply -f deploy/redis-deployment.yaml
kubectl apply -f deploy/redis-service.yaml

# Ver logs de la API
kubectl logs -l app=api
```

### 7. Recrear el Cluster desde Cero

Si todo falla, puedes eliminar y recrear el cluster:

```bash
# Eliminar cluster
k3d cluster delete todo-app

# Recrear
k3d cluster create todo-app \
  --api-port 6550 \
  --port "80:80@loadbalancer" \
  --agents 1

# Redesplegar todo
kubectl apply -f deploy/
```

### 8. Ver Logs de un Pod Específico

```bash
# Ver logs en tiempo real
kubectl logs -f <pod-name>

# Ejemplos:
kubectl logs -f api-xxxxxxxxxx-xxxxx
kubectl logs -f prometheus-xxxxxxxxxx-xxxxx
kubectl logs -f grafana-xxxxxxxxxx-xxxxx

# Ver logs de todos los pods de un deployment
kubectl logs -l app=api -f
```

### 9. Ejecutar Shell dentro de un Pod

```bash
# Acceder a shell del pod de API
kubectl exec -it <api-pod-name> -- /bin/bash

# Desde dentro, probar conexión a Redis
kubectl exec -it <api-pod-name> -- curl redis:6379

# Acceder a shell de Redis
kubectl exec -it <redis-pod-name> -- redis-cli
```

### 10. Métricas de cAdvisor no aparecen en Grafana

**Problema:** Los paneles de CPU/Memoria están vacíos.

**Causa:** Las queries en el dashboard de Grafana usan el label `name` que solo existe en Docker, no en Kubernetes.

**Solución:**

Edita el dashboard de Grafana y reemplaza las queries:

**Antes (Docker):**
```promql
container_memory_usage_bytes{name=~"fastapi|web|redis"}
```

**Después (Kubernetes):**
```promql
container_memory_usage_bytes{pod=~"api-.*|web-.*|redis-.*", container!=""}
```

O usa el label `container`:
```promql
container_memory_usage_bytes{container=~"api|web|redis"}
```

---

## 🎯 Comandos Útiles de K3D

```bash
# Listar clusters
k3d cluster list

# Detener cluster (sin eliminarlo)
k3d cluster stop todo-app

# Iniciar cluster detenido
k3d cluster start todo-app

# Eliminar cluster
k3d cluster delete todo-app

# Importar imagen al cluster
k3d image import <image-name>:<tag> -c todo-app

# Ver configuración del cluster
kubectl cluster-info

# Ver contexto actual
kubectl config current-context

# Cambiar a otro contexto (si tienes múltiples clusters)
kubectl config use-context k3d-todo-app
```

---

## 📚 Recursos Adicionales

- [Documentación de K3D](https://k3d.io/)
- [Documentación de K3S](https://k3s.io/)
- [Guía de Prometheus en Kubernetes](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [Guía de Grafana en Kubernetes](https://grafana.com/docs/grafana/latest/setup-grafana/installation/kubernetes/)

---

## ✅ Checklist de Despliegue

- [ ] K3D instalado y cluster creado
- [ ] Imágenes construidas e importadas
- [ ] Aplicación desplegada (redis, api, web)
- [ ] Ingress funcionando (http://localhost)
- [ ] RBAC de Prometheus aplicado
- [ ] Prometheus desplegado y corriendo
- [ ] Grafana desplegado y corriendo
- [ ] Exporters desplegados (redis-exporter, nginx-exporter)
- [ ] Ingress de monitoreo configurado
- [ ] Todos los targets de Prometheus en estado UP
- [ ] Dashboard de Grafana accesible
- [ ] Datasource de Prometheus configurado en Grafana
- [ ] Métricas de la aplicación visibles en Grafana

---

**¡Tu sistema de telemetría está listo en K3D!** 🚀

Para más información sobre el uso del sistema de telemetría, consulta [MONITORING.md](MONITORING.md).
