# nginx-php-fpm

This is a base image using nginx + php fpm monitored by supervisord.

- PHP 8.1
- Postgresql driver
- GD extension
- supervisor

It must be launched using tty option.
It uses the user 'www-data' (id 82).
