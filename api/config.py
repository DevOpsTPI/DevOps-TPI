import os
from typing import List

class Settings:
    def __init__(self):
        self.environment: str = os.getenv("ENVIRONMENT", "local")
        self.debug: bool = os.getenv("DEBUG", "false").lower() == "true"

        self.redis_host: str = os.getenv("REDIS_HOST", "redis")
        self.redis_port: int = int(os.getenv("REDIS_PORT", "6379"))
        self.redis_url: str = f"redis://{self.redis_host}:{self.redis_port}"

        # Configuracion de Redis Sentinel
        self.use_sentinel: bool = os.getenv("REDIS_SENTINEL", "false").lower() == "true"
        self.sentinel_service: str = os.getenv("REDIS_SENTINEL_SERVICE", "redis-sentinel")
        self.sentinel_port: int = int(os.getenv("REDIS_SENTINEL_PORT", "26379"))
        self.sentinel_master: str = os.getenv("REDIS_MASTER_NAME", "mymaster")

        self.port: int = int(os.getenv("PORT", "8000"))
        self.host: str = os.getenv("HOST", "0.0.0.0")  # default contenedores

        self.external_url: str = os.getenv("API_URL", f"http://localhost:{self.port}")
        self.frontend_url: str = os.getenv("FRONTEND_URL", "http://localhost:8080")

        self.cors_origins: List[str] = self._get_cors_origins()

    def _get_cors_origins(self) -> List[str]:
        origins = []
        if self.frontend_url:
            origins.append(self.frontend_url)
        else:
            origins.append("http://localhost:8080")

        additional = os.getenv("ADDITIONAL_CORS_ORIGINS", "")
        if additional:
            origins.extend([url.strip() for url in additional.split(",")])

        return origins

    def get_redis_client(self):
        import redis
        from redis.sentinel import Sentinel

        if self.use_sentinel:
            # Configurar Sentinel para alta disponibilidad
            # Usar nombres DNS cortos (dentro del mismo namespace)
            sentinels = [
                (f'redis-sentinel-0.redis-sentinel', self.sentinel_port),
                (f'redis-sentinel-1.redis-sentinel', self.sentinel_port),
                (f'redis-sentinel-2.redis-sentinel', self.sentinel_port)
            ]

            print(f"🔍 Conectando a Sentinel: {sentinels}")
            sentinel = Sentinel(sentinels, socket_timeout=2.0)

            # Obtener el cliente del master
            print(f"🔍 Buscando master '{self.sentinel_master}' via Sentinel")
            return sentinel.master_for(
                self.sentinel_master,
                socket_timeout=2.0,
                decode_responses=True
            )
        else:
            # Conexión directa a Redis (modo local/desarrollo)
            return redis.from_url(self.redis_url, decode_responses=True)

# Instancia global
settings = Settings()

def get_settings() -> Settings:
    return settings
