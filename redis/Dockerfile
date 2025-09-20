FROM redis:7-alpine

# Metadatos para Azure
LABEL maintainer="tu-email@ejemplo.com"
LABEL version="1.0"
LABEL description="Redis para Azure Container Registry - Red privada sin contraseña"

# Variables de entorno para Azure
ENV REDIS_PORT=6379
ENV REDIS_MAXMEMORY="256mb"
ENV REDIS_MAXMEMORY_POLICY="allkeys-lru"

# Health check simple y efectivo
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD redis-cli -p $REDIS_PORT ping || exit 1

# Exponer puerto (solo accesible desde red privada de Azure)
EXPOSE $REDIS_PORT

# Comando simplificado sin contraseña
CMD ["sh", "-c", "redis-server \
  --port $REDIS_PORT \
  $( [ -n \"$REDIS_MAXMEMORY\" ] && echo --maxmemory $REDIS_MAXMEMORY || echo '' ) \
  --maxmemory-policy $REDIS_MAXMEMORY_POLICY \
  --save 60 1000 \
  --appendonly yes \
  --appendfsync everysec"]