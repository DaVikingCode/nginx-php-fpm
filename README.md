# Nginx-PHP-FPM

This is a base image using nginx + php fpm monitored by supervisord.

It must be launched using tty option.

It uses the user `www-data`.

# Tester l'image en local
Faire les modifications dans le Dockerfile puis lancer la commande (le . correspond au dossier courant) :

```sh
docker build -t non-de-l-image .
```
