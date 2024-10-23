FROM node:19.9.0-alpine AS node

# Base image with PHP-FPM
FROM php:8.3.13RC1-fpm-alpine3.20 AS base

# Musl for adding locales
ENV MUSL_LOCALE_DEPS="cmake make musl-dev gcc gettext-dev libintl"
ENV MUSL_LOCPATH="/usr/share/i18n/locales/musl"

RUN apk add --no-cache \
    $MUSL_LOCALE_DEPS \
    && wget https://gitlab.com/rilian-la-te/musl-locales/-/archive/master/musl-locales-master.zip \
    && unzip musl-locales-master.zip \
      && cd musl-locales-master \
      && cmake -DLOCALE_PROFILE=OFF -D CMAKE_INSTALL_PREFIX:PATH=/usr . && make && make install \
      && cd .. && rm -r musl-locales-master

# Add Repositories
RUN rm -f /etc/apk/repositories &&\
    echo "http://dl-cdn.alpinelinux.org/alpine/v3.20/main" >> /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/v3.20/community" >> /etc/apk/repositories

# Add Build Dependencies
RUN apk update && apk add --no-cache --virtual .build-deps  \
    zlib-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    python3 \
    gcc \
    clang \
    llvm \
    libxml2-dev \
    bzip2-dev \
    linux-headers

# Add Production Dependencies
RUN apk add --update --no-cache \
    bash \
    jq \
    nano \
    git \
    openssh \
    pcre-dev ${PHPIZE_DEPS} \
    jpegoptim \
    pngquant \
    optipng \
    supervisor \
    nginx \
    dcron \
    libcap \
    icu-dev \
    freetype-dev \
    postgresql-dev \
    postgresql-client \
    zip \
    libzip-dev \
    less \
    imagemagick \
    libxslt-dev \
    exiftool \
    imagemagick-dev \
    chromium \
    && pecl install redis \
    && pecl install -o -f imagick

# Configure & Install Extension
RUN docker-php-ext-configure \
    opcache --enable-opcache &&\
    docker-php-ext-configure gd --with-jpeg=/usr/include/ --with-freetype=/usr/include/ && \
    docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql &&\
    docker-php-ext-configure zip && \
    docker-php-ext-install \
    opcache \
    mysqli \
    pgsql \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    sockets \
    intl \
    gd \
    xml \
    bz2 \
    pcntl \
    bcmath \
    exif \
    zip \
    xsl \
    && docker-php-ext-enable \
    imagick \
    redis

# Create necessary directories and set permissions
RUN mkdir -p /var/run/nginx \
    && mkdir -p /var/run/php-fpm \
    && mkdir -p /var/run/supervisor \
    && mkdir -p /var/log/nginx \
    && mkdir -p /var/log/supervisor \
    && mkdir -p /var/log/php-fpm \
    && chown -R www-data:www-data /var/run/nginx \
    && chown -R www-data:www-data /var/run/php-fpm \
    && chown -R www-data:www-data /var/run/supervisor \
    && chown -R www-data:www-data /var/log/nginx \
    && chown -R www-data:www-data /var/log/supervisor \
    && chown -R www-data:www-data /var/log/php-fpm \
    && chown -R www-data:www-data /etc/nginx \
    && chown -R www-data:www-data /usr/sbin/nginx \
    && chown -R www-data:www-data /usr/local/sbin/php-fpm \
    && chown -R www-data:www-data /usr/local/etc/php-fpm.conf \
    && touch /var/log/php-fpm/php-fpm.log \
    && chown www-data:www-data /var/log/php-fpm/php-fpm.log \
    && mkdir -p /run \
    && chown www-data:www-data /run

# Ensure cron directories exist and have correct permissions
RUN mkdir -p /etc/cron.d \
    && mkdir -p /etc/periodic \
    && touch /etc/crontabs/www-data \
    && chmod 755 /etc/cron.d \
    && chmod 755 /etc/periodic \
    && chown www-data:www-data /etc/cron.d \
    && chown www-data:www-data /etc/periodic \
    && chown www-data:www-data /etc/crontabs \
    && chmod 755 /usr/sbin/crond \
    && chown www-data:www-data /usr/sbin/crond \
    && setcap cap_setgid=ep /usr/sbin/crond

# Copy Nginx and Supervisor configuration files
COPY ./config/nginx.conf /etc/nginx/nginx.conf
COPY ./config/nginx-default.conf /etc/nginx/conf.d/default.conf

# Copy Supervisor config files
COPY ./config/supervisord.conf /etc/supervisord.conf
COPY ./config/supervisord-master.ini /etc/supervisor.d/master.ini

# Copy custom PHP-FPM configuration
COPY ./config/php-fpm.conf /usr/local/etc/php-fpm.conf

# Copy PHP configuration
COPY ./config/php8.3.ini /usr/local/etc/php/php.ini

# Set permissions
RUN chown -R www-data:www-data /var/lib/nginx /var/log/nginx /run/nginx /var/log/supervisor /var/run

# Add non root user to the tty group, so we can write to stdout and stderr
RUN addgroup www-data tty

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install Node
COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/share /usr/local/share
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin

# Puppeteer npm configuration.
# It uses apk installed Chromium "/usr/bin/chromium-browser", tell Puppeteer to not install local Chromium which takes time.
# Compatible version = Puppeteer 10.0.0. Install in project with "npm install puppeteer@10.0.0".
# More info here : https://stackoverflow.com/questions/69417926/docker-error-eacces-permission-denied-mkdir
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# Remove Build Dependencies
RUN apk del -f .build-deps

# Setup Working Dir
WORKDIR /var/www

# Switch to www-data user to run services
USER www-data

# Expose ports
EXPOSE 8080

# Command to run supervisord
CMD ["supervisord", "-c", "/etc/supervisord.conf"]
