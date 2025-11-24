from datetime import datetime
from config import get_settings
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response
import time

import json
import uuid

settings = get_settings()
print(f"Settings: {settings}")

app = FastAPI(
    title="API",
    description="API con FastAPI y Redis",
    debug=settings.debug
)

# ===== MÉTRICAS DE PROMETHEUS =====
# Contador de peticiones HTTP por método, endpoint y código de estado
http_requests_total = Counter(
    'http_requests_total',
    'Total de peticiones HTTP',
    ['method', 'endpoint', 'status']
)

# Histograma de latencia de peticiones HTTP
http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'Duración de peticiones HTTP en segundos',
    ['method', 'endpoint']
)

# Contador de tareas creadas
tasks_created_total = Counter(
    'tasks_created_total',
    'Total de tareas creadas'
)

# Contador de tareas completadas
tasks_completed_total = Counter(
    'tasks_completed_total',
    'Total de tareas marcadas como completadas'
)

# Contador de tareas eliminadas
tasks_deleted_total = Counter(
    'tasks_deleted_total',
    'Total de tareas eliminadas'
)

# Gauge para el número actual de tareas
tasks_current = Gauge(
    'tasks_current',
    'Número actual de tareas en el sistema'
)

# Gauge para tareas pendientes
tasks_pending = Gauge(
    'tasks_pending',
    'Número de tareas pendientes (no completadas)'
)

print(f"🚀 Ejecutando en entorno: {settings.environment}")
print(f"🌐 API URL: {settings.external_url}")
print(f"🔗 Redis: {settings.redis_host}:{settings.redis_port}")
print(f"🎯 CORS Origins: {settings.cors_origins}")
print(f"📊 Prometheus metrics habilitadas en /metrics")

# Configuración de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Función para normalizar endpoints y evitar alta cardinalidad en métricas
def normalize_endpoint(path: str) -> str:
    """
    Normaliza paths dinámicos reemplazando UUIDs por {id} para reducir cardinalidad.
    Ejemplos:
        /tasks/abc-123-def -> /tasks/{id}
        /tasks/abc-123-def/complete -> /tasks/{id}/complete
    """
    import re
    # Reemplazar UUIDs (formato: 8-4-4-4-12 caracteres hexadecimales) por {id}
    path = re.sub(r'/tasks/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}', '/tasks/{id}', path)
    return path

# Middleware para capturar métricas de peticiones HTTP
@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    # No registrar métricas del endpoint /metrics para evitar recursión
    if request.url.path == "/metrics":
        return await call_next(request)

    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time

    # Normalizar endpoint para evitar alta cardinalidad
    normalized_path = normalize_endpoint(request.url.path)

    # Registrar métricas con endpoint normalizado
    http_requests_total.labels(
        method=request.method,
        endpoint=normalized_path,
        status=response.status_code
    ).inc()

    http_request_duration_seconds.labels(
        method=request.method,
        endpoint=normalized_path
    ).observe(duration)

    return response

r = settings.get_redis_client()

# Función auxiliar para actualizar métricas de tareas
def update_task_metrics():
    """Actualiza las métricas de gauge basadas en el estado actual de Redis"""
    try:
        all_tasks = r.hgetall("tasks")
        total_tasks = len(all_tasks)
        pending_tasks = 0

        for task_data in all_tasks.values():
            task = json.loads(task_data)
            if not task.get('completed', False):
                pending_tasks += 1

        tasks_current.set(total_tasks)
        tasks_pending.set(pending_tasks)
    except Exception as e:
        print(f"Error actualizando métricas de tareas: {e}")

# Endpoints
@app.get("/metrics")
def metrics():
    """Endpoint de métricas para Prometheus"""
    update_task_metrics()
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/health")
def health_check():
    try:
        redis_status = r.ping()
        return {
        "status": "healthy" if r.ping() else "unhealthy",
        "environment": settings.environment,
        "api_url": settings.external_url,
        "redis": {
            "host": settings.redis_host,
            "port": settings.redis_port,
            }
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "environment": settings.environment,
            "redis_error": str(e)
        }

@app.get("/config")
def get_config():
    """Endpoint para ver la configuración actual"""
    return {
        "environment": settings.environment,
        "external_url": settings.external_url,
        "cors_origins": settings.cors_origins,
        "redis": {
            "host": settings.redis_host,
            "port": settings.redis_port
        }
    }

# To do app api
class Task(BaseModel):
    id: str
    text: str
    completed: bool = False
    created_at: str = datetime.utcnow().isoformat()

@app.post("/tasks", response_model=Task)
def create_task(text: str):
    task_id = str(uuid.uuid4())
    task = Task(id=task_id, text=text, completed=False)
    r.hset("tasks", task_id, task.json())
    tasks_created_total.inc()
    return task

@app.get("/tasks", response_model=list[Task])
def list_tasks():
    # Obtenemos todas las tareas de Redis
    tasks = [Task(**json.loads(t)) for t in r.hvals("tasks")]
    
    # Ordenamos por created_at descendente
    tasks.sort(key=lambda t: datetime.fromisoformat(t.created_at), reverse=True)
    
    return tasks

@app.post("/tasks/{task_id}/complete", response_model=Task)
def complete_task(task_id: str):
    data = r.hget("tasks", task_id)
    print(f"data complete: {data}")
    if not data:
        raise HTTPException(404, "Task not found")
    task = Task(**json.loads(data))
    task.completed = True
    r.hset("tasks", task_id, task.json())
    tasks_completed_total.inc()
    return task

@app.post("/tasks/{task_id}/incomplete", response_model=Task)
def incomplete_task(task_id: str):
    data = r.hget("tasks", task_id)
    print(f"data complete: {data}")
    if not data:
        raise HTTPException(404, "Task not found")
    task = Task(**json.loads(data))
    task.completed = False
    r.hset("tasks", task_id, task.json())
    return task

@app.delete("/tasks/{task_id}")
def delete_task(task_id: str):
    if not r.hdel("tasks", task_id):
        raise HTTPException(404, "Task not found")
    tasks_deleted_total.inc()
    return {"ok": True}