#!/bin/bash

set -e

echo "[WordPress] Starting initialization..."

# Wait for MariaDB to be ready
echo "[WordPress] Waiting for MariaDB at ${DB_HOST}..."
for i in {1..30}; do
    if mysqladmin ping -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASSWORD}" --silent 2>/dev/null; then
        echo "[WordPress] MariaDB is ready"
        break
    fi
    echo "[WordPress] MariaDB is unavailable - sleeping (attempt $i/30)"
    sleep 1
done

# Create wp-config.php if it doesn't exist
if [ ! -f "/var/www/html/wp-config.php" ]; then
    echo "[WordPress] Creating wp-config.php..."
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
    
    # Update configuration with environment variables
    sed -i "s/database_name_here/${DB_NAME}/g" /var/www/html/wp-config.php
    sed -i "s/username_here/${DB_USER}/g" /var/www/html/wp-config.php
    sed -i "s/password_here/${DB_PASSWORD}/g" /var/www/html/wp-config.php
    sed -i "s/localhost/${DB_HOST}/g" /var/www/html/wp-config.php
    
    # Add security salts and keys
    echo "[WordPress] Fetching security keys and salts..."
    SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/ || echo "")
    if [ ! -z "$SALTS" ]; then
        sed -i '/put your unique phrase here/d' /var/www/html/wp-config.php
        printf '%s\n' "$SALTS" >> /var/www/html/wp-config.php
    fi
fi

# Check if WordPress is already installed
if ! wp core is-installed --allow-root 2>/dev/null; then
    echo "[WordPress] Installing WordPress..."
    wp core install \
        --url="${WP_URL}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --allow-root
    
    echo "[WordPress] Creating additional user..."
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=editor \
        --allow-root || true
    
    echo "[WordPress] Installation complete"
else
    echo "[WordPress] Already installed"
fi

echo "[WordPress] Starting PHP-FPM in foreground..."
exec php-fpm7.4 -F
