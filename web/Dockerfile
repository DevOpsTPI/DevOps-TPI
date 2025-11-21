FROM nginx:alpine

# Envsubst (parte del paquete gettext)
RUN apk add --no-cache gettext

WORKDIR /usr/share/nginx/html

RUN rm -rf ./*

COPY . .

# Copiar configuración personalizada de nginx con stub_status habilitado
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
