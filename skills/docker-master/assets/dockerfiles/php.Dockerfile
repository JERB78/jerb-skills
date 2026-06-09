# Production Dockerfile for PHP apps (Laravel, Symfony, plain PHP)
# Dockerfile productivo para apps PHP (Laravel, Symfony, PHP puro)
#
# Stack: PHP 8.4 FPM + nginx in one container (alternative: separate containers via compose)

# ============================================================================
# Stage 1: composer deps
# Etapa 1: deps de composer
# ============================================================================
FROM composer:2.8 AS composer-deps

WORKDIR /app

COPY composer.json composer.lock ./
# --no-scripts and --no-autoloader because we'll regenerate after copying source
# --no-scripts y --no-autoloader porque regeneramos luego de copiar source
RUN composer install --no-dev --no-scripts --no-autoloader --no-progress --prefer-dist

COPY . .
RUN composer dump-autoload --optimize --no-dev

# ============================================================================
# Stage 2: runtime (PHP-FPM + nginx)
# Etapa 2: runtime (PHP-FPM + nginx)
# ============================================================================
FROM php:8.4.1-fpm-alpine3.21 AS runtime

# Install nginx + PHP extensions commonly needed
# Instalar nginx + extensiones PHP comúnmente necesarias
RUN apk add --no-cache \
    nginx \
    supervisor \
    curl \
    && docker-php-ext-install \
        pdo \
        pdo_mysql \
        opcache \
    && rm -rf /var/cache/apk/*

# Production opcache config
# Config opcache de producción
COPY <<EOF /usr/local/etc/php/conf.d/opcache.ini
opcache.enable=1
opcache.memory_consumption=128
opcache.max_accelerated_files=10000
opcache.validate_timestamps=0
opcache.revalidate_freq=0
EOF

# nginx config — adjust to your app
# Config nginx — ajustar a tu app
COPY <<EOF /etc/nginx/http.d/default.conf
server {
    listen 8080 default_server;
    root /var/www/html/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \\.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\\.ht {
        deny all;
    }
}
EOF

# Supervisor to run nginx + php-fpm in same container
# Supervisor para correr nginx + php-fpm en mismo container
COPY <<EOF /etc/supervisord.conf
[supervisord]
nodaemon=true

[program:nginx]
command=nginx -g "daemon off;"
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stderr_logfile=/dev/stderr
stdout_logfile_maxbytes=0
stderr_logfile_maxbytes=0

[program:php-fpm]
command=php-fpm
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stderr_logfile=/dev/stderr
stdout_logfile_maxbytes=0
stderr_logfile_maxbytes=0
EOF

WORKDIR /var/www/html

COPY --from=composer-deps --chown=www-data:www-data /app /var/www/html

# Non-root: use built-in www-data user (UID 82 in alpine)
# Non-root: usar el user www-data integrado (UID 82 en alpine)
USER www-data

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

CMD ["supervisord", "-c", "/etc/supervisord.conf"]

LABEL org.opencontainers.image.title="My PHP App"
LABEL org.opencontainers.image.licenses="MIT"
