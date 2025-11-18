# Authentification SSH par Clé
## Guide Rapide - Démarrage Immédiat

---

## ⚡ Démarrage en 5 Minutes

### 1️⃣ Générer la Clé (Client)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "utilisateur@$(date +%Y%m%d)"
# Saisir passphrase (≥20 caractères)
```

### 2️⃣ Vérifier Permissions

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

### 3️⃣ Importer Clé sur Serveur

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub utilisateur@serveur.exemple.com
# Saisir mot de passe (dernière fois)
```

### 4️⃣ Tester Connexion

```bash
ssh utilisateur@serveur.exemple.com
# Devrait demander passphrase SSH (pas mot de passe)
```

### 5️⃣ Configurer Serveur (SSH Sécurisé)

```bash
sudo nano /etc/ssh/sshd_config
```

Insérer :
```
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin no
HostKey /etc/ssh/ssh_host_ed25519_key
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
```

Puis :
```bash
sudo sshd -t         # Vérifier syntaxe
sudo systemctl restart ssh
```

---

## 📋 Configuration Client (~/.ssh/config)

```
Host serveur
    HostName serveur.exemple.com
    User utilisateur
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

Utilisation :
```bash
ssh serveur
```

---

## 🔒 SSH Agent (Optionnel mais Recommandé)

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Tester
ssh-add -l
```

Ajouter à ~/.bashrc :
```bash
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    ssh-add ~/.ssh/id_ed25519 2>/dev/null
fi
```

---

## ✅ Checklist Finale

- [ ] Clé ED25519 générée avec passphrase
- [ ] Permissions correctes (700, 600, 644)
- [ ] Clé publique copiée sur serveur
- [ ] Connexion par clé réussie
- [ ] PasswordAuthentication = no sur serveur
- [ ] Service SSH redémarré

---

## 🆘 Dépannage Rapide

| Problème | Solution |
|----------|----------|
| "Permission denied (publickey)" | Vérifier authorized_keys et permissions |
| SSH demande mot de passe | PubkeyAuthentication=yes et clé sur serveur |
| "Bad permissions" | chmod 600 id_ed25519 |
| Clé non trouvée | Vérifier IdentityFile dans ~/.ssh/config |

---

**Version rapide - Pour démarrage immédiat**
**Voir Guide Complet pour détails ANSSI**
