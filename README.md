# nginx-php-fpm

This is a base image using nginx + php fpm monitored by supervisord.

- Bash
- PHP 8.1
- Postgresql driver
- GD extension
- supervisor
- Composer
- Nodejs 16.13 + npm 8.1.2

It must be launched using tty option.
It uses the user 'www-data' (id 82).
