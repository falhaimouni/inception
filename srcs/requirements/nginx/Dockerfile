FROM debian:bullseye

# install nginx and openssl packages 
# nginx : web server that will handle HTTP/HTTPS requests 
# openssl : Toolkit for creating SSL/TLS certificates 
RUN apt-get update && apt-get install -y \
	nginx \
	openssl \
	&& rm -rf /var/lib/apt/lists/*

# Create SSL certificate and private key
RUN openssl req -newkey rsa:4096 -x509 -sha256 -days 365 -nodes \
	-out /etc/ssl/certs/inception.crt \
	-keyout /etc/ssl/private/inception.key \
	-subj "/C=US/ST=State/L=City/O=42/OU=School/CN=localhost"

# Copy custom nginx configuration file to enable SSL
# Copies your custom nginx.conf file from your local machine into the container
COPY conf/nginx.conf /etc/nginx/nginx.conf

# Expose ports 80 (HTTP) and 443 (HTTPS)
EXPOSE 80 443

# Start nginx in the foreground when the container launches
# -g "daemon off;" - Critical Docker option that runs NGINX in 
# foreground mode so the container doesn't exit immediately
CMD ["nginx", "-g", "daemon off;"]
