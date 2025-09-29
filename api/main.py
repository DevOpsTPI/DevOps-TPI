from datetime import datetime
from config import get_settings
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

import json
import uuid

settings = get_settings()
print(f"Settings: {settings}")

app = FastAPI(
    title="API",
    description="API con FastAPI y Redis",
    debug=settings.debug
)

print(f"🚀 Ejecutando en entorno: {settings.environment}")
print(f"🌐 API URL: {settings.external_url}")
print(f"🔗 Redis: {settings.redis_host}:{settings.redis_port}")
print(f"🎯 CORS Origins: {settings.cors_origins}")

# Configuración de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

r = settings.get_redis_client()

# Endpoints
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
    return {"ok": True}