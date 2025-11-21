# 📜 Scripts Disponibles

Guía de todos los scripts disponibles para desplegar y verificar el sistema de telemetría.

---

## 🪟 Scripts para Windows (PowerShell)

### 1. `scripts/deploy-k3d.ps1`

**Descripción:** Despliegue automático completo en K3D.

**Uso:**
```powershell
.\scripts\deploy-k3d.ps1
```

**Qué hace:**
- ✅ Verifica dependencias (k3d, kubectl, docker)
- ✅ Crea cluster K3D con configuración optimizada
- ✅ Construye imágenes Docker (api, web)
- ✅ Importa imágenes al cluster
- ✅ Despliega aplicación (redis, api, web)
- ✅ Despliega telemetría (Prometheus, Grafana, exporters)
- ✅ Muestra URLs de acceso e instrucciones

**Requisitos:**
- PowerShell 5.1+
- Ejecutar como Administrador (recomendado)
- Docker Desktop corriendo

**Tiempo estimado:** 3-5 minutos

---

### 2. `scripts/verify-monitoring.ps1`

**Descripción:** Verificación completa del sistema de telemetría.

**Uso:**
```powershell
.\scripts\verify-monitoring.ps1
```

**Qué verifica:**
- ✅ Pods y servicios corriendo
- ✅ Conectividad a Prometheus y Grafana
- ✅ Targets de Prometheus (UP/DOWN)
- ✅ Datasource de Grafana
- ✅ Endpoint /metrics de la API
- ✅ Conectividad Prometheus ↔ API

**Requisitos:**
- Cluster K3D desplegado
- PowerShell 5.1+

**Tiempo estimado:** 30 segundos

---

## 🐧 Scripts para Linux/Mac (Bash)

### 1. `scripts/deploy-k3d.sh`

**Descripción:** Despliegue automático completo en K3D.

**Uso:**
```bash
chmod +x scripts/deploy-k3d.sh
./scripts/deploy-k3d.sh
```

**Qué hace:**
- ✅ Verifica dependencias (k3d, kubectl, docker)
- ✅ Crea cluster K3D con configuración optimizada
- ✅ Construye imágenes Docker (api, web)
- ✅ Importa imágenes al cluster
- ✅ Despliega aplicación (redis, api, web)
- ✅ Despliega telemetría (Prometheus, Grafana, exporters)
- ✅ Muestra URLs de acceso e instrucciones

**Requisitos:**
- Bash 4.0+
- Docker corriendo

**Tiempo estimado:** 3-5 minutos

---

### 2. `scripts/verify-monitoring.sh`

**Descripción:** Verificación completa del sistema de telemetría.

**Uso:**
```bash
chmod +x scripts/verify-monitoring.sh
./scripts/verify-monitoring.sh
```

**Qué verifica:**
- ✅ Pods y servicios corriendo
- ✅ Conectividad a Prometheus y Grafana
- ✅ Targets de Prometheus (UP/DOWN)
- ✅ Datasource de Grafana
- ✅ Endpoint /metrics de la API
- ✅ Conectividad Prometheus ↔ API

**Requisitos:**
- Cluster K3D desplegado
- Bash 4.0+
- Python 3 (para procesamiento JSON)

**Tiempo estimado:** 30 segundos

---

### 3. `scripts/test-connectivity.sh`

**Descripción:** Test específico de conectividad Prometheus ↔ Grafana.

**Uso:**
```bash
chmod +x scripts/test-connectivity.sh
./scripts/test-connectivity.sh
```

**Qué verifica:**
- ✅ Prometheus está corriendo
- ✅ Grafana está corriendo
- ✅ Prometheus → API (scrapea métricas)
- ✅ Grafana → Prometheus (datasource)
- ✅ API → /metrics endpoint
- ✅ Todos los targets de Prometheus

**Requisitos:**
- Cluster K3D o Docker Compose desplegado
- Bash 4.0+
- Python 3 (opcional, para mejor output)

**Tiempo estimado:** 20 segundos

---

