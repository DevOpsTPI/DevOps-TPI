# Imagen base ligera con nginx
FROM nginx:alpine

# Instalamos herramientas necesarias para hacer sustitución de variables
RUN apk add --no-cache bash gettext

# Borramos contenido default de nginx
RUN rm -rf /usr/share/nginx/html/*

# Copiamos los archivos de tu app
COPY . /usr/share/nginx/html/

# Exponemos el puerto 80 (Azure lo redirige automáticamente)
EXPOSE 80

# Comando de inicio:
#  - reemplaza variables de entorno en config.js
#  - luego arranca nginx
#CMD envsubst < /usr/share/nginx/html/config.js > /usr/share/nginx/html/config.runtime.js && \
#  mv /usr/share/nginx/html/config.runtime.js /usr/share/nginx/html/config.js && \
#  nginx -g 'daemon off;'

# Instalamos envsubst (parte del paquete gettext)
RUN apk add --no-cache gettext

# Script de arranque: reemplaza la variable API_URL en config.js y levanta Nginx
CMD envsubst < config.js.template > config.js && \
    exec nginx -g "daemon off;"
