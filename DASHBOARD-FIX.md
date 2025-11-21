# Dashboard Fix - Actualizacion para K3S

## Problema Identificado

El dashboard original usaba labels de Docker Compose (`name="fastapi"`) pero K3S/Kubernetes usa labels diferentes (`pod`, `container`, `namespace`).

## Cambios Realizados

He actualizado los siguientes paneles en `monitoring/grafana/dashboards/todo-app-dashboard.json`:

### 1. Panel "Uso de CPU por Contenedor (%)"
**Antes:**
```promql
100 * (1 - avg(rate(container_cpu_usage_seconds_total{name=~"fastapi|web|redis"}[5m])) by (name))
```

**Despues:**
```promql
rate(container_cpu_usage_seconds_total{pod=~"api-.*|web-.*|redis-.*", container!="", container!="POD"}[5m]) * 100
```

### 2. Panel "Uso de Memoria por Contenedor"
**Antes:**
```promql
container_memory_usage_bytes{name=~"fastapi|web|redis"}
```

**Despues:**
```promql
container_memory_usage_bytes{pod=~"api-.*|web-.*|redis-.*", container!="", container!="POD"}
```

### 3. Panel "Trafico de Red por Contenedor"
**Antes:**
```promql
rate(container_network_receive_bytes_total{name=~"fastapi|web|redis"}[5m])
rate(container_network_transmit_bytes_total{name=~"fastapi|web|redis"}[5m])
```

**Despues:**
```promql
rate(container_network_receive_bytes_total{pod=~"api-.*|web-.*|redis-.*", container!="", container!="POD"}[5m])
rate(container_network_transmit_bytes_total{pod=~"api-.*|web-.*|redis-.*", container!="", container!="POD"}[5m])
```

## Como Re-importar el Dashboard

### Opcion 1: Actualizar el dashboard existente (RECOMENDADO)

1. Abre Grafana: http://grafana.localhost (admin/admin)

2. Ve a "Dashboards" en el menu lateral

3. Encuentra el dashboard "Todo App - Metricas Completas"

4. Haz clic en el icono de configuracion (engranaje) arriba a la derecha

5. Selecciona "JSON Model"

6. Abre el archivo `monitoring/grafana/dashboards/todo-app-dashboard.json` en un editor de texto

7. Copia TODO el contenido del archivo

8. Pega el contenido en el editor JSON de Grafana (reemplazando todo el contenido existente)

9. Haz clic en "Save changes"

10. Haz clic en "Save dashboard" arriba a la derecha

### Opcion 2: Eliminar y crear nuevo dashboard

1. Abre Grafana: http://grafana.localhost

2. Ve a "Dashboards" → Encuentra "Todo App - Metricas Completas"

3. Haz clic en el icono de configuracion → "Delete"

4. Confirma la eliminacion

5. Ve a "Dashboards" → "New" → "Import"

6. Haz clic en "Upload JSON file"

7. Selecciona: `monitoring/grafana/dashboards/todo-app-dashboard.json`

8. Haz clic en "Import"

## Verificar que Funciona

Despues de re-importar el dashboard:

1. Genera trafico para ver metricas:
```powershell
1..20 | ForEach-Object {
    Invoke-WebRequest -Uri "http://localhost/api/tasks?text=Test_$_" -Method POST
}
```

2. Espera 1-2 minutos para que Prometheus recolecte las metricas

3. Los paneles de CPU, Memoria y Red ahora deberian mostrar datos para:
   - `api-XXXXXXX-XXXX` (2 replicas)
   - `web-XXXXXXX-XXXX` (2 replicas)
   - `redis-XXXXXXX-XXXX` (1 replica)

## Labels K3S vs Docker Compose

| Metrica | Docker Compose | K3S/Kubernetes |
|---------|---------------|----------------|
| Identificador | `name="fastapi"` | `pod=~"api-.*"` |
| Contenedor | `name` | `container` |
| Namespace | N/A | `namespace="default"` |
| Filtro vacio | N/A | `container!=""` y `container!="POD"` |

## Queries de Prueba en Prometheus

Puedes probar estas queries en Prometheus (http://prometheus.localhost) para verificar:

### Ver pods de la API:
```promql
container_memory_usage_bytes{pod=~"api-.*", container!="", container!="POD"}
```

### Ver uso de CPU:
```promql
rate(container_cpu_usage_seconds_total{pod=~"api-.*", container!="", container!="POD"}[5m]) * 100
```

### Ver todas las metricas de contenedores:
```promql
container_memory_usage_bytes
```

## Troubleshooting

### "No data" en los paneles
- Verifica que los pods esten corriendo: `kubectl get pods`
- Verifica los targets en Prometheus: http://prometheus.localhost/targets
- El job `kubernetes-cadvisor` debe estar UP
- Espera 1-2 minutos despues de re-importar el dashboard

### No veo metricas de API o Web
- Ejecuta: `kubectl get pods -l app=api`
- Ejecuta: `kubectl get pods -l app=web`
- Si no hay pods, re-ejecuta el script de deploy

### Los paneles muestran datos pero son confusos
- Los labels ahora muestran el nombre completo del pod: `api-6d96c57d79-c2tkz`
- Esto es normal en Kubernetes, cada replica tiene un nombre unico
