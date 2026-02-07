#!/bin/bash
echo "== Containers =="
docker ps

echo -e "\n== Health =="
docker inspect mariadb | grep Status

echo -e "\n== Domain =="
ping -c 1 falhaimo.42.fr

echo -e "\n== HTTP =="
curl -I http://falhaimo.42.fr

echo -e "\n== HTTPS =="
curl -k -I https://falhaimo.42.fr

echo -e "\n== Volumes =="
ls /home/$USER/data/wordpress
ls /home/$USER/data/mariadb

echo -e "\n== PHP-FPM =="
docker exec wordpress ps aux | grep php

echo -e "\n== DB =="
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES;" 2>/dev/null

echo -e "\n== Nginx test =="
docker exec nginx nginx -t

