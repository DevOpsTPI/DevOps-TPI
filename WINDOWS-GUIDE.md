# 🪟 Guía para Windows - Sistema de Telemetría

Guía específica para desplegar el sistema de telemetría en **Windows** usando K3D.

---

## 📋 Requisitos Previos

### 1. Docker Desktop

**Descarga e instala Docker Desktop:**
- https://www.docker.com/products/docker-desktop

**Verificación:**
```powershell
docker --version
docker ps
```

### 2. Chocolatey (Gestor de Paquetes)

**Instalación (PowerShell como Administrador):**
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

**Verificación:**
```powershell
choco --version
```

### 3. K3D

**Instalación:**
```powershell
choco install k3d
```

**Verificación:**
```powershell
k3d version
```

### 4. Kubectl

**Instalación:**
```powershell
choco install kubernetes-cli
```

**Verificación:**
```powershell
kubectl version --client
```

---

## 🚀 Despliegue Rápido

### 1. Abrir PowerShell como Administrador

- Presiona `Win + X`
- Selecciona **"Windows PowerShell (Administrador)"** o **"Terminal (Administrador)"**

### 2. Navegar al Proyecto

```powershell
cd C:\Users\reina\OneDrive\Desktop\Archivos\U\DevOps\TPs\TPI
```

### 3. Permitir Ejecución de Scripts

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 4. Ejecutar Script de Despliegue

```powershell
.\scripts\deploy-k3d.ps1
```

Este script hará:
- ✅ Crear cluster K3D
- ✅ Construir imágenes Docker
- ✅ Importar imágenes al cluster
- ✅ Desplegar aplicación (redis, api, web)
- ✅ Desplegar telemetría (Prometheus, Grafana, exporters)

### 5. Configurar Archivo Hosts

**Opción A: Manualmente**

1. Abrir Bloc de notas como Administrador:
   ```powershell
   notepad C:\Windows\System32\drivers\etc\hosts
   ```

2. Agregar al final del archivo:
   ```
   127.0.0.1 grafana.localhost
   127.0.0.1 prometheus.localhost
   ```

3. Guardar (Ctrl + S)

**Opción B: Automáticamente (PowerShell como Admin)**

```powershell
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value @"

127.0.0.1 grafana.localhost
127.0.0.1 prometheus.localhost
"@
```

### 6. Verificar Despliegue

```powershell
.\scripts\verify-monitoring.ps1
```

---

## 🌐 Acceso a las Interfaces

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **App Web** | http://localhost | - |
| **API** | http://localhost/api | - |
| **Grafana** | http://grafana.localhost | admin / admin |
| **Prometheus** | http://prometheus.localhost | - |

### Alternativa: Port-Forward

Si `grafana.localhost` no funciona, usa port-forward:

```powershell
# Terminal 1: Grafana
kubectl port-forward svc/grafana 3000:3000

# Terminal 2: Prometheus
kubectl port-forward svc/prometheus 9090:9090
```

Luego accede:
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090

---

## ✅ Verificación Rápida

### 1. Ver Pods

```powershell
kubectl get pods
```

Todos deben estar `Running`:
```
NAME                              READY   STATUS    RESTARTS   AGE
redis-xxx                         1/1     Running   0          2m
api-xxx                           1/1     Running   0          2m
api-yyy                           1/1     Running   0          2m
web-xxx                           1/1     Running   0          2m
web-yyy                           1/1     Running   0          2m
prometheus-xxx                    1/1     Running   0          1m
grafana-xxx                       1/1     Running   0          1m
redis-exporter-xxx                1/1     Running   0          1m
nginx-exporter-xxx                1/1     Running   0          1m
```

### 2. Ver Servicios

```powershell
kubectl get svc
```

### 3. Probar Aplicación

```powershell
# Health check
curl http://localhost/api/health

# Crear tarea
curl -X POST "http://localhost/api/tasks?text=Test"

# Listar tareas
curl http://localhost/api/tasks
```

### 4. Verificar Prometheus

```powershell
kubectl port-forward svc/prometheus 9090:9090
```

Abrir navegador: http://localhost:9090/targets

Verificar que todos los jobs estén **UP**.

### 5. Verificar Grafana

```powershell
kubectl port-forward svc/grafana 3000:3000
```

Abrir navegador: http://localhost:3000

- Login: `admin` / `admin`
- Ir a Configuration → Data Sources → Prometheus → Test
- Debe decir: **"Data source is working"** ✅

---

## 🐛 Problemas Comunes en Windows

### ❌ "k3d no se reconoce como comando"

**Solución:**

1. Verifica que Chocolatey instaló k3d:
   ```powershell
   choco list --local-only | findstr k3d
   ```

2. Si no está instalado:
   ```powershell
   choco install k3d -y
   ```

3. Cierra y abre PowerShell nuevamente

### ❌ "Docker no está corriendo"

**Solución:**

1. Abre Docker Desktop desde el menú de inicio
2. Espera a que inicie completamente (icono de ballena en la bandeja)
3. Verifica:
   ```powershell
   docker ps
   ```

### ❌ "Scripts deshabilitados"

**Error:**
```
.\scripts\deploy-k3d.ps1 : No se puede cargar el archivo porque la ejecución
de scripts está deshabilitada en este sistema.
```

**Solución:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### ❌ "No se puede acceder a grafana.localhost"

**Solución 1: Verificar archivo hosts**

```powershell
# Ver contenido del archivo hosts
Get-Content C:\Windows\System32\drivers\etc\hosts

# Debe contener:
# 127.0.0.1 grafana.localhost
# 127.0.0.1 prometheus.localhost
```

**Solución 2: Usar port-forward**