## 🔧 Uso Común

### Flujo de Trabajo Típico

#### Windows:

```powershell
# 1. Desplegar todo
.\scripts\deploy-k3d.ps1

# 2. Verificar
.\scripts\verify-monitoring.ps1

# 3. Configurar hosts (PowerShell como Admin)
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value @"

127.0.0.1 grafana.localhost
127.0.0.1 prometheus.localhost
"@

# 4. Acceder a Grafana
# http://grafana.localhost (admin/admin)
```

#### Linux/Mac:

```bash
# 1. Desplegar todo
chmod +x scripts/deploy-k3d.sh
./scripts/deploy-k3d.sh

# 2. Verificar
chmod +x scripts/verify-monitoring.sh
./scripts/verify-monitoring.sh

# 3. Configurar hosts
sudo nano /etc/hosts
# Agregar:
# 127.0.0.1 grafana.localhost
# 127.0.0.1 prometheus.localhost

# 4. Acceder a Grafana
# http://grafana.localhost (admin/admin)
```

---

## 🐛 Scripts de Diagnóstico

### Verificar Estado Rápido

**Windows:**
```powershell
kubectl get pods
kubectl get svc
kubectl get ingress
```

**Linux/Mac:**
```bash
kubectl get pods
kubectl get svc
kubectl get ingress
```

### Ver Logs de un Servicio

**Windows:**
```powershell
kubectl logs -l app=prometheus -f
kubectl logs -l app=grafana -f
kubectl logs -l app=api -f
```

**Linux/Mac:**
```bash
kubectl logs -l app=prometheus -f
kubectl logs -l app=grafana -f
kubectl logs -l app=api -f
```

### Port-Forward Manual

**Windows:**
```powershell
# Terminal 1
kubectl port-forward svc/grafana 3000:3000

# Terminal 2
kubectl port-forward svc/prometheus 9090:9090

# Terminal 3
kubectl port-forward svc/api 8000:8000
```

**Linux/Mac:**
```bash
# Terminal 1
kubectl port-forward svc/grafana 3000:3000

# Terminal 2
kubectl port-forward svc/prometheus 9090:9090

# Terminal 3
kubectl port-forward svc/api 8000:8000
```

---

## 🧪 Generar Tráfico para Métricas

### Windows:

```powershell
# Generar 50 tareas
1..50 | ForEach-Object {
    Invoke-WebRequest -Uri "http://localhost/api/tasks?text=Task_$_" -Method POST
    Invoke-WebRequest -Uri "http://localhost/api/tasks" | Out-Null
    Start-Sleep -Milliseconds 500
}
```

### Linux/Mac:

```bash
# Generar 50 tareas
for i in {1..50}; do
  curl -X POST "http://localhost/api/tasks?text=Task_$i"
  curl http://localhost/api/tasks > /dev/null
  sleep 0.5
done
```

---

## 🧹 Scripts de Limpieza

### Eliminar Cluster K3D

**Windows:**
```powershell
k3d cluster delete todo-app
```

**Linux/Mac:**
```bash
k3d cluster delete todo-app
```

### Eliminar Imágenes Docker

**Windows:**
```powershell
docker rmi api:latest web:latest
```

**Linux/Mac:**
```bash
docker rmi api:latest web:latest
```

### Eliminar Solo Deployments (mantener cluster)

**Windows:**
```powershell
kubectl delete -f .\deploy\
```

**Linux/Mac:**
```bash
kubectl delete -f ./deploy/
```

---

## 📊 Scripts de Monitoreo

### Ver Recursos del Cluster

**Windows:**
```powershell
kubectl top nodes
kubectl top pods
```

**Linux/Mac:**
```bash
kubectl top nodes
kubectl top pods
```

### Ver Events

**Windows:**
```powershell
kubectl get events --sort-by=.metadata.creationTimestamp
```

