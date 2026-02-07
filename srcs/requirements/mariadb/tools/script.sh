#!/bin/bash

set -e

echo "[MariaDB] Starting initialization..."

# Load secrets if provided
if [ -n "${MYSQL_PASSWORD_FILE}" ] && [ -f "${MYSQL_PASSWORD_FILE}" ]; then
    MYSQL_PASSWORD="$(cat "${MYSQL_PASSWORD_FILE}")"
fi
if [ -n "${MYSQL_ROOT_PASSWORD_FILE}" ] && [ -f "${MYSQL_ROOT_PASSWORD_FILE}" ]; then
    MYSQL_ROOT_PASSWORD="$(cat "${MYSQL_ROOT_PASSWORD_FILE}")"
fi

if [ -z "${MYSQL_DATABASE}" ] || [ -z "${MYSQL_USER}" ] || [ -z "${MYSQL_PASSWORD}" ] || [ -z "${MYSQL_ROOT_PASSWORD}" ]; then
    echo "[MariaDB] Missing required environment variables or secrets."
    exit 1
fi

# Initialize database if needed
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "[MariaDB] Initializing database..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql --skip-test-db
    echo "[MariaDB] Database initialization complete"
    
    # Start MariaDB temporarily to set up users
    mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0 &
    MARIADB_PID=$!
    
    # Wait for MariaDB to start
    sleep 3
    
    # Create database and user with proper escaping
    mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF
    
    echo "[MariaDB] Database and user created"
    
    # Stop the temporary MariaDB instance
    kill $MARIADB_PID
    wait $MARIADB_PID 2>/dev/null || true
fi

# Set proper permissions
chown -R mysql:mysql /var/lib/mysql /var/run/mysqld
chmod 777 /var/run/mysqld

echo "[MariaDB] Starting MariaDB server in foreground..."

# Start MariaDB directly in foreground, replacing the shell process (PID 1)
exec mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0
