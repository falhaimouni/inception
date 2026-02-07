# Developer Documentation

## Prerequisites
- Docker Engine + Docker Compose
- A VM (required by the subject)
- Host entry: `127.0.0.1 falhaimo.42.fr` in /etc/hosts

## Configuration files
- srcs/docker-compose.yml
- srcs/.env (non-secret variables)
- srcs/secrets/*.txt (passwords and sensitive data)

## Build and launch
- Full build and run: `make`
- Rebuild from scratch: `make re`
- Start only: `make up`
- Stop: `make down`

## Manage containers and volumes
- Status: `make ps`
- Logs: `make logs`
- Cleanup containers/images: `make clean`
- Full cleanup including volumes/data: `make fclean`

## Data persistence
- Named volumes map to host paths:
  - MariaDB: /home/falhaimo/data/mariadb
  - WordPress: /home/falhaimo/data/wordpress

## Service layout
- NGINX: TLS termination on port 443 only
- WordPress: php-fpm on port 9000 (internal)
- MariaDB: port 3306 (internal)
- Network: dedicated Docker network in docker-compose.yml
