# Inception Project - Evaluation Guide

## Table of Contents
1. [Project Overview](#project-overview)
2. [How to Run](#how-to-run)
3. [Implementation Details](#implementation-details)
4. [Evaluation Questions & Answers](#evaluation-questions--answers)
5. [Advanced Technical Questions](#advanced-technical-questions)
6. [Verification Steps](#verification-steps)
7. [Troubleshooting](#troubleshooting)

---

## Project Overview

This project sets up a complete Docker infrastructure with three interconnected services:
- **NGINX**: Reverse proxy with SSL/TLS termination
- **WordPress**: CMS with PHP-FPM backend
- **MariaDB**: Database server

All services communicate through a custom Docker bridge network and use persistent volumes for data.

### Project Structure

```
inception/
├── Makefile              # Builds and manages Docker containers
├── srcs/
│   ├── docker-compose.yml        # Service orchestration
│   ├── .env                       # Environment variables
│   └── requirements/
│       ├── nginx/
│       │   ├── Dockerfile
│       │   └── conf/default.conf
│       ├── wordpress/
│       │   ├── Dockerfile
│       │   └── tools/wordpress.sh
│       └── mariadb/
│           ├── Dockerfile
│           └── tools/mariadb.sh
├── secrets/              # Credentials (NOT in repo, created locally)
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── data/                 # Persistent volumes (created automatically)
    ├── db/
    └── wp/
```

---

## How to Run

### Prerequisites
- Docker and Docker Compose installed
- Linux system with `/home/falhaimo` directory accessible

### Step 1: Create Secrets (One-time Setup)

```bash
mkdir -p secrets
echo "wordpress_db_password" > secrets/db_password.txt
echo "mysql_root_password" > secrets/db_root_password.txt
echo "wp_admin_secure_password" > secrets/wp_admin_password.txt
echo "wp_user_secure_password" > secrets/wp_user_password.txt
```

### Step 2: Create Data Directories

```bash
mkdir -p /home/falhaimo/data/db
mkdir -p /home/falhaimo/data/wp
```

### Step 3: Start the Project

```bash
make
```

This command:
- Builds all Docker images (nginx, wordpress, mariadb)
- Creates the custom bridge network
- Starts all three containers
- Waits for services to be healthy

### Step 4: Access the Website

```bash
# Add to /etc/hosts (if testing locally)
echo "127.0.0.1 falhaimo.42.fr" | sudo tee -a /etc/hosts

# Open in browser
https://falhaimo.42.fr/
```

### Step 5: Stop the Project

```bash
make down
```

---


































## Implementation Details

### NGINX Implementation

#### Dockerfile Breakdown

```dockerfile
FROM debian:bookworm-slim

# Install NGINX and OpenSSL
RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Generate self-signed SSL certificate
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/nginx-selfsigned.key \
    -out /etc/ssl/certs/nginx-selfsigned.crt \
    -subj "/C=MA/ST=Khouribga/L=Khouribga/O=42/OU=1337/CN=falhaimo.42.fr"

# Copy custom NGINX configuration
COPY conf/default.conf /etc/nginx/sites-available/default

# Expose HTTPS port only
EXPOSE 443

# Run NGINX in foreground
CMD ["nginx", "-g", "daemon off;"]
```

**Key Implementation Points:**

1. **Base Image**: Uses `debian:bookworm-slim` (minimal Debian 12)
2. **SSL Certificate**: Self-signed with 365-day validity
3. **Configuration**: Custom `default.conf` handles routing and SSL
4. **Foreground Mode**: `-g daemon off;` keeps NGINX as PID 1
5. **Security**: Only port 443 exposed (HTTP handled by redirect)

#### NGINX Configuration Explained

```nginx
server {
    listen 80;
    server_name falhaimo.42.fr;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name falhaimo.42.fr;

    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    root /var/www/html;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
```

**Configuration Breakdown:**

1. **HTTP Redirect**: All port 80 traffic redirected to HTTPS (301)
2. **SSL Setup**: Points to self-signed certificate
3. **Protocol Versions**: Only TLSv1.2 and TLSv1.3 allowed
4. **PHP Processing**: Forwards `.php` files to WordPress container on port 9000
5. **Service Discovery**: Uses `wordpress:9000` (Docker DNS resolution)

---

### WordPress Implementation

#### Dockerfile Breakdown

```dockerfile
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    php-fpm \
    php-mysql \
    php-curl \
    php-gd \
    php-mbstring \
    php-xml \
    php-xmlrpc \
    php-zip \
    mariadb-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Download WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Configure PHP-FPM to listen on 0.0.0.0:9000
RUN sed -i 's|listen = /run/php/php.*-fpm.sock|listen = 9000|' /etc/php/*/fpm/pool.d/www.conf

WORKDIR /var/www/html

COPY tools/wordpress.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/wordpress.sh

EXPOSE 9000

CMD ["bash", "-c", "/usr/local/bin/wordpress.sh"]
```

**Key Implementation Points:**

1. **PHP Extensions**: All required WordPress extensions installed
2. **WP-CLI**: Command-line interface for WordPress management
3. **PHP-FPM Network Mode**: Configured to listen on TCP port 9000 (not Unix socket)
4. **MariaDB Client**: Allows database operations from WordPress container
5. **Initialization Script**: `wordpress.sh` handles WordPress setup

#### WordPress Setup Script Explained

```bash
#!/bin/bash

# Wait for MariaDB to be ready
# ✅ NOTICE: Using service name 'mariadb', NOT an IP address
while ! mariadb -h mariadb -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT 1" >/dev/null 2>&1; do
    echo "Waiting for MariaDB..."
    sleep 2
done

# Download WordPress if not present
if [ ! -f wp-config.php ]; then
    wp core download --allow-root
    
    # Create wp-config.php
    # ✅ CRITICAL: --dbhost=mariadb uses Docker DNS resolution
    wp config create \
        --dbname="$DB_NAME" \
        --dbuser="$DB_USER" \
        --dbpass="$DB_PASSWORD" \
        --dbhost=mariadb \
        --allow-root
    
    # Install WordPress
    wp core install \
        --url="$WP_URL" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --allow-root
    
    # Create additional user
    wp user create "$WP_USER" "$WP_USER_EMAIL" \
        --user_pass="$WP_USER_PASSWORD" \
        --role=author \
        --allow-root
fi

# Start PHP-FPM in foreground
exec php-fpm -F
```

**Script Logic:**

1. **Database Wait Loop**: Ensures MariaDB is ready before proceeding
2. **Idempotency**: Only installs WordPress if `wp-config.php` doesn't exist
3. **WP-CLI Operations**: Downloads core, creates config, installs WordPress
4. **User Creation**: Creates admin + additional user (no "admin" keyword)
5. **Process Management**: Uses `exec` to replace shell with PHP-FPM

---

### MariaDB Implementation

#### Dockerfile Breakdown

```dockerfile
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    mariadb-server \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Create directory for MariaDB run files
RUN mkdir -p /var/run/mysqld && \
    chown -R mysql:mysql /var/run/mysqld

COPY tools/mariadb.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/mariadb.sh

EXPOSE 3306

CMD ["bash", "-c", "/usr/local/bin/mariadb.sh"]
```

**Key Implementation Points:**

1. **MariaDB Server**: Full database server installation
2. **Runtime Directory**: Required for socket files and PID
3. **Permissions**: Ensures `mysql` user can write to run directory
4. **Initialization Script**: Handles database setup and user creation

#### MariaDB Setup Script Explained

```bash
#!/bin/bash

# Initialize MariaDB data directory if needed
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
    
    # Start temporary MariaDB instance
    mysqld --user=mysql --bootstrap << EOF
USE mysql;
FLUSH PRIVILEGES;

-- Set root password
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';

-- Create database
CREATE DATABASE IF NOT EXISTS ${DB_NAME};

-- Create user with access from any host
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';

-- Grant privileges
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';

FLUSH PRIVILEGES;
EOF
fi

# Start MariaDB in foreground
exec mysqld --user=mysql --bind-address=0.0.0.0
```

**Script Logic:**

1. **Data Directory Check**: Only initializes if database doesn't exist
2. **Bootstrap Mode**: Uses temporary instance for initial setup
3. **Root Password**: Sets password from Docker secret
4. **Database Creation**: Creates WordPress database
5. **User Management**: Creates user with remote access (`'%'` host)
6. **Network Binding**: Listens on all interfaces (`0.0.0.0`)
7. **Foreground Mode**: Uses `exec mysqld` to run as PID 1

---

### Docker Compose Configuration

```yaml
version: '3.8'

services:
  mariadb:
    build: ./requirements/mariadb
    container_name: mariadb
    volumes:
      - mariadb_vol:/var/lib/mysql
    networks:
      - network_1
    secrets:
      - db_password
      - db_root_password
    environment:
      DB_NAME: wordpress
      DB_USER: wordpress
      DB_PASSWORD_FILE: /run/secrets/db_password
      DB_ROOT_PASSWORD_FILE: /run/secrets/db_root_password
    healthcheck:
      test: ["CMD", "mariadb", "-u", "root", "-p$DB_ROOT_PASSWORD", "-e", "SELECT 1"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  wordpress:
    build: ./requirements/wordpress
    container_name: wordpress
    depends_on:
      mariadb:
        condition: service_healthy
    volumes:
      - wordpress_vol:/var/www/html
    networks:
      - network_1
    secrets:
      - db_password
      - wp_admin_password
      - wp_user_password
    environment:
      DB_NAME: wordpress
      DB_USER: wordpress
      DB_PASSWORD_FILE: /run/secrets/db_password
      WP_URL: https://falhaimo.42.fr
      WP_TITLE: "Inception"
      WP_ADMIN_USER: falhaimo
      WP_ADMIN_PASSWORD_FILE: /run/secrets/wp_admin_password
      WP_ADMIN_EMAIL: falhaimo@student.1337.ma
      WP_USER: contributor
      WP_USER_PASSWORD_FILE: /run/secrets/wp_user_password
      WP_USER_EMAIL: contributor@example.com
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "9000"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  nginx:
    build: ./requirements/nginx
    container_name: nginx
    depends_on:
      wordpress:
        condition: service_healthy
    volumes:
      - wordpress_vol:/var/www/html
    networks:
      - network_1
    ports:
      - "443:443"
    healthcheck:
      test: ["CMD", "curl", "-k", "-f", "https://localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  mariadb_vol:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/falhaimo/data/db
  wordpress_vol:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/falhaimo/data/wp

networks:
  network_1:
    driver: bridge

secrets:
  db_password:
    file: ../secrets/db_password.txt
  db_root_password:
    file: ../secrets/db_root_password.txt
  wp_admin_password:
    file: ../secrets/wp_admin_password.txt
  wp_user_password:
    file: ../secrets/wp_user_password.txt
```

**Configuration Breakdown:**

1. **Service Dependencies**: WordPress waits for MariaDB, NGINX waits for WordPress
2. **Health Checks**: Each service has custom health validation
3. **Volume Binding**: Uses bind mounts to specific host directories
4. **Network Isolation**: All services on custom bridge network
5. **Secrets Management**: Credentials passed as files (not env vars)
6. **Restart Policy**: `unless-stopped` ensures persistence across reboots

---

## Evaluation Questions & Answers

### **1. How Docker and docker-compose work**

**Q: Explain how Docker works.**

**A:** Docker is a containerization platform that packages applications and their dependencies into isolated containers. Each container runs on the same kernel but has its own filesystem, processes, and network namespace.

**Key points:**
- **Image**: A blueprint (like a class) defining the container
- **Container**: A running instance of an image
- **Dockerfile**: Instructions to build an image
- **Layers**: Each RUN/COPY command creates a new layer

In our project:
- We build 3 custom images from Dockerfiles
- Each image is built from `debian:bookworm-slim`
- Containers are isolated but communicate via network

**Q: Explain docker-compose.**

**A:** Docker Compose orchestrates multi-container applications using a `docker-compose.yml` file.

**Key features in our setup:**
- **Services**: Defines nginx, wordpress, mariadb containers
- **Networks**: Creates a custom bridge network for inter-service communication
- **Volumes**: Persists data across container restarts
- **Secrets**: Securely passes credentials to containers
- **Dependencies**: Ensures services start in correct order
- **Healthchecks**: Verifies services are ready before starting dependents

---

### **2. Docker Image vs Without Docker Compose**

**Q: What's the difference between a Docker image used with docker-compose vs without?**

**A:**

**Without docker-compose** (manual `docker run`):
```bash
docker run -d --name mariadb \
  -e DB_NAME=wordpress \
  -v mariadb_data:/var/lib/mysql \
  --network custom_network \
  mariadb:latest
```

**Problems:**
- Must manually create network first
- Must manage container order and dependencies
- Hard to restart entire stack
- Difficult to manage multiple containers

**With docker-compose**:
```bash
docker-compose up -d
```

**Benefits:**
- Single file manages entire infrastructure
- Automatic network creation
- Automatic dependency ordering
- Easy scaling and management
- Version controlled configuration

---

### **3. Docker Benefits vs Virtual Machines**

**Q: What are the benefits of Docker compared to VMs?**

**A:**

| Aspect | Docker | VM |
|--------|--------|-----|
| **Overhead** | Minimal (~MB) | Heavy (~GB) |
| **Boot Time** | Seconds | Minutes |
| **Resource Usage** | Shares kernel | Full OS per VM |
| **Isolation** | Process-level | Full system |
| **Portability** | Works anywhere | Hypervisor-dependent |
| **Density** | Hundreds per host | Few per host |

**In our project:**
- Each service is lightweight (~100-300MB)
- Can run all 3 containers on minimal hardware
- Startup time: ~10-15 seconds
- VMs would take 1-2 minutes per service

---

### **4. Directory Structure Relevance**

**Q: Why is the directory structure required this way?**

**A:**

```
inception/
├── srcs/                 ← All config files at root
│   ├── docker-compose.yml
│   ├── requirements/
│   │   ├── nginx/Dockerfile
│   │   ├── wordpress/Dockerfile
│   │   └── mariadb/Dockerfile
├── secrets/              ← Credentials separate from code
└── Makefile              ← Entry point for evaluation
```

**Rationale:**

1. **`srcs/` at root**: 
   - Evaluator expects all Docker files in one place
   - Clean separation from documentation
   - Easy to locate `docker-compose.yml`

2. **`requirements/` folder**:
   - Groups each service with its Dockerfile
   - Tools/scripts included in service folder
   - Parallels expected project structure

3. **`secrets/` separate**:
   - Prevents accidentally committing credentials
   - Evaluator understands where to place secrets
   - Security best practice

4. **`Makefile` at root**:
   - Evaluation runs `make` command
   - Must orchestrate entire project from one place

---

## Advanced Technical Questions

### **5. Networking Deep Dive**

**Q: How do the containers communicate with each other?**

**A:** Containers communicate through a **custom bridge network** named `network_1`.

**How it works:**

1. **Docker DNS**: Docker provides built-in DNS resolution
2. **Service Names as Hostnames**: 
   - `mariadb` resolves to MariaDB container IP
   - `wordpress` resolves to WordPress container IP
3. **Network Isolation**: Containers on this network can talk to each other but are isolated from other networks

**Example connections:**
```bash
# WordPress connects to MariaDB
mariadb -h mariadb -u wordpress -p

# NGINX forwards PHP to WordPress
fastcgi_pass wordpress:9000;
```

**⚠️ CRITICAL: Use Service Names, NOT IP Addresses**

**✅ CORRECT (Service Names):**
```bash
# In WordPress configuration
DB_HOST=mariadb

# In NGINX configuration
fastcgi_pass wordpress:9000;

# In WP-CLI commands
wp config create --dbhost=mariadb
```

**❌ WRONG (Hardcoded IPs):**
```bash
# DO NOT DO THIS
DB_HOST=192.168.91.3  # ❌ Evaluator will question this!
fastcgi_pass 172.18.0.3:9000;  # ❌ Architecturally weak
```

**Why service names are better:**
- **Dynamic**: IPs can change on container restart
- **Portable**: Works across different environments
- **Maintainable**: No need to track IPs manually
- **Docker Best Practice**: Leverages built-in DNS
- **Evaluation Requirement**: Evaluators expect this approach

**Network Verification:**
```bash
# Inside WordPress container
docker exec wordpress ping mariadb
# PING mariadb (172.18.0.2) 56(84) bytes of data.

# Check DNS resolution
docker exec wordpress nslookup mariadb
# Server: 127.0.0.11
# Address: 127.0.0.11#53
# 
# Non-authoritative answer:
# Name: mariadb
# Address: 172.18.0.2
```

---

**Q: Why use a custom bridge network instead of the default?**

**A:**

| Feature | Default Bridge | Custom Bridge |
|---------|----------------|---------------|
| **DNS Resolution** | ❌ No | ✅ Yes |
| **Isolation** | ❌ Shared | ✅ Per-network |
| **Container Links** | Manual `--link` | Automatic |
| **Best Practice** | Legacy | Modern |

**In our project:**
- Services communicate by name, not IP
- No need for deprecated `--link` flags
- Easy to add more services later
- Clear separation from other projects

---

**Q: CRITICAL - How do you configure WordPress to connect to MariaDB? Show me the exact configuration.**

**A:** **This is a common evaluation trap!**

**✅ CORRECT Configuration:**

```bash
# In wordpress.sh script (using WP-CLI)
wp config create \
    --dbname="$DB_NAME" \
    --dbuser="$DB_USER" \
    --dbpass="$DB_PASSWORD" \
    --dbhost=mariadb \                    # ← Service name!
    --allow-root
```

**Or in wp-config.php:**
```php
define('DB_HOST', 'mariadb');  // ✅ Service name
```

**❌ WRONG - What NOT to do:**
```php
define('DB_HOST', '192.168.91.3');  // ❌ Hardcoded IP
define('DB_HOST', '172.18.0.2');    // ❌ Will break on restart
define('DB_HOST', 'localhost');     // ❌ Wrong - MariaDB is in different container
```

**Why this matters:**
1. Docker's internal DNS automatically resolves `mariadb` to the correct IP
2. IP addresses can change when containers restart
3. Service names work across any Docker environment
4. **Evaluators specifically check for this** - it's a sign you understand Docker networking

**Verification:**
```bash
# Check your wp-config.php
docker exec wordpress grep DB_HOST /var/www/html/wp-config.php
# Should output: define('DB_HOST', 'mariadb');

# Test DNS resolution
docker exec wordpress nslookup mariadb
# Should resolve to container IP

# Test connection using service name
docker exec wordpress mariadb -h mariadb -u wordpress -p
# Should connect successfully
```

---

### **6. Volume Management**

**Q: Explain the difference between named volumes and bind mounts.**

**A:**

**Named Volumes** (Docker-managed):
```yaml
volumes:
  - mariadb_data:/var/lib/mysql
```
- Managed by Docker
- Stored in `/var/lib/docker/volumes/`
- Cannot choose exact location

**Bind Mounts** (Host-managed):
```yaml
volumes:
  mariadb_vol:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/falhaimo/data/db
```
- Mounts specific host directory
- Full control over location
- Required for project (must be in `/home/<user>/data/`)

---

**Q: What happens to data when containers are removed?**

**A:**

```bash
# Remove containers (data PERSISTS)
docker compose down

# Remove containers AND volumes (data LOST)
docker compose down -v
```

**Volume persistence:**
- Data in `/home/falhaimo/data/db` and `/home/falhaimo/data/wp` survives container deletion
- Even after `docker system prune`, bind mount data remains
- Survives host reboots
- Only lost if manually deleted from host filesystem

---

### **7. Dockerfile Best Practices**

**Q: Why combine RUN commands with && instead of multiple RUN statements?**

**A:**

**Bad (Multiple layers):**
```dockerfile
RUN apt-get update
RUN apt-get install -y nginx
RUN apt-get install -y openssl
RUN rm -rf /var/lib/apt/lists/*
```
- Creates 4 image layers
- Each layer adds to image size
- Cleanup in last RUN doesn't reduce size

**Good (Single layer):**
```dockerfile
RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/*
```
- Creates 1 image layer
- Cleanup in same layer reduces final size
- Faster builds (fewer layers to cache)

---

**Q: What is the purpose of `rm -rf /var/lib/apt/lists/*`?**

**A:** Reduces image size by removing APT package cache.

**Without cleanup:**
- APT stores package lists in `/var/lib/apt/lists/`
- Can be 100-200 MB
- Not needed after installation

**With cleanup:**
- Image size reduced significantly
- Still can run `apt-get update` later if needed

---

### **8. Container Process Management**

**Q: Why use `exec` in shell scripts? What's the difference?**

**A:**

**Without exec:**
```bash
#!/bin/bash
php-fpm -F  # Shell (PID 1), PHP-FPM (PID 2)
```
- Shell process remains as PID 1
- PHP-FPM runs as child process
- Signals (SIGTERM) go to shell, not PHP-FPM
- Container shutdown hangs (waits for timeout)

**With exec:**
```bash
#!/bin/bash
exec php-fpm -F  # PHP-FPM replaces shell, becomes PID 1
```
- Shell replaced by PHP-FPM
- PHP-FPM is PID 1
- Signals go directly to PHP-FPM
- Clean shutdown

**Verification:**
```bash
# Check what's running as PID 1
docker exec wordpress ps aux
# USER       PID  COMMAND
# www-data     1  php-fpm: master process
```

---

**Q: What does "daemon off" mean in NGINX?**

**A:**

**Default NGINX behavior:**
- Runs as background daemon (daemonizes)
- Parent process exits after spawning worker
- Docker thinks container stopped

**With `daemon off;`:**
```dockerfile
CMD ["nginx", "-g", "daemon off;"]
```
- NGINX stays in foreground
- Remains as PID 1
- Docker can monitor the process

**Applies to:**
- NGINX: `daemon off;`
- PHP-FPM: `-F` flag
- MariaDB: `mysqld` (already foreground by default)

---

### **9. Security Considerations**

**Q: Why use Docker secrets instead of environment variables?**

**A:**

**Environment Variables (Less Secure):**
```yaml
environment:
  DB_PASSWORD: "my_secret_password"  # ❌ Visible in docker inspect
```
- Visible in `docker inspect`
- Logged in shell history
- Accidentally committed to git
- Stored in process environment

**Docker Secrets (More Secure):**
```yaml
secrets:
  - db_password  # ✅ Mounted as file in /run/secrets/
```
- Not visible in `docker inspect`
- Files stored in tmpfs (RAM only)
- Never written to disk
- Not in environment variables

**Reading secrets in scripts:**
```bash
# Bad: Direct env var
DB_PASSWORD="$DB_PASSWORD"

# Good: Read from secret file
DB_PASSWORD=$(cat /run/secrets/db_password)
# or
DB_PASSWORD=$(cat "$DB_PASSWORD_FILE")
```

---

**Q: What are the security implications of binding to 0.0.0.0?**

**A:**

**MariaDB binding:**
```bash
mysqld --bind-address=0.0.0.0
```
- Listens on all network interfaces
- Allows connections from any container on the network
- **Safe in our case** because:
  1. Network is isolated (custom bridge)
  2. Only our containers can access it
  3. Not exposed to host or internet

**Port publishing:**
```yaml
ports:
  - "443:443"  # Only NGINX exposed to host
```
- Only NGINX port 443 published to host
- MariaDB port 3306 NOT published (internal only)
- WordPress port 9000 NOT published (internal only)

---

### **10. Health Checks Deep Dive**

**Q: Why are health checks important? What happens without them?**

**A:**

**Without health checks:**
```yaml
depends_on:
  - mariadb  # Waits for container START, not READY
```
- WordPress starts as soon as MariaDB container starts
- MariaDB might not be accepting connections yet
- WordPress connection fails
- WordPress crashes or waits forever

**With health checks:**
```yaml
depends_on:
  mariadb:
    condition: service_healthy  # Waits for HEALTHY status
```
- WordPress waits until MariaDB passes health check
- Health check verifies database is actually ready
- Proper startup sequence guaranteed

**Health check examples:**

1. **MariaDB**: Try database connection
```yaml
healthcheck:
  test: ["CMD", "mariadb", "-u", "root", "-p$DB_ROOT_PASSWORD", "-e", "SELECT 1"]
```

2. **WordPress**: Check if PHP-FPM is listening
```yaml
healthcheck:
  test: ["CMD", "nc", "-z", "localhost", "9000"]
```

3. **NGINX**: Try HTTPS request
```yaml
healthcheck:
  test: ["CMD", "curl", "-k", "-f", "https://localhost"]
```

---

### **11. SSL/TLS Implementation**

**Q: Explain the SSL certificate generation command.**

**A:**

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/nginx-selfsigned.key \
    -out /etc/ssl/certs/nginx-selfsigned.crt \
    -subj "/C=MA/ST=Khouribga/L=Khouribga/O=42/OU=1337/CN=falhaimo.42.fr"
```

**Flag breakdown:**
- `req`: Certificate request utility
- `-x509`: Output self-signed certificate (not a request)
- `-nodes`: No DES encryption for private key (no passphrase)
- `-days 365`: Valid for 1 year
- `-newkey rsa:2048`: Generate 2048-bit RSA key pair
- `-keyout`: Where to save private key
- `-out`: Where to save certificate
- `-subj`: Certificate subject (avoids interactive prompts)
  - `CN=falhaimo.42.fr`: Common Name (domain name)

---

**Q: What's the difference between TLSv1.2 and TLSv1.3?**

**A:**

| Feature | TLSv1.2 | TLSv1.3 |
|---------|---------|----------|
| **Handshake** | 2 round trips | 1 round trip |
| **Speed** | Slower | Faster |
| **Security** | Good | Better |
| **Cipher Suites** | Many (some weak) | Only strong ciphers |
| **Forward Secrecy** | Optional | Always |

**In our NGINX config:**
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```
- Supports both for compatibility
- Clients can negotiate which to use
- TLSv1.0 and TLSv1.1 disabled (insecure)

---

### **12. WordPress-Specific Questions**

**Q: Why use WP-CLI instead of manual installation?**

**A:**

**Manual installation:**
- Download zip file
- Extract files
- Edit wp-config.php manually
- Visit installation page in browser
- Fill out form
- Create users manually

**WP-CLI automation:**
```bash
wp core download --allow-root
wp config create --dbname="wordpress" --dbuser="wordpress" --allow-root
wp core install --url="https://falhaimo.42.fr" --allow-root
wp user create contributor contributor@example.com --allow-root
```

**Benefits:**
- Fully automated (no manual steps)
- Reproducible (same result every time)
- No browser interaction needed
- Can script additional setup
- Idempotent (safe to run multiple times)

---

**Q: Why does NGINX share the WordPress volume?**

**A:**

```yaml
nginx:
  volumes:
    - wordpress_vol:/var/www/html  # Same volume as WordPress

wordpress:
  volumes:
    - wordpress_vol:/var/www/html
```

**Reason:**
- NGINX serves static files (CSS, JS, images)
- PHP-FPM only processes `.php` files
- NGINX needs access to WordPress files to serve static content

**Request flow:**

1. **Static file (e.g., `style.css`):**
   - Browser → NGINX
   - NGINX reads file directly from `/var/www/html/`
   - NGINX → Browser

2. **PHP file (e.g., `index.php`):**
   - Browser → NGINX
   - NGINX → WordPress (FastCGI)
   - PHP-FPM processes script
   - WordPress → NGINX
   - NGINX → Browser

---

### **13. Makefile and Orchestration**

**Q: What does the Makefile do? Walk through the process.**

**A:**

```makefile
all: build up

build:
	@docker compose -f srcs/docker-compose.yml build

up:
	@docker compose -f srcs/docker-compose.yml up -d
	@echo "Waiting for services to be healthy..."
	@docker compose -f srcs/docker-compose.yml ps

down:
	@docker compose -f srcs/docker-compose.yml down

clean: down
	@docker system prune -af
	@docker volume rm $$(docker volume ls -q) 2>/dev/null || true

re: clean all
```

**Execution flow of `make`:**

1. **Build Phase:**
   - Reads all Dockerfiles
   - Executes RUN commands
   - Creates image layers
   - Tags images: `inception-mariadb`, `inception-wordpress`, `inception-nginx`

2. **Up Phase:**
   - Creates network `inception_network_1`
   - Creates volumes (binds to host directories)
   - Starts MariaDB container
   - Waits for MariaDB health check to pass
   - Starts WordPress container
   - Waits for WordPress health check to pass
   - Starts NGINX container
   - Waits for NGINX health check to pass

3. **Ready:**
   - All services running and healthy
   - Can access https://falhaimo.42.fr/

---

### **14. Troubleshooting Process**

**Q: If WordPress can't connect to MariaDB, how would you debug?**

**A:** Systematic debugging approach:

**Step 1: Check if MariaDB is running**
```bash
docker compose -f srcs/docker-compose.yml ps
# Should show mariadb as "healthy"
```

**Step 2: Check MariaDB logs**
```bash
docker logs mariadb
# Look for: "mysqld: ready for connections"
```

**Step 3: Test network connectivity**
```bash
# Can WordPress ping MariaDB?
docker exec wordpress ping mariadb

# Can WordPress resolve DNS?
docker exec wordpress nslookup mariadb
```

**Step 4: Test database connection**
```bash
# Try connecting manually
docker exec wordpress mariadb -h mariadb -u wordpress -p
# Enter password from secrets/db_password.txt
```

**Step 5: Check credentials**
```bash
# Verify secret files exist
ls -la secrets/

# Check content (should not have newlines/spaces)
cat secrets/db_password.txt | od -c
```

**Step 6: Verify MariaDB user permissions**
```bash
docker exec mariadb mariadb -u root -p$(cat secrets/db_root_password.txt) -e \
  "SELECT user, host FROM mysql.user WHERE user='wordpress';"

# Should show: wordpress | %
```

**Common issues:**
- Secret file has trailing newline
- Wrong environment variable names
- MariaDB not binding to 0.0.0.0
- User doesn't have '%' host (only 'localhost')

---

## Verification Steps

### Step 1: Pre-Evaluation Cleanup

```bash
docker stop $(docker ps -qa) 2>/dev/null || true
docker rmi -f $(docker images -qa) 2>/dev/null || true
docker volume rm $(docker volume ls -q) 2>/dev/null || true
docker network rm $(docker network ls -q) 2>/dev/null || true
```

### Step 2: Run Make

```bash
cd /home/falhaimo/42_projects/inception
make
```

**Expected output:**
```
Building mariadb...
Building wordpress...
Building nginx...
Starting services...
All services are healthy!
```

### Step 3: Verify Docker Network

```bash
docker network ls
# Should show "network_1" with bridge driver

docker network inspect inception_network_1
# Should show 3 containers connected
```

### Step 4: Verify Containers Are Running

```bash
docker compose -f srcs/docker-compose.yml ps
```

**Expected output:**
```
NAME        COMMAND                 STATUS
mariadb     "bash -c ./mariadb.sh"  healthy
wordpress   "bash -c ./wordpress.sh" healthy
nginx       "nginx -g daemon off;"  healthy
```

### Step 5: Test NGINX HTTP→HTTPS Redirect

```bash
# Should redirect to HTTPS
curl -I http://localhost/

# Expected: 301 redirect to https://
```

### Step 6: Test HTTPS Access

```bash
# Access WordPress over HTTPS
curl -k https://falhaimo.42.fr/ | grep -q "wordpress"

# Should return WordPress HTML (ignore self-signed cert warning with -k)
```

### Step 7: Verify SSL/TLS Certificate

```bash
openssl s_client -connect localhost:443 -showcerts < /dev/null 2>/dev/null | grep -A 5 "Certificate:"
```

**Should show:**
- TLSv1.2 or TLSv1.3
- Self-signed certificate
- Valid dates

### Step 8: Verify Volumes

```bash
docker volume ls

# Should show:
# inception_mariadb_vol
# inception_wordpress_vol

docker inspect inception_wordpress_vol
# Should show Mountpoint: /home/falhaimo/data/wp

docker inspect inception_mariadb_vol
# Should show Mountpoint: /home/falhaimo/data/db
```

### Step 9: Test WordPress Installation

**Access via browser:**
```
https://falhaimo.42.fr/
```

**Expected:**
- No installation page (already configured)
- WordPress homepage loads
- Self-signed certificate warning (click "Proceed")

**Login with admin credentials:**
- URL: `https://falhaimo.42.fr/wp-login.php`
- Username: `falhaimo` (no "admin")
- Password: (from secrets/wp_admin_password.txt)

### Step 10: Test Database Connectivity

```bash
# Login to MariaDB container
docker exec -it mariadb mariadb -u wordpress -p$(cat secrets/db_password.txt) wordpress

# Try a query
SHOW TABLES;

# Should show WordPress tables:
# wp_posts, wp_users, wp_options, etc.
```

### Step 11: Test WordPress Functionality

1. **Add a comment:**
   - Go to a WordPress post
   - Post a test comment
   - Refresh page - comment should appear

2. **Edit a page:**
   - Go to admin dashboard
   - Edit a page
   - Add some text
   - Publish
   - View on frontend - changes should appear

### Step 12: Test Persistence (Reboot)

```bash
# Reboot the virtual machine
sudo reboot

# After reboot, start containers again
make

# Verify:
# 1. WordPress data is still there
# 2. Posts/comments from step 11 still exist
# 3. MariaDB shows same data
```

---

## Troubleshooting

### Issue: "docker-compose not found"

**Solution:**
```bash
# Install docker-compose
sudo apt-get install docker-compose

# Or use newer syntax
docker compose instead of docker-compose
```

### Issue: "Cannot connect to Docker daemon"

**Solution:**
```bash
# Start Docker service
sudo systemctl start docker

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### Issue: "Volume mount fails: /home/falhaimo/data/db not found"

**Solution:**
```bash
# Create directories
mkdir -p /home/falhaimo/data/db
mkdir -p /home/falhaimo/data/wp

# Fix permissions
sudo chown -R $USER:$USER /home/falhaimo/data/
```

### Issue: "WordPress shows installation page"

**Solution:**
- Verify `WP_HOME` and `WP_SITEURL` are set in wp-config.php
- Check WordPress container logs:
  ```bash
  docker logs wordpress
  ```
- Verify database connection:
  ```bash
  docker exec wordpress wp core is-installed --allow-root
  ```

### Issue: "SSL certificate warnings in browser"

**This is expected!** The certificate is self-signed. The evaluation accepts this:
> "A warning for a self-signed certificate may appear."

Click "Proceed" or "Accept Risk and Continue" in your browser.

### Issue: "PHP-FPM connection refused"

**Solution:**
```bash
# Check if PHP-FPM is listening on port 9000
docker exec wordpress nc -z localhost 9000

# Check logs
docker logs wordpress

# Verify php-fpm is running in foreground
docker exec wordpress ps aux | grep php-fpm
```

### Issue: "MariaDB won't connect"

**Solution:**
```bash
# Check MariaDB logs
docker logs mariadb

# Verify credentials
docker exec mariadb mariadb -u root -p$(cat secrets/db_root_password.txt) -e "SHOW DATABASES;"

# Check network connectivity
docker exec wordpress ping mariadb
```

---

## Defense Talking Points

### Explain Docker & docker-compose (2-3 min)

> "Docker is containerization technology that packages an application with all its dependencies. Docker Compose orchestrates multiple containers using a YAML configuration file. In this project, I have three services - NGINX for reverse proxy with SSL/TLS, WordPress for the CMS with PHP-FPM, and MariaDB for the database. They communicate through a custom bridge network and persist data using volumes."

### Explain Project Structure (2 min)

> "The project structure follows the evaluation requirements. All configuration is in the `srcs/` folder at the root. Each service has its own Dockerfile in the `requirements/` subdirectory. The `Makefile` at the root orchestrates everything. Secrets are stored separately and are not committed to git."

### Explain Key Design Decisions (2-3 min)

1. **No background processes**: All containers run processes in foreground mode using `exec` and appropriate flags (`php-fpm -F`, `nginx -g daemon off;`, etc.)

2. **Health checks**: Each service has healthchecks to ensure startup order. WordPress and NGINX only start after their dependencies are ready.

3. **Custom network**: Using a bridge network instead of links or host networking. Services communicate by name: `wordpress:9000`, `mariadb:3306`.

4. **Volume management**: Bind mounts store persistent data in `/home/falhaimo/data/` on the host, not inside containers.

5. **Secrets management**: Using Docker Secrets for credentials, not environment variables.

6. **SSL/TLS**: Self-signed certificate valid for 365 days, supporting TLSv1.2 and TLSv1.3.

### Handle Questions About Scripts

**If asked: "Why use exec in the entrypoint scripts?"**

> "The `exec` keyword replaces the shell process with the actual service process. This ensures the service receives signals properly and is PID 1 in the container. If we ran the command without `exec`, the shell would be PID 1, and stopping the container would require waiting for the timeout."

**If asked: "Why use -F flag for PHP-FPM?"**

> "The `-F` flag keeps PHP-FPM in foreground mode instead of daemonizing it. Docker expects the main process to run in foreground; if PHP-FPM daemonizes, the container thinks the service stopped and exits."

---

## Quick Reference Commands

```bash
# Build and start
make

# View logs
docker compose -f srcs/docker-compose.yml logs -f [service]

# Execute command in container
docker exec -it [container_name] [command]

# Stop all services
make down

# Clean everything
docker compose -f srcs/docker-compose.yml down -v

# Check service health
docker compose -f srcs/docker-compose.yml ps

# View network
docker network inspect inception_network_1

# Check volumes
docker volume ls
docker inspect [volume_name]
```

---

## Expected Evaluation Outcome

✅ **Mandatory Requirements (Will Pass)**
- [x] Docker and docker-compose explained
- [x] NGINX only on port 443 (HTTP→HTTPS redirect)
- [x] SSL/TLS certificate (TLSv1.2/1.3)
- [x] WordPress installed and accessible
- [x] No pre-made images
- [x] Custom bridge network
- [x] All volumes mounted to `/home/falhaimo/data/`
- [x] No background processes in entrypoints
- [x] Admin user without "admin" keyword
- [x] Data persists after reboot

**Grade: 100/100** (Assuming all components work correctly during evaluation)

---

## Additional Evaluation Topics

### Understanding Container Lifecycle

**Q: What's the container lifecycle? Walk through what happens with `make`.**

**A:**

```
[IMAGE BUILD]
     ↓
[CREATE] → [RUNNING] → [EXITED]
     ↑         ↓           ↓
     ←────[RESTART]────────┘
```

**With our project:**

1. **Build**: `docker compose build`
   - Creates images from Dockerfiles
   - Images stored in Docker daemon

2. **Create**: `docker compose up -d` (first time)
   - Creates containers from images
   - Creates network
   - Creates/mounts volumes
   - Container state: Created (not running yet)

3. **Start**: Automatic after create
   - Runs CMD/ENTRYPOINT from Dockerfile
   - Container state: Running
   - Health checks begin

4. **Stop**: `docker compose down`
   - Sends SIGTERM to PID 1
   - Waits 10 seconds
   - Sends SIGKILL if still running
   - Container state: Exited

5. **Remove**: Part of `docker compose down`
   - Deletes container
   - Keeps volumes (unless `-v` flag)
   - Keeps images (unless `docker image rm`)

---

### Resource Management

**Q: How much disk space does this project use?**

**A:**

```bash
# Check image sizes
docker images | grep inception

# Typical sizes:
# inception-mariadb    ~400 MB
# inception-wordpress  ~350 MB
# inception-nginx      ~150 MB
# Total images:        ~900 MB

# Check volume sizes
du -sh /home/falhaimo/data/db   # ~100 MB (grows with data)
du -sh /home/falhaimo/data/wp   # ~50 MB (WordPress files)
```

**Q: Can you limit container resources?**

**A:** Yes, docker-compose supports resource limits:

```yaml
services:
  mariadb:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          memory: 256M
```

---

### Common Pitfalls During Evaluation

**1. Hardcoding IP addresses instead of using service names:**
```bash
# ❌ WRONG - Evaluator will catch this immediately!
DB_HOST=192.168.91.3

# ✅ CORRECT - Use Docker DNS
DB_HOST=mariadb

# How to check your configuration:
docker exec wordpress cat /var/www/html/wp-config.php | grep DB_HOST
# Should output: define('DB_HOST', 'mariadb');
```

**Why this is critical:**
- Evaluators specifically look for this
- Shows you understand Docker networking
- Hardcoded IPs indicate you don't trust Docker DNS
- IPs will break when containers are recreated

**2. Wrong domain name:**
```bash
# Check /etc/hosts
cat /etc/hosts | grep falhaimo
# Should show: 127.0.0.1 falhaimo.42.fr
```

**3. Port conflicts:**
```bash
# Check if port 443 is already used
sudo netstat -tlnp | grep :443
# Should be empty, or show nginx from this project
```

**4. Permission issues:**
```bash
# Data directories must be accessible
ls -la /home/falhaimo/data/
# Should show: drwxr-xr-x user user
```

**5. Old containers still running:**
```bash
# Clean slate
docker stop $(docker ps -qa) 2>/dev/null || true
docker rm $(docker ps -qa) 2>/dev/null || true
make
```

**6. Secret files with wrong encoding:**
```bash
# Check for hidden characters
cat -A secrets/db_password.txt
# Should NOT show: password$
# Should show: password

# Fix if needed
tr -d '\n' < secrets/db_password.txt > secrets/db_password.tmp
mv secrets/db_password.tmp secrets/db_password.txt
```

---

## Performance Considerations

**Q: How can you optimize container startup time?**

**A:**

1. **Multi-stage builds** (not used in this project):
```dockerfile
FROM debian:bookworm as builder
RUN apt-get update && apt-get install -y build-tools
COPY . /app
RUN make

FROM debian:bookworm-slim
COPY --from=builder /app/binary /app/
```

2. **Layer caching**:
- Put infrequently changing commands first
- Copy dependency files before source code

3. **Reduce image size**:
- Use `-slim` base images ✅ (we do this)
- Remove package cache ✅ (we do this)
- Combine RUN commands ✅ (we do this)

4. **Health check intervals**:
```yaml
healthcheck:
  interval: 10s     # Check every 10 seconds
  timeout: 5s       # Wait max 5 seconds
  retries: 5        # Try 5 times before failing
  start_period: 30s # Grace period for slow starts
```

---

## Real-World Production Considerations

**Q: What would you change for production use?**

**A:**

1. **SSL Certificate**:
   - Use Let's Encrypt (not self-signed)
   - Auto-renewal with certbot

2. **Secrets Management**:
   - Use Docker Swarm secrets or Kubernetes secrets
   - Or external: AWS Secrets Manager, HashiCorp Vault

3. **Logging**:
   - Centralized logging (ELK stack)
   - Log aggregation

4. **Monitoring**:
   - Prometheus + Grafana
   - Health check endpoints

5. **Backups**:
   - Automated database backups
   - Offsite storage

6. **High Availability**:
   - Multiple WordPress instances (load balanced)
   - MariaDB replication
   - Redis cache

7. **Security**:
   - Run containers as non-root
   - Use security scanning (Trivy, Clair)
   - Network policies
   - Read-only root filesystem where possible

8. **CI/CD**:
   - Automated testing
   - Container image scanning
   - Rolling updates

---

## Quick Mental Model

**Think of it as a house:**

- **Dockerfile** = Blueprint (how to build a room)
- **Image** = Prefab room (can create many instances)
- **Container** = Actual room in the house
- **Volume** = Storage unit (persists after room demolished)
- **Network** = Hallways (rooms communicate through them)
- **docker-compose.yml** = House plan (all rooms and connections)

**Our house has 3 rooms:**
1. **MariaDB** = Storage room (database)
2. **WordPress** = Living room (where work happens)
3. **NGINX** = Front door (only entry point from outside)

**They share:**
- Common hallway (network)
- Shared storage (WordPress volume)
- Private storage (MariaDB volume)

