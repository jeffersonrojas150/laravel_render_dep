# Dockerfile

# --- Etapa 1: Builder ---
# Usamos una imagen oficial de PHP 8.2 con Composer
FROM composer:2 as builder

# Establecemos el directorio de trabajo
WORKDIR /app

# Copiamos solo los archivos de dependencias primero para aprovechar el cache de Docker
COPY composer.json composer.lock ./

# Instalamos las dependencias de producción sin scripts de dev
RUN composer install --no-interaction --no-plugins --no-scripts --no-dev --prefer-dist

# Copiamos el resto del código de la aplicación
COPY . .


# --- Etapa 2: Producción ---
# Usamos una imagen ligera de PHP-FPM con Alpine Linux
FROM php:8.2-fpm-alpine

# Instalamos paquetes necesarios del sistema (y Nginx)
# Y extensiones de PHP comunes para Laravel
RUN apk add --no-cache \
    nginx \
    supervisor \
    libzip-dev \
    libpng-dev \
    jpeg-dev \
    freetype-dev \
    oniguruma-dev \
    libxml2-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
    pdo_mysql \
    zip \
    gd \
    exif \
    bcmath \
    soap \
    pcntl

# Establecemos el directorio de trabajo
WORKDIR /var/www/html

# Copiamos los archivos de la aplicación desde la etapa 'builder'
COPY --from=builder /app .

# --- Bloque Corregido ---
# Creamos un .env temporal para que los comandos de artisan puedan ejecutarse
RUN cp .env.example .env
# Generamos una APP_KEY para el entorno de construcción
RUN php artisan key:generate
# Generamos los archivos optimizados AHORA que estamos en la ruta final
RUN php artisan route:cache && php artisan view:cache
# --- Fin del Bloque Corregido ---

# Copiamos las configuraciones personalizadas de Nginx y Supervisor
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Damos permisos correctos al directorio de la aplicación
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache && \
    chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Exponemos el puerto 8085 (Render usará este puerto internamente)
EXPOSE 8085

# El comando que se ejecutará al iniciar el contenedor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]