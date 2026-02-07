FROM debian:bullseye

RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Create directory for certificates
RUN mkdir -p /etc/ssl/certs /etc/ssl/private && \
    chmod 700 /etc/ssl/private

# Copy initialization script that generates certificates
COPY tools/start.sh /usr/local/bin/start.sh

# Copy nginx configuration files
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/default.conf /etc/nginx/sites-available/default

# Enable the site by creating symlink
RUN mkdir -p /etc/nginx/sites-enabled && \
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default && \
    chmod +x /usr/local/bin/start.sh

EXPOSE 80 443

ENTRYPOINT ["/usr/local/bin/start.sh"]
