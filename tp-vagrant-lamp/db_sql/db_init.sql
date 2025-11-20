-- Création de la base de données si elle n'existe pas
CREATE DATABASE IF NOT EXISTS tp_db CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- Création de l'utilisateur si besoin, accessible depuis n'importe où
CREATE USER IF NOT EXISTS 'tp_user'@'%' IDENTIFIED BY 'tp_password';

-- Accorder tous les privilèges à l'utilisateur sur cette base
GRANT ALL PRIVILEGES ON tp_db.* TO 'tp_user'@'%';

-- Appliquer les droits immédiatement
FLUSH PRIVILEGES;
