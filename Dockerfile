#!/bin/bash
FROM --platform=linux/amd64 php:8.1.0-fpm
WORKDIR /var/www

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    locales \
    zip \
    jpegoptim optipng pngquant gifsicle \
    vim \
    unzip \
    git \
    curl \
    libpq-dev \
    libssl-dev \
    libmemcached-dev

# Install extensions
RUN docker-php-ext-install pdo pdo_mysql pdo_pgsql
RUN apt-get install -y \
        libonig-dev \
    && docker-php-ext-install iconv mbstring
RUN apt-get install -y \
        libzip-dev \
        zlib1g-dev \
    && docker-php-ext-install zip
RUN docker-php-ext-install exif
RUN docker-php-ext-install pcntl
RUN apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php composer-setup.php
RUN php -r "unlink('composer-setup.php');"
RUN mv composer.phar /usr/local/bin/composer

ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_HOME /composer
ENV PATH $PATH:/composer/vendor/bin

# Install nodejs
RUN apt-get update &&\
    apt-get install -y --no-install-recommends gnupg &&\
    curl -sL https://deb.nodesource.com/setup_16.x | bash - &&\
    apt-get update &&\
    apt-get install -y --no-install-recommends nodejs &&\
    npm install --global gulp-cli cross-env

# Add user for laravel application
RUN groupadd -g 1000 www
RUN useradd -u 1000 -ms /bin/bash -g www www

# Permission
# RUN chown -R www-data:www-data /var/www
# Change current user to www
# USER www

COPY ./ /var/www
COPY ./composer.json /var/www/
COPY ./composer.lock /var/www/
COPY ./.env /var/www/.env

RUN cd /var/www
RUN composer install
RUN npm install
RUN npm run dev
RUN php artisan key:generate
RUN php artisan config:cache
RUN php artisan config:clear

# ADD ./ /var/www
# ADD ./public /var/www/html
# Add permission
RUN chmod -R 777 /var/www/bootstrap/cache \
 && chmod -R 777 /var/www/storage

# RUN composer dump-autoload
RUN composer dump-autoload

# Expose port 9000 and start php-fpm server
EXPOSE 9000
CMD ["php-fpm"]