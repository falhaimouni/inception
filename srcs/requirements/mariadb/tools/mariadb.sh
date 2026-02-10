#!/bin/bash
set -e
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

# Read secrets and strip trailing newlines
DB_PASSWORD=$(cat /run/secrets/db_password | tr -d '\n')
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password | tr -d '\n')

sed -i "s/127.0.0.1/0.0.0.0/" "/etc/mysql/mariadb.conf.d/50-server.cnf"

# Initialize database if the application database directory does not exist
if [ ! -d "/var/lib/mysql/${DB_NAME}" ]; then
	cat > /tmp/init.sql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

	# Start MariaDB with the init file so SQL runs on first boot
	exec mariadbd --user=mysql --datadir=/var/lib/mysql --init-file=/tmp/init.sql
fi

# Normal start
exec mariadbd --user=mysql --datadir=/var/lib/mysql