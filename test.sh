#!/bin/bash

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

echo -e "${GREEN}== Containers =="
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo -e "\n${GREEN}== Health =="
for container in mariadb wordpress nginx; do
    status=$(docker inspect -f '{{.State.Status}}, Healthy={{.State.Health.Status}}' "$container" 2>/dev/null)
    echo "$container: $status"
done

echo -e "\n${GREEN}== Domain =="
ping -c 2 falhaimo.42.fr

echo -e "\n${GREEN}== HTTP =="
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://falhaimo.42.fr

echo -e "\n${GREEN}== HTTPS =="
curl -sk -o /dev/null -w "HTTPS Status: %{http_code}\n" https://falhaimo.42.fr

echo -e "\n${GREEN}== Volumes =="
echo "WordPress files:"
docker exec wordpress ls -lh /var/www/html
echo -e "\nMariaDB files:"
docker exec mariadb ls -lh /var/lib/mysql

echo -e "\n${GREEN}== PHP-FPM =="
docker exec wordpress ps aux | grep php-fpm | grep -v grep

echo -e "\n${GREEN}== DB =="
# Check MariaDB health first
if [ "$(docker inspect -f '{{.State.Health.Status}}' mariadb)" != "healthy" ]; then
    echo -e "${RED}MariaDB is not healthy${NC}"
else
    docker exec mariadb sh -c "mysql -uroot -p\$MYSQL_ROOT_PASSWORD -e 'SHOW DATABASES;'" 2>/dev/null || \
    echo -e "${RED}DB check failed. Make sure DB_ROOT_PASSWORD is correct.${NC}"
fi

echo -e "\n${GREEN}== Nginx test =="
docker exec nginx nginx -t

