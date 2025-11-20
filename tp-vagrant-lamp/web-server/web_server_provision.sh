#!/bin/bash
set -e

LOGFILE="/vagrant/web-server_provision.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "[INFO] Démarrage du provisioning Apache/PHP..."

# Installation Apache2, PHP, et extensions nécessaires (php-mysql inclut mysqli/PDO)
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y apache2 php php-mysql libapache2-mod-php

# Activation du module PHP (sera ignoré s'il est déjà activé)
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;") # obtenir la version majeure.minor de PHP installée
if ! a2query -m "php${PHP_VERSION}" >/dev/null 2>&1; then # vérifier si le module est déjà activé
    echo "[INFO] Activation du module PHP ${PHP_VERSION} pour Apache..." 
  a2enmod "php${PHP_VERSION}"
fi

systemctl enable apache2
systemctl restart apache2

echo "[INFO] Installation et configuration du dossier partagé terminée. Vérification index.php..."

# Vérification de la présence de index.php dans /var/www/html (monté depuis ./shared)
if [ ! -f /var/www/html/index.php ]; then
cat <<'EOF' > /var/www/html/index.php
<?php
$host = '192.168.56.11'; // IP de la VM DB
$dbname = 'tp_db';
$username = 'tp_user';
$password = 'tp_password';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "<h2>Connexion à la base de données réussie !</h2>";
} catch (PDOException $e) {
    echo "<h2>Erreur de connexion : " . htmlspecialchars($e->getMessage()) . "</h2>";
}
?>
EOF
    echo "[INFO] index.php déployé dans /var/www/html/"
else
    echo "[INFO] index.php déjà présent, pas de changement."
fi

echo "[SUCCESS] Provisioning du web-server terminé avec succès."
