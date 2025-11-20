#!/bin/bash
# commentaire en francais
# ce TP n'est pas destiné à être utilisé en production
set -e

LOGFILE="/vagrant/db-server_provision.log" # rediriger toute la sortie vers un fichier de log
exec > >(tee -a "$LOGFILE") 2>&1 # redirection stdout et stderr vers le fichier de log

echo "[INFO] Démarrage du provisioning MariaDB..."

# 1. Installation MariaDB
echo "[INFO] Installation de MariaDB si nécessaire..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client

# 2. Activer et démarrer le service
echo "[INFO] Activation et démarrage du service mariadb..."
systemctl enable mariadb
systemctl start mariadb

# 3. Configurer MariaDB pour écouter sur toutes les interfaces
MARIADB_CNF="/etc/mysql/mariadb.conf.d/50-server.cnf"
# Remplacer une ligne existante même si elle est commentée, sinon ajouter
if grep -q "^[[:space:]]*#\?[[:space:]]*bind-address" "$MARIADB_CNF"; then
    sed -i -e 's/^[[:space:]]*#\?[[:space:]]*bind-address.*/bind-address = 0.0.0.0/' "$MARIADB_CNF"
else
    echo "bind-address = 0.0.0.0" >> "$MARIADB_CNF"
fi
systemctl restart mariadb

# 4. Importer le script SQL avec validation
SQLFILE="/vagrant/db_sql/db_init.sql"
if [ -f "$SQLFILE" ] && [ -s "$SQLFILE" ]; then
    echo "[INFO] Import initial SQL depuis $SQLFILE"
    if ! mysql < "$SQLFILE"; then
        echo "[ERROR] L'import SQL a échoué pour $SQLFILE" >&2
        exit 1
    fi
else
    if [ -f "$SQLFILE" ] && [ ! -s "$SQLFILE" ]; then
        echo "[WARN] $SQLFILE existe mais est vide, création manuelle des objets..."
    else
        echo "[WARN] $SQLFILE introuvable, création manuelle des objets..."
    fi
    mysql -e "CREATE DATABASE IF NOT EXISTS tp_db CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    mysql -e "CREATE USER IF NOT EXISTS 'tp_user'@'%' IDENTIFIED BY 'tp_password';"
    mysql -e "GRANT ALL PRIVILEGES ON tp_db.* TO 'tp_user'@'%';"
    mysql -e "FLUSH PRIVILEGES;"
    mysql -D tp_db -e "CREATE TABLE IF NOT EXISTS users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100), email VARCHAR(100));"
fi

echo "[SUCCESS] Provisioning MariaDB terminé avec succès."
