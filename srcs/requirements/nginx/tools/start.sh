#!/bin/bash

set -e

echo "[NGINX] Starting initialization..."

# Generate self-signed SSL certificate if it doesn't exist
if [ ! -f "/etc/ssl/certs/inception.crt" ] || [ ! -f "/etc/ssl/private/inception.key" ]; then
    echo "[NGINX] Generating self-signed SSL certificate..."
    openssl req -newkey rsa:4096 -x509 -sha256 -days 365 -nodes \
        -out /etc/ssl/certs/inception.crt \
        -keyout /etc/ssl/private/inception.key \
        -subj "/C=US/ST=State/L=City/O=42/OU=School/CN=${DOMAIN_NAME}"
    echo "[NGINX] SSL certificate generated"
fi

# Wait for WordPress to be ready
echo "[NGINX] Waiting for WordPress..."
for i in {1..30}; do
    if curl -sf http://wordpress:9000/index.php >/dev/null 2>&1; then
        echo "[NGINX] WordPress is ready"
        break
    fi
    echo "[NGINX] WordPress not ready - sleeping (attempt $i/30)"
    sleep 1
done

echo "[NGINX] Starting nginx server in foreground..."

# Start nginx in foreground, replacing the shell process (PID 1)
exec nginx -g 'daemon off;'
