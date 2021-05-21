FROM php:8.0.6-fpm-alpine3.13

# Setup Working Dir
WORKDIR /var/www

# Add Repositories
RUN rm -f /etc/apk/repositories &&\
    echo "http://dl-cdn.alpinelinux.org/alpine/v3.13/main" >> /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/v3.13/community" >> /etc/apk/repositories

# Add Build Dependencies
RUN apk update && apk add --no-cache --virtual .build-deps  \
    zlib-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libxml2-dev \
    bzip2-dev \
    zip \
    libzip-dev


# Add Production Dependencies
RUN apk add --update --no-cache \
    pcre-dev ${PHPIZE_DEPS} \
    jpegoptim \
    pngquant \
    optipng \
    supervisor \
    nano \
    nginx \
    icu-dev \
    freetype-dev \
    postgresql-dev \
    && pecl install redis

# Configure & Install Extension
RUN docker-php-ext-configure \
    opcache --enable-opcache &&\
    docker-php-ext-configure gd --with-jpeg=/usr/include/ --with-freetype=/usr/include/ && \
    docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql &&\
    docker-php-ext-configure zip && \
    docker-php-ext-install \
    opcache \
    pgsql \
    pdo_pgsql \
    sockets \
    intl \
    gd \
    xml \
    bz2 \
    pcntl \
    bcmath \
    exif \
    && docker-php-ext-enable \
    redis

# Add Composer
RUN curl -s https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin/ --filename=composer
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="./vendor/bin:$PATH"

COPY ./config/opcache.ini $PHP_INI_DIR/conf.d/
COPY ./config/php.ini $PHP_INI_DIR/conf.d/

# Setup Crond and Supervisor by default
RUN echo '*  *  *  *  * /usr/local/bin/php  /var/www/artisan schedule:run >> /dev/null 2>&1' > /etc/crontabs/root && mkdir /etc/supervisor.d
COPY ./config/master.ini /etc/supervisor.d/
COPY ./config/supervisord.conf /etc/
COPY ./config/default.conf /etc/nginx/conf.d
COPY ./config/nginx.conf /etc/nginx/nginx.conf

RUN chmod 755 -R /etc/supervisor.d/ /etc/supervisord.conf  /etc/nginx/

# Remove Build Dependencies
RUN apk del -f .build-deps

RUN mkdir -p /var/lib/nginx/tmp /var/log/nginx \
    && chown -R www-data:www-data /var/lib/nginx /var/log/nginx \
    && chmod -R 755 /var/lib/nginx /var/log/nginx

# Add non root user to the tty group, so we can write to stdout and stderr
RUN addgroup www-data tty

CMD ["/usr/bin/supervisord"]