```powershell
kubectl port-forward svc/grafana 3000:3000
# Acceder a http://localhost:3000
```

### ❌ "Error al crear cluster K3D"

**Error:**
```
ERRO[0000] Failed to create cluster 'todo-app' because a cluster with that name already exists
```

**Solución:**
```powershell
# Eliminar cluster existente
k3d cluster delete todo-app

# Crear nuevo cluster
.\scripts\deploy-k3d.ps1
```

### ❌ "Pods en estado ImagePullBackOff"

**Solución:**

```powershell
# Reconstruir e importar imágenes
docker build -t api:latest .\api
docker build -t web:latest .\web

# Importar al cluster
k3d image import api:latest web:latest -c todo-app

# Reiniciar deployments
kubectl rollout restart deployment api
kubectl rollout restart deployment web
```

### ❌ "curl no se reconoce como comando"

**Solución 1: Usar PowerShell equivalente**

```powershell
# En lugar de curl, usa:
Invoke-WebRequest http://localhost/api/health
```

**Solución 2: Instalar curl**

```powershell
choco install curl -y
```

### ❌ "Permiso denegado al editar hosts"

**Solución:**

Debes ejecutar PowerShell **como Administrador**:

1. Presiona `Win + X`
2. Selecciona **"Windows PowerShell (Administrador)"**
3. Ejecuta el comando para editar hosts

---

## 🧹 Limpieza

### Eliminar solo los deployments

```powershell
kubectl delete -f .\deploy\
```

### Eliminar el cluster completo

```powershell
k3d cluster delete todo-app
```

### Eliminar imágenes Docker

```powershell
docker rmi api:latest web:latest
```

---

## 🔧 Comandos Útiles en PowerShell

### Ver estado de K3D

```powershell
# Listar clusters
k3d cluster list

# Detener cluster
k3d cluster stop todo-app

# Iniciar cluster
k3d cluster start todo-app

# Eliminar cluster
k3d cluster delete todo-app
```

### Ver logs de pods

```powershell
# Logs en tiempo real
kubectl logs -l app=prometheus -f

# Logs de un pod específico
kubectl logs <pod-name>

# Ejemplos:
kubectl logs -l app=api -f
kubectl logs -l app=grafana -f
```

### Port-forward múltiples servicios

```powershell
# En diferentes ventanas de PowerShell:

# Ventana 1: Grafana
kubectl port-forward svc/grafana 3000:3000

# Ventana 2: Prometheus
kubectl port-forward svc/prometheus 9090:9090

# Ventana 3: API
kubectl port-forward svc/api 8000:8000
```

### Ejecutar shell dentro de un pod

```powershell
# Listar pods
kubectl get pods

# Ejecutar bash en el pod de API
kubectl exec -it <api-pod-name> -- /bin/bash

# Ejecutar comando directamente
kubectl exec <api-pod-name> -- curl redis:6379
```

---

## 📊 Generar Tráfico para Ver Métricas

```powershell
# Script para generar tráfico
1..50 | ForEach-Object {
    Invoke-WebRequest -Uri "http://localhost/api/tasks?text=Task_$_" -Method POST
    Invoke-WebRequest -Uri "http://localhost/api/tasks" | Out-Null
    Start-Sleep -Milliseconds 500
}
```

Luego abre Grafana y observa las métricas actualizarse en tiempo real.

---

## 🎓 Atajos de Teclado en PowerShell

| Atajo | Acción |
|-------|--------|
| `Ctrl + C` | Detener comando actual |
| `Ctrl + L` | Limpiar pantalla (también `clear` o `cls`) |
| `↑` `↓` | Navegar historial de comandos |
| `Tab` | Autocompletar |
| `F7` | Mostrar historial de comandos |

---

## 📚 Recursos Adicionales

- [Documentación de K3D](https://k3d.io/)
- [Guía completa: K3D-DEPLOYMENT.md](K3D-DEPLOYMENT.md)
- [Guía de telemetría: MONITORING.md](MONITORING.md)
- [Quick Start: QUICKSTART-K3D.md](QUICKSTART-K3D.md)

---

## ✅ Checklist de Despliegue en Windows

- [ ] Docker Desktop instalado y corriendo
- [ ] Chocolatey instalado
- [ ] K3D instalado (`choco install k3d`)
- [ ] Kubectl instalado (`choco install kubernetes-cli`)
- [ ] PowerShell ejecutado como Administrador
- [ ] Execution Policy configurado (`Set-ExecutionPolicy RemoteSigned`)
- [ ] Script de despliegue ejecutado (`.\scripts\deploy-k3d.ps1`)
- [ ] Archivo hosts configurado
- [ ] Pods en estado Running (`kubectl get pods`)
- [ ] Grafana accesible (http://grafana.localhost)
- [ ] Prometheus accesible (http://prometheus.localhost)
- [ ] Script de verificación ejecutado (`.\scripts\verify-monitoring.ps1`)
- [ ] Dashboard de Grafana muestra datos

---

## 🎉 ¡Listo!

Tu sistema de telemetría está corriendo en Windows con K3D.

**Comandos esenciales:**

```powershell
# Ver estado
kubectl get pods

# Ver logs
kubectl logs -l app=prometheus -f

# Port-forward
kubectl port-forward svc/grafana 3000:3000

# Verificar
.\scripts\verify-monitoring.ps1

# Eliminar cluster
k3d cluster delete todo-app
```

**URLs de acceso:**
- App: http://localhost
- Grafana: http://grafana.localhost (admin/admin)
- Prometheus: http://prometheus.localhost

¡Disfruta de tu sistema de observabilidad! 🚀📊
