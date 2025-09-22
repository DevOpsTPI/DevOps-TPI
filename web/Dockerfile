# Imagen base ligera con nginx
FROM nginx:alpine

# Instalamos envsubst (parte del paquete gettext)
RUN apk add --no-cache gettext

# Directorio de trabajo
WORKDIR /usr/share/nginx/html

# Borramos contenido default de nginx
RUN rm -rf ./*

# Copiamos los archivos de tu app (incluyendo config.js con ${API_URL})
COPY . .

# Script de arranque: reemplaza la variable API_URL en config.js y levanta Nginx
CMD envsubst '$API_URL' < config.js > temp_config.js && \
    mv temp_config.js config.js && \
    exec nginx -g "daemon off;"

# Exponemos el puerto 80 (Azure lo redirige automáticamente)
EXPOSE 80
