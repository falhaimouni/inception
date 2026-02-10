FROM debian:bookworm-slim

RUN apt update -y \
    && apt install nginx -y \
    && apt install openssl -y

COPY  conf/default.conf /etc/nginx/conf.d
RUN rm -f /etc/nginx/sites-enabled/default
RUN mkdir -p /etc/nginx/ssl
RUN openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/server.key \
    -out /etc/nginx/ssl/server.crt \
    -days 365 \
    -subj "/C=JO/ST=Amman/L=Amman/O=42/OU=Inception/CN=localhost"
CMD ["nginx", "-g", "daemon off;"]
