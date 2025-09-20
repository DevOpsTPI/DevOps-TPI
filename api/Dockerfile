FROM python:3.10-slim

# Metadatos para Azure
#LABEL maintainer="tu-email@ejemplo.com"
LABEL version="1.0"
LABEL description="API FastAPI con Redis para Azure Container Registry"

# Variables de entorno para Azure (coinciden con tu config.py)
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV ENVIRONMENT=production
ENV PORT=8000
ENV HOST=0.0.0.0
ENV REDIS_HOST=localhost
ENV REDIS_PORT=6379

WORKDIR /app

# Instalar curl para health check
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copiar requirements primero (mejor cache de Docker layers)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código fuente
COPY . .

# Health check usando tu endpoint /health
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:$PORT/health || exit 1

# Exponer puerto
EXPOSE $PORT

# Comando usando las variables de entorno
CMD uvicorn main:app --host $HOST --port $PORT