**Linux/Mac:**
```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

---

## 🔍 Troubleshooting con Scripts

### Si deploy-k3d falla:

1. **Verificar Docker:**
   ```bash
   docker ps
   ```

2. **Verificar dependencias:**
   ```bash
   k3d version
   kubectl version --client
   ```

3. **Ver logs detallados:**
   - El script muestra errores en tiempo real
   - Lee los mensajes de error cuidadosamente

4. **Eliminar y reintentar:**
   ```bash
   k3d cluster delete todo-app
   ./scripts/deploy-k3d.sh  # o .ps1 en Windows
   ```

### Si verify-monitoring falla:

1. **Esperar más tiempo:**
   - Los pods pueden tardar en iniciar
   - Espera 1-2 minutos y reintenta

2. **Verificar pods manualmente:**
   ```bash
   kubectl get pods
   ```

3. **Ver logs de pods con problemas:**
   ```bash
   kubectl logs <pod-name>
   ```

4. **Reiniciar deployment problemático:**
   ```bash
   kubectl rollout restart deployment <deployment-name>
   ```

---

## 💡 Tips de Uso

### 1. Ejecutar Scripts desde la Raíz del Proyecto

Siempre ejecuta los scripts desde la carpeta raíz `TPI/`:

```bash
cd /path/to/TPI
./scripts/deploy-k3d.sh
```

### 2. Permisos en Linux/Mac

Recuerda dar permisos de ejecución:

```bash
chmod +x scripts/*.sh
```

### 3. PowerShell Execution Policy en Windows

Si hay problemas ejecutando scripts:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 4. Usar Port-Forward si Ingress no funciona

Si `grafana.localhost` no funciona, siempre puedes usar port-forward:

```bash
kubectl port-forward svc/grafana 3000:3000
```

### 5. Detener Port-Forward

En Windows/Linux/Mac: `Ctrl + C`

---

## 📚 Documentación Relacionada

| Documento | Para qué |
|-----------|----------|
| [START-WINDOWS.md](START-WINDOWS.md) | Guía rápida para Windows |
| [WINDOWS-GUIDE.md](WINDOWS-GUIDE.md) | Guía completa para Windows |
| [QUICKSTART-K3D.md](QUICKSTART-K3D.md) | Quick start para K3D (Linux/Mac/Windows) |
| [K3D-DEPLOYMENT.md](K3D-DEPLOYMENT.md) | Guía detallada de K3D |
| [MONITORING.md](MONITORING.md) | Guía completa de telemetría |
| [README-TELEMETRY.md](README-TELEMETRY.md) | README principal de telemetría |

---

## ✅ Checklist de Scripts

### Primera Vez:

- [ ] Instalar dependencias (Docker, k3d, kubectl)
- [ ] Dar permisos a scripts (Linux/Mac)
- [ ] Configurar Execution Policy (Windows)
- [ ] Ejecutar `deploy-k3d` (.sh o .ps1)
- [ ] Configurar archivo hosts
- [ ] Ejecutar `verify-monitoring` (.sh o .ps1)
- [ ] Acceder a Grafana

### Uso Diario:

- [ ] Verificar que Docker está corriendo
- [ ] Iniciar cluster si está detenido: `k3d cluster start todo-app`
- [ ] Verificar pods: `kubectl get pods`
- [ ] Acceder a interfaces (Grafana, Prometheus)

### Al Terminar:

- [ ] Detener cluster: `k3d cluster stop todo-app`
- [ ] O eliminar cluster: `k3d cluster delete todo-app`

---

## 🎯 Scripts en Resumen

| Script | Plataforma | Tiempo | Propósito |
|--------|------------|--------|-----------|
| `deploy-k3d.ps1` | Windows | 3-5 min | Despliegue completo |
| `deploy-k3d.sh` | Linux/Mac | 3-5 min | Despliegue completo |
| `verify-monitoring.ps1` | Windows | 30 seg | Verificación completa |
| `verify-monitoring.sh` | Linux/Mac | 30 seg | Verificación completa |
| `test-connectivity.sh` | Linux/Mac | 20 seg | Test de conectividad |

---

**¡Usa estos scripts para facilitar tu trabajo con el sistema de telemetría!** 🚀
