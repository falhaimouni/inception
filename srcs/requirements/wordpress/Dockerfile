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
    && rm -rf /var/lib/apt/lists/*

# Copy WordPress from local directory
COPY wordpress/ /var/www/html/wordpress/

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html/wordpress

# Create PHP-FPM run directory
RUN mkdir -p /run/php && chown www-data:www-data /run/php

# Ensure PHP-FPM listens on all interfaces
RUN sed -i 's/^listen = .*/listen = 0.0.0.0:9000/' /etc/php/7.4/fpm/pool.d/www.conf

# Copy our custom PHP-FPM configuration
COPY conf/www.conf /etc/php/7.4/fpm/pool.d/www.conf

EXPOSE 9000

# Start PHP-FPM in foreground mode
CMD ["php-fpm7.4", "-F", "-R"]