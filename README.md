*This project has been created as part of the 42 curriculum by falhaimo.*

## Description
This project builds a small Docker-based infrastructure composed of NGINX (TLS), WordPress with php-fpm, and MariaDB. It demonstrates service isolation, networking, persistence, and secure configuration using environment variables and Docker secrets.

## Instructions
### Prerequisites
- Docker and Docker Compose installed
- A VM (required by the subject)
- Domain mapped to localhost: add `127.0.0.1 falhaimo.42.fr` to /etc/hosts

### Build and run
- Build and start: `make`
- Start only: `make up`
- Stop: `make down`
- Logs: `make logs`
- Status: `make ps`
- Full cleanup: `make fclean`

### Access
- Site: https://falhaimo.42.fr
- Admin panel: https://falhaimo.42.fr/wp-admin

## Project description and design choices
### Docker usage and sources
- Base images: Debian Bullseye
- Services: NGINX (TLS), WordPress (php-fpm), MariaDB
- Orchestration: docker-compose.yml + Makefile
- Persistence: Docker named volumes (`mariadb_vol`, `wordpress_vol`)
- Secrets: stored in `secrets/` and mounted via Docker secrets

### Comparisons
**Virtual Machines vs Docker**
- VMs emulate full OS stacks and are heavier; Docker containers share the host kernel, are lighter, and start faster.

**Secrets vs Environment Variables**
- Secrets keep sensitive values out of the environment and image layers; env vars are convenient but can leak through logs or process lists.

**Docker Network vs Host Network**
- Docker networks provide service discovery and isolation; host networking removes isolation and is forbidden in this project.

**Docker Volumes vs Bind Mounts**
- Volumes are managed by Docker and recommended for persistence; bind mounts are direct host paths and are forbidden for the required volumes here.

## Resources
- Docker Docs: https://docs.docker.com/
- Docker Compose: https://docs.docker.com/compose/
- NGINX: https://nginx.org/en/docs/
- MariaDB: https://mariadb.org/documentation/
- WordPress: https://wordpress.org/support/

### AI usage
AI was used to: scan configuration for compliance gaps, propose fixes for Docker secrets/volumes, and draft documentation structure. All changes were reviewed and tested locally.
