FROM debian:bullseye

# Install PHP without specific version (will get the default)
RUN apt-get update && apt-get install -y \
    php-fpm \
    php-mysql \
    php-curl \
    php-gd \
    php-mbstring \
    php-xml \
    php-xmlrpc \
    php-soap \
    php-intl \
    php-zip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Copy WordPress from local directory
COPY wordpress/ /var/www/html/wordpress/

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html/wordpress

# Create PHP-FPM run directory
RUN mkdir -p /run/php

# Find and use the correct PHP version
RUN PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2) && \
    echo "Using PHP version: $PHP_VERSION"

# Copy PHP-FPM configuration to the correct location
COPY conf/www.conf /etc/php/*/fpm/pool.d/www.conf

EXPOSE 9000

# Use the discovered PHP-FPM version
CMD ["sh", "-c", "php-fpm$(php -r 'echo PHP_MAJOR_VERSION.\".\".PHP_MINOR_VERSION;') -F"]