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
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

$dsn = "mysql:host=192.168.56.11;dbname=tp_db;charset=utf8mb4";
$username = "tp_user";
$password = "tp_password";

try {
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
} catch (PDOException $e) {
    die("Erreur de connexion : " . $e->getMessage());
}

function sanitize($str) {
    return htmlspecialchars($str, ENT_QUOTES, 'UTF-8');
}

// Ajout utilisateur
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'add') {
    $name = trim($_POST['name'] ?? '');
    $email = trim($_POST['email'] ?? '');
    if ($name !== '' && filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $stmt = $pdo->prepare("INSERT INTO users (name, email) VALUES (?, ?)");
        $stmt->execute([$name, $email]);
        header("Location: " . $_SERVER['PHP_SELF']);
        exit;
    }
}

// Suppression utilisateur
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'delete' && isset($_POST['id'])) {
    $id = intval($_POST['id']);
    $pdo->prepare("DELETE FROM users WHERE id=?")->execute([$id]);
    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}

// Préparation modification
$user_edit = null;
if (isset($_GET['edit'])) {
    $id = intval($_GET['edit']);
    $stmt = $pdo->prepare("SELECT * FROM users WHERE id=?");
    $stmt->execute([$id]);
    $user_edit = $stmt->fetch();
}

// Mise à jour
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'update' && isset($_POST['id'])) {
    $id = intval($_POST['id']);
    $name = trim($_POST['name'] ?? '');
    $email = trim($_POST['email'] ?? '');
    if ($name !== '' && filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $stmt = $pdo->prepare("UPDATE users SET name=?, email=? WHERE id=?");
        $stmt->execute([$name, $email, $id]);
        header("Location: " . $_SERVER['PHP_SELF']);
        exit;
    }
}

// Récupération utilisateurs
$users = $pdo->query("SELECT * FROM users ORDER BY id DESC")->fetchAll();
?>

<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Mini CRUD utilisateur</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet" />
    <style>
        body, html {
            height: 100%;
        }
        .container {
            height: 100%;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .card {
            width: 100%;
            max-width: 550px;
        }
    </style>
</head>
<body>
<div class="container">
    <div class="card p-4 shadow-sm">
        <h3 class="mb-4 text-center">Mini-CRUD Utilisateur</h3>

        <form method="post" novalidate>
            <input type="hidden" name="action" value="<?= $user_edit ? "update" : "add" ?>">
            <?php if ($user_edit): ?>
                <input type="hidden" name="id" value="<?= intval($user_edit['id']) ?>">
            <?php endif; ?>
            <div class="mb-3">
                <label for="name" class="form-label">Nom</label>
                <input type="text" id="name" name="name" required class="form-control"
                    value="<?= $user_edit ? sanitize($user_edit['name']) : '' ?>" autocomplete="off" />
            </div>
            <div class="mb-3">
                <label for="email" class="form-label">E-mail</label>
                <input type="email" id="email" name="email" required class="form-control"
                    value="<?= $user_edit ? sanitize($user_edit['email']) : '' ?>" autocomplete="off" />
            </div>
            <button type="submit" class="btn btn-primary w-100">
                <?= $user_edit ? "Mettre à jour" : "Envoyer" ?>
            </button>
            <?php if ($user_edit): ?>
                <a href="<?= $_SERVER['PHP_SELF'] ?>" class="btn btn-secondary w-100 mt-2">Annuler</a>
            <?php endif; ?>
        </form>

        <hr/>

        <table class="table table-striped table-bordered mt-3 mb-0">
            <thead class="table-light text-center">
                <tr>
                    <th>ID</th><th>Nom</th><th>Email</th><th>Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($users)): ?>
                    <tr><td colspan="4" class="text-center">Aucun utilisateur</td></tr>
                <?php else: ?>
                    <?php foreach ($users as $user): ?>
                        <tr>
                            <td class="text-center"><?= intval($user['id']) ?></td>
                            <td><?= sanitize($user['name']) ?></td>
                            <td><?= sanitize($user['email']) ?></td>
                            <td class="text-center">
                                <a href="?edit=<?= intval($user['id']) ?>" class="btn btn-warning btn-sm me-1">Modifier</a>
                                <form method="post" style="display:inline-block;" onsubmit="return confirm('Supprimer cet utilisateur ?');">
                                    <input type="hidden" name="action" value="delete" />
                                    <input type="hidden" name="id" value="<?= intval($user['id']) ?>" />
                                    <button type="submit" class="btn btn-danger btn-sm">Suppr.</button>
                                </form>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                <?php endif; ?>
            </tbody>
        </table>

    </div>
</div>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>


EOF
    echo "[INFO] index.php déployé dans /var/www/html/"
else
    echo "[INFO] index.php déjà présent, pas de changement."
fi

echo "[SUCCESS] Provisioning du web-server terminé avec succès."

# exécuter le script de provisionnement côté guest (copié et lancé par Vagrant)
web_config.vm.provision "shell", path: "web-server/web_server_provision.sh"
