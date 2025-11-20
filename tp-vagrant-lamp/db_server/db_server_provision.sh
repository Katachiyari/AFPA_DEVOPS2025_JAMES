#!/bin/bash

# Mettre à jour et installer MariaDB
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client

# Configurer MariaDB pour écouter toutes les interfaces
sed -i "s/^bind-address\s*=.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf

# Activer MariaDB au démarrage
systemctl enable mariadb
systemctl start mariadb

# Exécuter le script SQL d'initialisation
mysql < /vagrant/db_sql/db_init.sql
