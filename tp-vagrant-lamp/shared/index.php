<?php
$servername = "192.168.56.11";
$username = "tp_user";
$password = "tp_password";
$dbname = "tp_db";

// Créer une connexion MySQLi
$conn = new mysqli($servername, $username, $password, $dbname);

// Vérifier la connexion
if ($conn->connect_error) {
    echo "Connexion à la base de données échouée : " . $conn->connect_error;
} else {
    echo "Connexion à la base de données réussie !";
}

// Fermer la connexion
$conn->close();
?>
