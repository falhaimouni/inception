#!/bin/bash

# Start PHP-FPM in background
php-fpm7.4 -D

# Wait a moment for PHP-FPM to start
sleep 2

# Check if PHP-FPM is running
if ! pgrep "php-fpm" > /dev/null; then
    echo "PHP-FPM failed to start"
    exit 1
fi

# Keep the container running
tail -f /dev/null
