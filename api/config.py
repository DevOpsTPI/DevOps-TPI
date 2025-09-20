# ===== api/config.py =====
import os
from typing import List

class Settings:
    def __init__(self):
        # === CONFIGURACIÓN BÁSICA ===
        self.environment: str = os.getenv('ENVIRONMENT', 'local')
        self.debug: bool = self.environment == 'local'
        
        # === CONFIGURACIÓN REDIS ===
        self.redis_host = os.getenv('REDIS_HOST', 'redis' if self.environment == 'local' else 'localhost')
        self.redis_port = int(os.getenv('REDIS_PORT', '6379'))
        self.redis_url = f"redis://{self.redis_host}:{self.redis_port}"
        
        # === CONFIGURACIÓN CORS ===
        self.cors_origins = self._get_cors_origins()
        
        # === CONFIGURACIÓN DEL SERVIDOR ===
        self.port = int(os.getenv('PORT', '8000'))
        self.host = '0.0.0.0'  # Para que funcione en contenedores
        
        # === URL EXTERNA (opcional para logs/debug) ===
        self.external_url = os.getenv('EXTERNAL_URL', f'http://localhost:{self.port}')
        
    def _get_cors_origins(self) -> List[str]:
        """Configuración de CORS según el entorno"""
        if self.environment == 'local':
            return [
                "http://localhost:8080",
                "http://127.0.0.1:8080",
                "http://localhost:3000",
            ]
        else:
            # En producción (Azure)
            origins = []
            
            # URL del frontend desde variable de entorno
            frontend_url = os.getenv('FRONTEND_URL', '')
            if frontend_url:
                origins.append(frontend_url)

            # URLs adicionales separadas por comas
            additional_origins = os.getenv('ADDITIONAL_CORS_ORIGINS', '')
            if additional_origins:
                origins.extend([url.strip() for url in additional_origins.split(',')])
            
            return origins
    
    def get_redis_client(self):
        """Factory para crear cliente Redis"""
        import redis
        try:
            return redis.from_url(self.redis_url, decode_responses=True)
        except Exception as e:
            raise ConnectionError(f"Error conectando a Redis en {self.redis_host}:{self.redis_port} - {e}")
    
    def is_production(self) -> bool:
        return self.environment == 'production'
    
    def is_local(self) -> bool:
        return self.environment == 'local'

# === INSTANCIA GLOBAL ===
settings = Settings()

# === FUNCIÓN DE UTILIDAD ===
def get_settings() -> Settings:
    """Obtiene la configuración global"""
    return settings