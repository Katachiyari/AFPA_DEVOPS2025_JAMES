# ⚡ Guide Rapide : SSH Authentification par Clé - Debian

---

## 🚀 Installation et déploiement en 5 minutes

### ✅ Prérequis
- Accès SSH au serveur Debian (avec mot de passe)
- Terminal sur le client
- SSH client installé

---

## Étape 1 : Installation SSH serveur (Debian)

```bash
# Sur le SERVEUR Debian
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh
```

---

## Étape 2 : Générer la clé (CLIENT)

```bash
# Sur votre ORDINATEUR CLIENT
ssh-keygen -t ed25519 -a 100 -C "vous@machine" -f ~/.ssh/id_ed25519

# Entrez une passphrase forte quand demandé
# Exemple : p@ssW0rd_SSH_2025_Secure!
```

---

## Étape 3 : Copier la clé publique (CLIENT → SERVEUR)

```bash
# Sur le CLIENT
ssh-copy-id -i ~/.ssh/id_ed25519.pub admin@IP_SERVEUR

# Entrez le mot de passe du serveur quand demandé
```

---

## Étape 4 : Tester la connexion (CLIENT)

```bash
# Sur le CLIENT
ssh -i ~/.ssh/id_ed25519 admin@IP_SERVEUR

# Entrez la passphrase de votre clé si elle a une
# ✅ Vous devriez être connecté sans demande de mot de passe !
```

---

## Étape 5 : Sécuriser (Optionnel mais TRÈS recommandé)

```bash
# Sur le SERVEUR, éditer la configuration
sudo nano /etc/ssh/sshd_config

# Chercher et décommenter/modifier ces lignes :
PubkeyAuthentication yes
PasswordAuthentication no        # ⚠️ Activez APRÈS test !
PermitRootLogin no

# Sauvegarder (Ctrl+X, Y, Entrée)
# Redémarrer SSH
sudo systemctl restart ssh

# Tester que ça marche encore avec la clé
ssh admin@IP_SERVEUR
```

---

## 🆘 Si connexion échoue

```bash
# Mode verbose pour diagnostiquer
ssh -v -i ~/.ssh/id_ed25519 admin@IP_SERVEUR

# Vérifier sur le serveur
ssh admin@IP_SERVEUR
cat ~/.ssh/authorized_keys
ls -la ~/.ssh/  # Doit être 700, authorized_keys doit être 600
```

---

## 📋 Checklist finale

- ✅ SSH serveur installé et actif (`sudo systemctl status ssh`)
- ✅ Clé générée sur client (`ls ~/.ssh/id_ed25519*`)
- ✅ Clé copiée sur serveur (`cat ~/.ssh/authorized_keys`)
- ✅ Permissions correctes sur serveur (`chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys`)
- ✅ Connexion sans mot de passe validée
- ✅ `PasswordAuthentication no` appliqué si souhaité

---

**C'est fait ! Vous avez SSH par clé fonctionnel et sécurisé sur Debian.**