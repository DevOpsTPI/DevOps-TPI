from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from config import get_settings

settings = get_settings()

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
        },
        "is_production": settings.is_production()
    }

@app.get("/get/{key}")
def get_value(key: str):
    try:
        value = r.get(key)
        return {"key": key, "value": value}
    except Exception as e:
        return {"error": f"Error getting key: {str(e)}"}

@app.post("/set/{key}/{value}")
def set_value(key: str, value: str):
    try:
        r.set(key, value)
        return {"message": f"Set {key} = {value}"}
    except Exception as e:
        return {"error": f"Error setting key: {str(e)}"}