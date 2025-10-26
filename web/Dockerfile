FROM nginx:alpine

# Envsubst (parte del paquete gettext)
RUN apk add --no-cache gettext

WORKDIR /usr/share/nginx/html

RUN rm -rf ./*

COPY . .



EXPOSE 80
