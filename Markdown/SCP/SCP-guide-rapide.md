# SCP - Transfert Fichiers Sécurisé
## Guide Rapide - Démarrage Immédiat

---

## ⚡ Installation (5 minutes)

### Client (Poste Local)

```bash
# 1. Vérifier OpenSSH Client
which scp
scp -V

# 2. Installer si absent
sudo apt update
sudo apt install -y openssh-client

# 3. Générer clé ED25519
ssh-keygen -t ed25519 -f ~/.ssh/id_scp -C "scp-user@$(date +%Y%m%d)" -N ""

# 4. Vérifier
ls -la ~/.ssh/id_scp*
chmod 600 ~/.ssh/id_scp
```

### Serveur (Distant)

```bash
# 1. Vérifier OpenSSH Server
sudo systemctl status ssh

# 2. Si absent, installer
sudo apt install -y openssh-server

# 3. Créer utilisateur SCP
sudo adduser scp-user --shell /usr/sbin/nologin --no-create-home

# 4. Créer répertoire de transfert
sudo mkdir -p /data/scp-transfers
sudo chown scp-user:scp-user /data/scp-transfers
sudo chmod 750 /data/scp-transfers
```

---

## 🔑 Déployer Clé Publique

```bash
# Option 1 : ssh-copy-id (recommandé)
ssh-copy-id -i ~/.ssh/id_scp.pub scp-user@serveur.exemple.com

# Option 2 : Manuellement
cat ~/.ssh/id_scp.pub
# Copier sur serveur puis :
echo "ssh-ed25519 AAAA..." >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

---

## 🚀 Transferts Simples

```bash
# Push : Client → Serveur
scp ~/fichier.txt scp-user@serveur:/data/scp-transfers/

# Pull : Serveur → Client
scp scp-user@serveur:/data/fichier.txt ~/

# Avec port alternatif
scp -P 2222 ~/fichier.txt scp-user@serveur:/tmp/

# Vérifier
ls ~/fichier.txt
ssh scp-user@serveur "ls -la /data/scp-transfers/fichier.txt"
```

---

## 📁 Transferts Récursifs

```bash
# Copier répertoire entier
scp -r ~/projet scp-user@serveur:/data/

# Copier contenu répertoire (sans parent)
scp -r ~/projet/* scp-user@serveur:/data/

# Depuis serveur
scp -r scp-user@serveur:/data/projet ~/backups/
```

---

## 🔒 Transfert ANSSI-Compliant

```bash
# Options recommandées ANSSI
scp -C \
    -p \
    -i ~/.ssh/id_scp \
    -o StrictHostKeyChecking=accept-new \
    ~/fichier.txt scp-user@serveur:/data/

# Explication :
# -C    → Compression SSH
# -p    → Préserver timestamps/permissions
# -i    → Clé dédiée
# -o    → Options SSH
```

---

## ✅ Checklist Transfert

- [ ] SCP installé (`scp -V`)
- [ ] Clé ED25519 générée (`ls ~/.ssh/id_scp`)
- [ ] Clé publique déployée
- [ ] SSH connexion fonctionne (`ssh scp-user@serveur echo OK`)
- [ ] Transfert simple réussi (`scp ~/test.txt ...`)
- [ ] Intégrité vérifiée (empreinte SHA256)

---

## 🔒 Configuration SSH (~/.ssh/config)

```
Host scp-prod
    HostName serveur.exemple.com
    User scp-user
    IdentityFile ~/.ssh/id_scp
    IdentitiesOnly yes
    Compression yes
```

Utilisation :
```bash
scp ~/fichier.txt scp-prod:/data/
scp -r scp-prod:/data/backup ~/backups/
```

---

## 📝 Script de Transfert Simple

```bash
#!/bin/bash
# Sauvegarder en ~/bin/scp-transfer.sh

SRC="${1:?Usage: $0 <source> <user@host> <dest_path>}"
HOST="${2:?}"
DEST="${3:?}"

echo "[*] Transfert : $SRC → $HOST:$DEST"

scp -C -p -i ~/.ssh/id_scp "$SRC" "$HOST:$DEST/"

if [ $? -eq 0 ]; then
    echo "[✓] Transfert réussi"
else
    echo "[✗] Erreur"
    exit 1
fi
```

Utilisation :
```bash
chmod +x ~/bin/scp-transfer.sh
~/bin/scp-transfer.sh ~/fichier.txt scp-user@serveur /data/
```

---

## 🔄 Transfert Multiple Parallèle

```bash
# Transférer plusieurs fichiers en parallèle

for file in ~/data/*.txt; do
    scp -C -p "$file" scp-user@serveur:/data/ &
done

wait
echo "Tous les transferts complétés"
```

---

## 🔐 Vérifier l'Intégrité

```bash
#!/bin/bash
# Transfert + vérification SHA256

FILE="$1"
HOST="$2"

SHA_SRC=$(sha256sum "$FILE" | awk '{print $1}')
echo "[*] Empreinte source : $SHA_SRC"

scp -C -p "$FILE" "$HOST:/tmp/"

SHA_DST=$(ssh "$HOST" "sha256sum /tmp/$(basename $FILE)" | awk '{print $1}')
echo "[*] Empreinte distante : $SHA_DST"

if [ "$SHA_SRC" = "$SHA_DST" ]; then
    echo "[✓] Intégrité vérifiée"
else
    echo "[✗] Erreur d'intégrité"
fi
```

---

## 🆘 Dépannage Rapide

| Problème | Solution |
|----------|----------|
| "Permission denied" | Vérifier clé : `ssh -i ~/.ssh/id_scp user@serveur` |
| "No such file or directory" | Vérifier path : `ssh user@serveur ls -la /data/` |
| "No space left" | Vérifier espace : `ssh user@serveur df -h` |
| Transfert très lent | Ajouter compression : `scp -C ...` |
| Fichier ne se voit pas | Vérifier permissions : `ssh user@serveur ls -la` |

---

**Guide rapide - Pour démarrage immédiat**
**Voir Guide Complet pour détails ANSSI et concepts avancés**
