FROM debian:bullseye

RUN apt-get update && apt-get install -y \
    php7.4-fpm \
    php7.4-mysql \
    php7.4-curl \
    php7.4-gd \
    php7.4-mbstring \
    php7.4-xml \
    php7.4-xmlrpc \
    php7.4-soap \
    php7.4-intl \
    php7.4-zip \
    php7.4-cli \
    curl \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Install WP-CLI for WordPress management
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

WORKDIR /var/www/html

# Copy WordPress files
COPY wordpress/ /var/www/html/

# Copy PHP-FPM configuration
COPY conf/www.conf /etc/php/7.4/fpm/pool.d/www.conf

# Copy initialization script
COPY tools/start.sh /usr/local/bin/start.sh

# Create PHP-FPM run directory and set permissions
RUN mkdir -p /run/php && \
    chown -R www-data:www-data /var/www/html && \
    chown -R www-data:www-data /run/php && \
    chmod +x /usr/local/bin/start.sh

# Copy WordPress files to a temporary location for the startup script to deploy
COPY wordpress/ /tmp/wordpress-install/

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/start.sh"]