# ⚡ START - Windows

Guía ultra rápida para desplegar en **Windows**.

---

## 📋 Instalación Rápida (5 minutos)

### 1. Instalar Chocolatey

**PowerShell como Administrador** (`Win + X` → "Terminal (Admin)"):

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

### 2. Instalar Docker Desktop

Descarga e instala desde: https://www.docker.com/products/docker-desktop

**Importante:** Reinicia Windows después de instalar.

### 3. Instalar K3D y Kubectl

```powershell
choco install k3d kubernetes-cli -y
```

### 4. Verificar Instalación

```powershell
docker --version
k3d version
kubectl version --client
```

---

## 🚀 Despliegue (2 minutos)

### 1. Abrir PowerShell como Administrador

`Win + X` → "Terminal (Admin)"

### 2. Ir al Proyecto

```powershell
cd C:\Users\reina\OneDrive\Desktop\Archivos\U\DevOps\TPs\TPI
```

### 3. Permitir Scripts

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 4. Ejecutar Despliegue

```powershell
.\scripts\deploy-k3d.ps1
```

⏳ **Espera 3-5 minutos** mientras se despliega todo.

### 5. Configurar Hosts

**PowerShell como Admin:**

```powershell
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value @"

127.0.0.1 grafana.localhost
127.0.0.1 prometheus.localhost
"@
```

---

## ✅ Verificar

```powershell
.\scripts\verify-monitoring.ps1
```

---

## 🌐 Acceder

| Servicio | URL | Login |
|----------|-----|-------|
| **App** | http://localhost | - |
| **Grafana** | http://grafana.localhost | admin / admin |
| **Prometheus** | http://prometheus.localhost | - |

### Si `grafana.localhost` no funciona:

```powershell
# Terminal 1
kubectl port-forward svc/grafana 3000:3000

# Terminal 2
kubectl port-forward svc/prometheus 9090:9090
```

Luego:
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090

---

## 🐛 Problemas Comunes

### ❌ "Scripts deshabilitados"

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### ❌ "Docker no está corriendo"

1. Abre Docker Desktop
2. Espera a que inicie
3. Verifica: `docker ps`

### ❌ "No se reconoce k3d"

```powershell
choco install k3d -y
# Cierra y abre PowerShell
```

### ❌ "Cluster ya existe"

```powershell
k3d cluster delete todo-app
.\scripts\deploy-k3d.ps1
```

### ❌ "Permiso denegado (hosts)"

Debes ejecutar PowerShell **como Administrador**:
- `Win + X` → "Terminal (Admin)"

---

## 📊 Ver Métricas

### 1. Generar Tráfico

```powershell
1..20 | ForEach-Object {
    Invoke-WebRequest -Uri "http://localhost/api/tasks?text=Task_$_" -Method POST
    Start-Sleep -Milliseconds 500
}
```

### 2. Abrir Grafana

http://grafana.localhost (admin/admin)

### 3. Ver Dashboard

"Todo App - Métricas Completas"

---

## 🧹 Limpiar

```powershell
# Eliminar cluster
k3d cluster delete todo-app

# Eliminar imágenes
docker rmi api:latest web:latest
```

---

## 📚 Documentación Completa

- **Guía Windows:** [WINDOWS-GUIDE.md](WINDOWS-GUIDE.md)
- **Guía K3D:** [K3D-DEPLOYMENT.md](K3D-DEPLOYMENT.md)
- **Quick Start:** [QUICKSTART-K3D.md](QUICKSTART-K3D.md)
- **Telemetría:** [MONITORING.md](MONITORING.md)

---

## ✅ Checklist

- [ ] Docker Desktop instalado
- [ ] Chocolatey instalado
- [ ] K3D instalado
- [ ] Kubectl instalado
- [ ] PowerShell como Admin
- [ ] Script ejecutado
- [ ] Hosts configurado
- [ ] Grafana accesible
- [ ] Métricas visibles

---

## 🎯 Comandos Esenciales

```powershell
# Ver pods
kubectl get pods

# Ver logs
kubectl logs -l app=prometheus -f

# Port-forward
kubectl port-forward svc/grafana 3000:3000

# Verificar
.\scripts\verify-monitoring.ps1

# Eliminar
k3d cluster delete todo-app
```

---

## 🎉 ¡Listo!

**URLs:**
- App: http://localhost
- Grafana: http://grafana.localhost
- Prometheus: http://prometheus.localhost

**Credenciales Grafana:**
- Usuario: `admin`
- Password: `admin`

¡Disfruta! 🚀
