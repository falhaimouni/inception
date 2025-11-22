#!/bin/bash

if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
fi

# Start MariaDB temporarily to run commands
mysqld_safe --datadir=/var/lib/mysql &

# Wait for MariaDB to start
sleep 5

# Create database and user
mysql -e "CREATE DATABASE IF NOT EXISTS wordpress;"
mysql -e "CREATE USER IF NOT EXISTS 'wpuser'@'%' IDENTIFIED BY 'wppassword';"
mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'%';"
mysql -e "FLUSH PRIVILEGES;"

# Stop the temporary MariaDB instance
mysqladmin shutdown

# Start MariaDB in foreground
exec mysqld_safe --datadir=/var/lib/mysql
