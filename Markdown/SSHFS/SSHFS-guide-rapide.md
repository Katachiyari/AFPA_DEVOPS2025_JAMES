# SSHFS - Montage Fichiers Distants Sécurisés
## Guide Rapide - Démarrage Immédiat

---

## ⚡ Installation (5 minutes)

### Client (Poste Local)

```bash
# 1. Installer SSHFS et dépendances
sudo apt update
sudo apt install -y sshfs openssh-client

# 2. Ajouter utilisateur au groupe fuse
sudo usermod -aG fuse $USER

# 3. Se déconnecter/reconnecter pour que le changement prenne effet
newgrp fuse
# ou logout/login

# 4. Vérifier l'installation
sshfs --version
id | grep fuse
```

### Serveur (Distant)

```bash
# 1. Vérifier OpenSSH Server
sudo systemctl status ssh

# 2. Vérifier SFTP subsystem
grep -i "subsystem.*sftp" /etc/ssh/sshd_config
# Si absent, ajouter :
# Subsystem sftp /usr/lib/openssh/sftp-server
```

---

## 🔑 Génération Clé ED25519 Dédiée

```bash
# 1. Créer clé ED25519 pour SSHFS uniquement
ssh-keygen -t ed25519 \
           -f ~/.ssh/id_sshfs \
           -C "sshfs-user@$(date +%Y%m%d)" \
           -N ""

# 2. Vérifier les permissions
chmod 600 ~/.ssh/id_sshfs
chmod 644 ~/.ssh/id_sshfs.pub
ls -la ~/.ssh/id_sshfs*

# 3. Copier la clé publique sur serveur
cat ~/.ssh/id_sshfs.pub
# Copier manuellement ou via :
ssh-copy-id -i ~/.ssh/id_sshfs.pub utilisateur@serveur.exemple.com
```

---

## 📁 Créer Répertoire de Montage

```bash
# Structure recommandée
mkdir -p ~/mnt/{prod,dev,temp}

# Vérifier
ls -la ~/mnt/
```

---

## 🚀 Montage Simple (Une Ligne)

```bash
# Montage basique
sshfs -C utilisateur@serveur:/data ~/mnt/data

# Vérifier le montage
ls ~/mnt/data
df -h ~/mnt/data

# Utiliser comme répertoire normal
cat ~/mnt/data/fichier.txt
cp ~/fichier.local ~/mnt/data/
```

---

## 🔒 Montage Sécurisé ANSSI-Compliant

```bash
# Options recommandées ANSSI
sshfs -C \
      -o reconnect \
      -o ServerAliveInterval=300 \
      -o idmap=user \
      -o cache=yes \
      -o cache_timeout=600 \
      -o allow_other \
      -o default_permissions \
      -o IdentityFile=~/.ssh/id_sshfs \
      utilisateur@serveur:/data ~/mnt/data

# Explication :
# -C                   → Compression SSH
# reconnect            → Reconnexion automatique
# ServerAliveInterval  → Keep-alive toutes les 5 min
# idmap=user           → Mapper UID/GID
# cache                → Cache local
# allow_other          → Accessible autres users
# default_permissions  → Respect permissions POSIX
# IdentityFile         → Clé dédiée SSHFS
```

---

## ✅ Checklist de Montage

- [ ] SSHFS installé (`sshfs --version`)
- [ ] Utilisateur dans groupe fuse (`id | grep fuse`)
- [ ] Clé ED25519 générée (`ls ~/.ssh/id_sshfs`)
- [ ] Clé publique copiée sur serveur
- [ ] Répertoire de montage créé (`mkdir -p ~/mnt/data`)
- [ ] Montage réussi (`sshfs ...`)
- [ ] Accès fonctionnel (`ls ~/mnt/data`)

---

## 🔌 Configuration SSH Client (~/.ssh/config)

```
# Pour simplifier les montages répétés

Host data-prod
    HostName data.prod.exemple.com
    User sshfs-user
    IdentityFile ~/.ssh/id_sshfs
    IdentitiesOnly yes
    
    # Options SSHFS
    Compression yes
    ServerAliveInterval 300
    ServerAliveCountMax 3
```

Puis montage simplifiée :
```bash
sshfs -C -o reconnect,ServerAliveInterval=300 data-prod:/data ~/mnt/data
```

---

## 📝 Script de Montage Automatisé

```bash
#!/bin/bash
# Sauvegarder en ~/bin/mount-sshfs.sh

SSHFS_HOST="${1:?Usage: $0 <user@host> [remote_path]}"
REMOTE_PATH="${2:-/home}"
LOCAL_PATH="$HOME/mnt/$(echo $SSHFS_HOST | cut -d@ -f2)"

mkdir -p "$LOCAL_PATH"

sshfs -C \
      -o reconnect \
      -o ServerAliveInterval=300 \
      -o idmap=user \
      -o cache=yes \
      -o allow_other \
      -o IdentityFile="$HOME/.ssh/id_sshfs" \
      "$SSHFS_HOST:$REMOTE_PATH" \
      "$LOCAL_PATH"

echo "Montage : $LOCAL_PATH"
```

Utilisation :
```bash
chmod +x ~/bin/mount-sshfs.sh
~/bin/mount-sshfs.sh utilisateur@serveur /data
```

---

## 🔓 Démonter un Montage

```bash
# Démonter
fusermount -u ~/mnt/data

# Ou forcer (si stuck)
fusermount -uz ~/mnt/data

# Vérifier la déconnexion
df -h | grep sshfs
mount | grep sshfs
```

---

## 🆘 Dépannage Rapide

| Problème | Solution |
|----------|----------|
| "Permission denied (publickey)" | Vérifier clé : `ssh -i ~/.ssh/id_sshfs user@serveur` |
| "No such file or directory" | Vérifier path : `ssh user@serveur ls -la /data` |
| "Read-only file system" | Vérifier permissions serveur : `ssh user@serveur ls -ld /data` |
| Montage figé | `fusermount -uz ~/mnt/data` |
| Reconnexion lente | Ajouter `-o reconnect,ServerAliveInterval=300` |
| Clé demande passphrase | Ajouter à SSH Agent : `ssh-add ~/.ssh/id_sshfs` |

---

## 🧪 Tester la Montage

```bash
# 1. Vérifier montage actif
mount | grep sshfs

# 2. Lister le contenu
ls -la ~/mnt/data/

# 3. Copier fichier test
cp ~/test.txt ~/mnt/data/

# 4. Vérifier transfert
ssh utilisateur@serveur "ls -la /data/test.txt"

# 5. Démonter proprement
fusermount -u ~/mnt/data
```

---

## 📊 Montage Multiple Automatisé

```bash
#!/bin/bash
# Monter plusieurs serveurs

declare -A SERVERS=(
    ["prod-data"]="user@prod:/data"
    ["dev-lab"]="user@dev:/home"
    ["logs"]="user@logs:/var/log"
)

for alias in "${!SERVERS[@]}"; do
    path="${SERVERS[$alias]}"
    mount_point="$HOME/mnt/$alias"
    mkdir -p "$mount_point"
    
    echo "Montage : $alias"
    sshfs -C -o reconnect,ServerAliveInterval=300 "$path" "$mount_point"
done

# Lister les montages
mount | grep sshfs
```

---

**Guide rapide - Pour démarrage immédiat**
**Voir Guide Complet pour détails ANSSI et concepts avancés**
