FROM debian:bullseye

# install nginx and openssl packages 
# nginx : web server that will handle HTTP/HTTPS requests 
# openssl : Toolkit for creating SSL/TLS certificates 
RUN apt-get update && apt-get install -y \
	nginx \
	openssl \
	&& rm -rf /var/lib/apt/lists/*

# Create SSL certificate 
RUN openssl req -newkey rsa:4096 -x509 -sha256 -days 365 -nodes \
	-out /etc/ssl/certs/inception.crt \
	-keyout /etc/ssl/private/inception.key \
	-subj "/C=US/ST=State/L=City/0=42/OU=School/CN=localhost"
