# Inception Project - Evaluation Guide

## Table of Contents
1. [Project Overview](#project-overview)
2. [How to Run](#how-to-run)
3. [Evaluation Questions & Answers](#evaluation-questions--answers)
4. [Verification Steps](#verification-steps)
5. [Troubleshooting](#troubleshooting)

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
- Linux system with `/home/falhaimouni` directory accessible

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
mkdir -p /home/falhaimouni/data/db
mkdir -p /home/falhaimouni/data/wp
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
cd /home/falhaimouni/42_projects/inception
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
# Should show Mountpoint: /home/falhaimouni/data/wp

docker inspect inception_mariadb_vol
# Should show Mountpoint: /home/falhaimouni/data/db
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
- Username: `falhaimouni` (no "admin")
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

### Issue: "Volume mount fails: /home/falhaimouni/data/db not found"

**Solution:**
```bash
# Create directories
mkdir -p /home/falhaimouni/data/db
mkdir -p /home/falhaimouni/data/wp

# Fix permissions
sudo chown -R $USER:$USER /home/falhaimouni/data/
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

4. **Volume management**: Bind mounts store persistent data in `/home/falhaimouni/data/` on the host, not inside containers.

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
- [x] All volumes mounted to `/home/falhaimouni/data/`
- [x] No background processes in entrypoints
- [x] Admin user without "admin" keyword
- [x] Data persists after reboot

**Grade: 100/100** (Assuming all components work correctly during evaluation)

