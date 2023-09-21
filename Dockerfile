#FROM node:20.0.0-alpine as node
FROM node:19.9.0-alpine as node

FROM php:8.1.0-fpm-alpine3.15 as base

# Setup Working Dir
WORKDIR /var/www

# Musl for adding locales
ENV MUSL_LOCALE_DEPS cmake make musl-dev gcc gettext-dev libintl
ENV MUSL_LOCPATH /usr/share/i18n/locales/musl

RUN apk add --no-cache \
    $MUSL_LOCALE_DEPS \
    && wget https://gitlab.com/rilian-la-te/musl-locales/-/archive/master/musl-locales-master.zip \
    && unzip musl-locales-master.zip \
      && cd musl-locales-master \
      && cmake -DLOCALE_PROFILE=OFF -D CMAKE_INSTALL_PREFIX:PATH=/usr . && make && make install \
      && cd .. && rm -r musl-locales-master

# Add Repositories
RUN rm -f /etc/apk/repositories &&\
    echo "http://dl-cdn.alpinelinux.org/alpine/v3.13/main" >> /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/v3.13/community" >> /etc/apk/repositories

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
    bzip2-dev

# Add Production Dependencies
RUN apk add --update --no-cache \
    bash \
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
    redis && \
    chown www-data:www-data /usr/sbin/crond && \
    setcap cap_setgid=ep /usr/sbin/crond

COPY ./config/php.ini $PHP_INI_DIR/conf.d/

# Setup config for supervisor nginx php-fpm crontabs
RUN mkdir /etc/supervisor.d
COPY ./config/supervisord-master.ini /etc/supervisor.d/master.ini
COPY ./config/supervisord.conf /etc/

RUN mkdir /var/log/supervisor/
RUN touch /var/log/supervisor/supervisord.log
RUN chown -R www-data:www-data /var/log/supervisor/

COPY ./config/nginx-default.conf /etc/nginx/conf.d/default.conf
COPY ./config/nginx.conf /etc/nginx/nginx.conf

COPY ./config/php-fpm.conf /usr/local/etc/php-fpm.conf.d/www.conf
COPY ./config/php-fpm.conf /usr/local/etc/php-fpm.d/www.conf
COPY ./config/php-fpm-docker.conf /usr/local/etc/php-fpm.d/docker.conf

RUN chmod 755 -R /etc/supervisor.d/ /etc/supervisord.conf  /etc/nginx/ /etc/crontabs/

# Remove Build Dependencies
RUN apk del -f .build-deps

RUN mkdir -p /var/lib/nginx/tmp /var/log/nginx \
    && chown -R www-data:www-data /var/lib/nginx /var/log/nginx \
    && chmod -R 755 /var/lib/nginx /var/log/nginx

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

USER www-data

CMD ["/usr/bin/supervisord"]
