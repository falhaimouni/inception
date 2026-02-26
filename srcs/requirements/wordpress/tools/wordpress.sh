#!/bin/bash
set -e
# Read secrets and strip trailing newlines (files often contain a trailing newline)
DB_PASSWORD=$(cat /run/secrets/db_password | tr -d '\n')
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password | tr -d '\n')
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password | tr -d '\n')
mkdir -p "$WP_DIR"

if [ ! -f "$WP_DIR/wp-config.php" ]; then
  wget -qO /tmp/wordpress.tar.gz https://wordpress.org/latest.tar.gz
  tar -xzf /tmp/wordpress.tar.gz -C /tmp/
  cp -r /tmp/wordpress/* "$WP_DIR"
  chown -R www-data:www-data "$WP_DIR"

  cp "$WP_DIR/wp-config-sample.php" "$WP_DIR/wp-config.php"
  sed -i "s/database_name_here/${DB_NAME}/" "$WP_DIR/wp-config.php"
  sed -i "s/username_here/${DB_USER}/" "$WP_DIR/wp-config.php"
  sed -i "s/password_here/${DB_PASSWORD}/" "$WP_DIR/wp-config.php"
  sed -i "s/localhost/${DB_HOST}/" "$WP_DIR/wp-config.php"

  # Ensure WordPress knows its canonical URL (helps with redirects when behind TLS termination)
  if ! grep -q "WP_HOME" "$WP_DIR/wp-config.php"; then
    sed -i "1s|^<?php$|<?php\n\ndefine('WP_HOME', '${WP_URL}');\ndefine('WP_SITEURL', '${WP_URL}');|" "$WP_DIR/wp-config.php"
  fi
  # Add HTTPS detection for reverse proxies
  if ! grep -q "HTTPS Detection" "$WP_DIR/wp-config.php"; then
    sed -i "/\/\* That's all, stop editing! Happy publishing. \*\//i \\
/* HTTPS Detection */\nif (isset(\\\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \\\$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {\n    \\\$_SERVER['HTTPS'] = 'on';\n}\n" "$WP_DIR/wp-config.php" || true
  fi  
fi

if ! wp --path="$WP_DIR" core is-installed --allow-root; then
  wp --path="$WP_DIR" core install \
    --url="$WP_URL" \
    --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN_USER" \
    --admin_password="$WP_ADMIN_PASSWORD" \
    --admin_email="$WP_ADMIN_EMAIL" \
    --skip-email \
    --allow-root

wp user create "$WP_USER_NAME" "$WP_USER_EMAIL" \
  --path="$WP_DIR" \
  --role=author \
  --user_pass="$WP_USER_PASSWORD" \
  --allow-root

fi
    sed -i "s|listen = /run/php/php8.2-fpm.sock|listen = 9000|" "/etc/php/8.2/fpm/pool.d/www.conf" 

exec php-fpm8.2 -F