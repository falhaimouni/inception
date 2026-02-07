# User Documentation

## Services provided
- NGINX: HTTPS reverse proxy (TLS 1.2/1.3)
- WordPress: CMS with php-fpm
- MariaDB: WordPress database

## Start and stop
- Start: `make up`
- Stop: `make down`
- Logs: `make logs`
- Status: `make ps`

## Access the website and admin panel
- Website: https://falhaimo.42.fr
- Admin panel: https://falhaimo.42.fr/wp-admin

## Credentials
- Stored as Docker secrets in srcs/secrets:
  - db_password.txt
  - db_root_password.txt
  - wp_admin_password.txt
- The .env file contains non-secret configuration values only.

## Verify services are running
- `make ps` should show mariadb, wordpress, and nginx as “Up”
- Check container logs: `make logs`
- Test HTTPS locally: `curl -k -I https://falhaimo.42.fr`
