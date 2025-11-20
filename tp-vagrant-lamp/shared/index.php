<?php
$host = '192.168.56.11';
$dbname = 'tp_db';
$username = 'tp_user';
$password = 'tp_password';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die("<div class='alert alert-danger'>Erreur de connexion : " . htmlspecialchars($e->getMessage()) . "</div>");
}

function sanitize($str) {
    return htmlspecialchars($str, ENT_QUOTES, 'UTF-8');
}

// Create
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'add') {
    $name = trim($_POST['name'] ?? '');
    $email = trim($_POST['email'] ?? '');
    if ($name && filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $stmt = $pdo->prepare("INSERT INTO users (name, email) VALUES (?, ?)");
        $stmt->execute([$name, $email]);
    }
}

// Delete
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'delete' && isset($_POST['id'])) {
    $id = intval($_POST['id']);
    $pdo->prepare("DELETE FROM users WHERE id=?")->execute([$id]);
}

// Update
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'update' && isset($_POST['id'])) {
    $id = intval($_POST['id']);
    $name = trim($_POST['name'] ?? '');
    $email = trim($_POST['email'] ?? '');
    if ($name && filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $stmt = $pdo->prepare("UPDATE users SET name=?, email=? WHERE id=?");
        $stmt->execute([$name, $email, $id]);
    }
}

// Pour l'affichage pré-rempli lors du clic sur Modifier
$user_edit = null;
if (isset($_GET['edit'])) {
    $id = intval($_GET['edit']);
    $stmt = $pdo->prepare("SELECT * FROM users WHERE id=?");
    $stmt->execute([$id]);
    $user_edit = $stmt->fetch(PDO::FETCH_ASSOC);
}

// Read
$users = $pdo->query("SELECT * FROM users")->fetchAll(PDO::FETCH_ASSOC);
?>

<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>Mini CRUD utilisateur</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-light">
<div class="container" style="max-width:550px;margin-top:40px;">
    <h3 class="mb-3 text-center">Mini-CRUD Utilisateur (TP)</h3>
    <div class="card p-3 mb-4">
        <form method="post">
            <input type="hidden" name="action" value="<?php echo $user_edit ? "update" : "add"; ?>">
            <?php if ($user_edit): ?>
                <input type="hidden" name="id" value="<?php echo intval($user_edit['id']) ?>">
            <?php endif; ?>
            <div class="mb-3">
                <label for="name" class="form-label">Nom</label>
                <input id="name" name="name" type="text" class="form-control" value="<?php echo $user_edit ? sanitize($user_edit['name']) : "" ?>" required>
            </div>
            <div class="mb-3">
                <label for="email" class="form-label">E-mail</label>
                <input id="email" name="email" type="email" class="form-control" value="<?php echo $user_edit ? sanitize($user_edit['email']) : "" ?>" required>
            </div>
            <div class="d-grid gap-2">
                <button type="submit" class="btn btn-primary"><?php echo $user_edit ? "Mettre à jour" : "Ajouter"; ?></button>
            </div>
        </form>
    </div>
    <div class="card p-3">
        <h6 class="mb-3 text-center">Utilisateurs existants</h6>
        <table class="table table-sm table-striped table-bordered text-center align-middle">
            <thead>
                <tr>
                    <th>ID</th><th>Nom</th><th>Email</th><th>Actions</th>
                </tr>
            </thead>
            <tbody>
            <?php foreach ($users as $u): ?>
                <tr>
                    <td><?php echo intval($u['id']); ?></td>
                    <td><?php echo sanitize($u['name']); ?></td>
                    <td><?php echo sanitize($u['email']); ?></td>
                    <td>
                        <a class="btn btn-sm btn-secondary" href="?edit=<?php echo intval($u['id']); ?>">Modifier</a>
                        <form method="post" style="display:inline;">
                            <input type="hidden" name="action" value="delete">
                            <input type="hidden" name="id" value="<?php echo intval($u['id']); ?>">
                            <button type="submit" class="btn btn-sm btn-danger" onclick="return confirm('Supprimer cet utilisateur ?');">Suppr.</button>
                        </form>
                    </td>
                </tr>
            <?php endforeach; if (empty($users)): ?>
                <tr><td colspan="4">Aucun utilisateur</td></tr>
            <?php endif; ?>
            </tbody>
        </table>
    </div>
</div>
</body>
</html>
