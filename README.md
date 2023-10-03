# nginx-php-fpm

This is a base image using nginx + php fpm monitored by supervisord.

- Bash
- JQ
- PHP 8.1 with extensions : 
  - opcache
  - mysqli
  - pgsql
  - pdo
  - pdo_mysql
  - pdo_pgsql
  - sockets
  - intl
  - gd
  - xml
  - bz2
  - pcntl
  - bcmath
  - mbstring
  - exif
  - zip
  - xsl
- PostgreSQL driver
- MySQL driver
- PostgreSQL Client with pg_dump
- GD extension
- Imagick extension
- Exiftool
- supervisor
- Composer
- Chromium + Puppeteer npm configuration
- Nodejs 16.13 + npm 8.1.2
- Nodejs 19.9.0 + npm 9.6.3

It must be launched using tty option.
It uses the user 'www-data' (id 82).
