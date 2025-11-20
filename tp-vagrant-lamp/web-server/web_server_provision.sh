#!/bin/bash

set -e

apt-get update

DEBIAN_FRONTEND=noninteractive apt-get install -y apache2 php php-mysql

chown -R www-data:www-data /var/www

chmod -R 775 /var/www/html

systemctl enable apache2

systemctl restart apache2

rm -f /var/www/html/index.html
