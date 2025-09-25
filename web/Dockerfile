FROM nginx:alpine

# Envsubst (parte del paquete gettext)
RUN apk add --no-cache gettext

WORKDIR /usr/share/nginx/html

RUN rm -rf ./*

COPY . .

# Script de arranque: reemplaza la variable API_URL en config.js y levanta Nginx
CMD envsubst '$API_URL' < config.js > temp_config.js && \
    mv temp_config.js config.js && \
    exec nginx -g "daemon off;"

EXPOSE 80
