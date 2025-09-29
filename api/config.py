import os
from typing import List

class Settings:
    def __init__(self):
        self.environment: str = os.getenv("ENVIRONMENT", "local")
        self.debug: bool = os.getenv("DEBUG", "false").lower() == "true"

        self.redis_host: str = os.getenv("REDIS_HOST", "redis")
        self.redis_port: int = int(os.getenv("REDIS_PORT", "6379"))
        self.redis_url: str = f"redis://{self.redis_host}:{self.redis_port}"

        self.port: int = int(os.getenv("PORT", "8000"))
        self.host: str = os.getenv("HOST", "0.0.0.0")  # default contenedores

        self.external_url: str = os.getenv("API_URL", f"http://localhost:{self.port}")
        self.frontend_url: str = os.getenv("FRONTEND_URL", "http://localhost:8080")

        self.cors_origins: List[str] = self._get_cors_origins()

    def _get_cors_origins(self) -> List[str]:
        origins = []
        if self.frontend_url:
            origins.append(self.frontend_url)

        additional = os.getenv("ADDITIONAL_CORS_ORIGINS", "")
        if additional:
            origins.extend([url.strip() for url in additional.split(",")])

        return origins

    def get_redis_client(self):
        import redis
        return redis.from_url(self.redis_url, decode_responses=True)

# Instancia global
settings = Settings()

def get_settings() -> Settings:
    return settings
