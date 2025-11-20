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

# Assurer les permissions/ownership pour Apache si possible
mkdir -p /var/www/html
# Détecter le type de montage pour /var/www/html (ex: vboxsf ne permet pas chown)
MOUNT_TYPE=$(awk '$2=="/var/www/html" {print $3}' /proc/mounts || true)
if [ "$MOUNT_TYPE" = "vboxsf" ]; then
    echo "[INFO] /var/www/html est monté avec vboxsf; ownership géré par les options de montage."
else
    if chown -R www-data:www-data /var/www/html 2>/dev/null; then
        echo "[INFO] Ownership de /var/www/html défini sur www-data:www-data."
    else
        echo "[WARN] Impossible de changer ownership de /var/www/html (chown a échoué)." >&2
    fi
fi
# Assurer des permissions lisibles/exécutables pour les dossiers
chmod -R u=rwX,g=rX,o=rX /var/www/html 2>/dev/null || true

# Journal & socket info pour diagnostiquer accès HTTP
echo "[INFO] Vérification écoute sur le port 80..." 
ss -ltnp 2>/dev/null | grep ':80' || echo "[WARN] Aucun service n'écoute sur le port 80 (vérifiez Apache)."
echo "[INFO] Derniers logs Apache:" 
journalctl -u apache2 --no-pager -n 50 2>/dev/null | sed -n '1,200p' || echo "[WARN] journalctl non disponible ou aucun log Apache."

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

# exécuter le script de provisionnement côté guest (copié et lancé par Vagrant)
web_config.vm.provision "shell", path: "web-server/web_server_provision.sh"
