#!/usr/bin/env bash
set -e # --> IA m'a conseillé de mettre

apt-get update
apt-get upgrade -y

if ! dpkg -s apache2 >/dev/null 2>&1; then
    apt-get install -y apache2 php php-cli
    echo "Apache2 and PHP have been installed."
else
    echo "Apache2 is already installed."
fi

systemctl enable apache2
systemctl start apache2

rm -rf /var/www/html/*

cat << EOF > /var/www/html/index.html
<html><body>
<h1><center> Hello world ! </center></h1>
</body></html>
EOF

chown -R www-data:www-data /var/www/html

echo "Hello from Vagrant LAMP setup!" > /etc/motd
