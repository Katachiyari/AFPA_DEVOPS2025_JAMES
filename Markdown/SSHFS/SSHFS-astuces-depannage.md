# SSHFS - Astuces, Dépannage et Solutions Avancées

---

## 🛠️ Astuces Pratiques

### Alias Bash pour Montages Récurrents

```bash
# Ajouter à ~/.bashrc

alias mount-prod-data='sshfs -C -o reconnect,ServerAliveInterval=300 user@prod:/data ~/mnt/prod-data'
alias mount-dev='sshfs -C -o reconnect,ServerAliveInterval=300 user@dev:/home ~/mnt/dev'
alias mount-logs='sshfs -C -o reconnect,ServerAliveInterval=300 user@logs:/var/log ~/mnt/logs'

# Pour démonter rapidement
alias umount-sshfs='for m in $(mount | grep sshfs | awk "{print \$3}"); do fusermount -u "$m"; done'
alias sshfs-status='mount | grep sshfs'

# Utilisation
mount-prod-data   # Au lieu de la commande longue
mount-dev
sshfs-status
umount-sshfs
```

### Variables Réutilisables pour Montages

```bash
# Créer une configuration centralisée

cat > ~/.config/sshfs-mounts.conf << 'EOF'
# SSHFS Mounts Configuration

# Serveur production
PROD_HOST="user@prod.exemple.com"
PROD_PATH="/data"
PROD_MOUNT="$HOME/mnt/prod"

# Serveur développement
DEV_HOST="user@dev.interne"
DEV_PATH="/home"
DEV_MOUNT="$HOME/mnt/dev"

# Options ANSSI standardisées
SSHFS_OPTS="-C -o reconnect,ServerAliveInterval=300,idmap=user,cache=yes,allow_other"
EOF

# Source dans ~/.bashrc
source ~/.config/sshfs-mounts.conf

# Utiliser dans scripts
sshfs $SSHFS_OPTS $PROD_HOST:$PROD_PATH $PROD_MOUNT
```

### Montage avec Limite de Bande Passante

```bash
#!/bin/bash
# Limiter la bande passante SSH pour SSHFS

BANDWIDTH_LIMIT="1024"  # KB/s
SSHFS_HOST="$1"
REMOTE_PATH="${2:-.}"
MOUNT_POINT="${3:-~/mnt/$(echo $SSHFS_HOST | cut -d@ -f2)}"

# Via option rate limiting SSH
sshfs -C \
      -o reconnect \
      -o ServerAliveInterval=300 \
      -o bandwidth=$BANDWIDTH_LIMIT \
      "$SSHFS_HOST:$REMOTE_PATH" \
      "$MOUNT_POINT"

echo "Montage limité à $BANDWIDTH_LIMIT KB/s"
```

### Synchronisation Automatique avec Inotify

```bash
#!/bin/bash
# Synchroniser un répertoire SSHFS avec rsync en temps réel

MOUNT_POINT="$1"
SSHFS_SOURCE="$2"

if [ ! -d "$MOUNT_POINT" ]; then
    echo "Erreur : $MOUNT_POINT n'existe pas"
    exit 1
fi

# Utiliser inotify-tools pour détecter les changements
# Peut être gourmand en ressources

# Alternative : sync périodique simple
watch -n 60 "sync && echo 'Sync complété'"

# Ou ajouter à cron
# */5 * * * * sync
```

### Compression SSH Adaptative

```bash
#!/bin/bash
# Choisir compression selon débit

check_bandwidth() {
    # Test rapide de débit
    ping -c 3 "$1" | grep "min/avg/max" | awk '{print $4}' | cut -d/ -f2
}

LATENCY=$(check_bandwidth "serveur.exemple.com")

if (( LATENCY > 100 )); then
    # Haute latence → compression forte
    COMPRESSION="-o CompressionLevel=9"
else
    # Basse latence → compression légère
    COMPRESSION="-o CompressionLevel=1"
fi

sshfs -C $COMPRESSION utilisateur@serveur:/data ~/mnt/data
echo "Compression appliquée : $COMPRESSION"
```

### Monitoring Montage SSHFS

```bash
#!/bin/bash
# Surveiller l'état des montages SSHFS

monitor_sshfs() {
    while true; do
        clear
        
        echo "=== SSHFS Mounts Status ==="
        date
        echo ""
        
        # Montages actifs
        mount | grep sshfs
        
        echo ""
        echo "=== Processus SSHFS ==="
        ps aux | grep -E "[s]shfs|sftp-server" | head -5
        
        echo ""
        echo "=== Connexions SSH ==="
        netstat -tlnp 2>/dev/null | grep ":22" | wc -l
        
        sleep 5
    done
}

monitor_sshfs
```

---

## 🔍 Dépannage Détaillé

### Problème 1 : "Permission denied (publickey)"

#### Diagnostic Complet

```bash
# 1. Vérifier que la clé existe
ls -la ~/.ssh/id_sshfs
# Doit afficher : -rw------- (permissions 600)

# 2. Vérifier l'empreinte de clé
ssh-keygen -l -f ~/.ssh/id_sshfs

# 3. Tester SSH directement (sans SSHFS)
ssh -i ~/.ssh/id_sshfs -v utilisateur@serveur
# Chercher dans output : "Offering public key" et "Authentications"

# 4. Sur le serveur, vérifier authorized_keys
ssh utilisateur@serveur "cat ~/.ssh/authorized_keys | wc -l"

# 5. Vérifier que la clé publique est bien présente
cat ~/.ssh/id_sshfs.pub
ssh utilisateur@serveur "grep $(cat ~/.ssh/id_sshfs.pub | cut -d' ' -f2 | cut -c1-20) ~/.ssh/authorized_keys"
```

#### Solutions

```bash
# ✓ Régénérer et redéployer la clé
ssh-keygen -t ed25519 -f ~/.ssh/id_sshfs -C "sshfs-$(date +%Y%m%d)" -N ""

# ✓ Copier la clé publique
ssh-copy-id -i ~/.ssh/id_sshfs.pub utilisateur@serveur

# ✓ Ou manuellement
cat ~/.ssh/id_sshfs.pub | ssh utilisateur@serveur 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'

# ✓ Fixer permissions sur serveur
ssh utilisateur@serveur 'chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys'

# ✓ Tester directement
ssh -i ~/.ssh/id_sshfs utilisateur@serveur "echo OK"
```

### Problème 2 : "No such file or directory" au Montage

#### Diagnostic

```bash
# 1. Vérifier que le chemin distant existe
ssh utilisateur@serveur "ls -la /data"
# Si n'existe pas, créer :
ssh utilisateur@serveur "mkdir -p /data"

# 2. Vérifier les permissions
ssh utilisateur@serveur "ls -ld /data"
# Doit avoir au minimum 755

# 3. Tester SFTP directement
sftp utilisateur@serveur
> cd /data
> ls
> quit
```

#### Solutions

```bash
# ✓ Créer le répertoire sur serveur
ssh utilisateur@serveur "mkdir -p /data && chmod 755 /data"

# ✓ Ou via SFTP
sftp utilisateur@serveur << EOF
mkdir data
chmod 755 data
quit
EOF

# ✓ Puis retry montage
sshfs -C utilisateur@serveur:/data ~/mnt/data
```

### Problème 3 : "Transport endpoint is not connected"

#### Diagnostic

```bash
# Montage figé ou déconnecté

# 1. Vérifier si montage existe
mount | grep sshfs

# 2. Essayer d'accéder
ls ~/mnt/data 2>&1

# 3. Vérifier les processus SSHFS
ps aux | grep -E "[s]shfs"

# 4. Vérifier la connexion SSH
ping -c 3 serveur.exemple.com
ssh -o ConnectTimeout=5 utilisateur@serveur "echo OK"
```

#### Solutions

```bash
# ✓ Si reconnect est activé
# Attendre quelques secondes, devrait se reconnecter

# ✓ Sinon, démonter et remmonter
fusermount -uz ~/mnt/data
sleep 2
sshfs -C -o reconnect,ServerAliveInterval=300 utilisateur@serveur:/data ~/mnt/data

# ✓ Script d'auto-reconnexion
while ! mountpoint -q ~/mnt/data; do
    echo "Remontage..."
    mkdir -p ~/mnt/data
    sshfs -C -o reconnect utilisateur@serveur:/data ~/mnt/data 2>/dev/null
    sleep 5
done
```

### Problème 4 : Accès Très Lent ou Figé

#### Diagnostic Performance

```bash
# 1. Tester la latence SSH
time ssh utilisateur@serveur "echo OK"
# Si > 5 secondes, problème réseau

# 2. Tester la bande passante brute
scp utilisateur@serveur:/tmp/1gb.file ~/test.file

# 3. Vérifier la charge serveur
ssh utilisateur@serveur "uptime && free -h"

# 4. Vérifier les inodes utilisés
df -i ~/mnt/data

# 5. Monitor la connexion SSH en temps réel
watch -n 1 'netstat -tlnp | grep ":22" || ss -tlnp | grep ":22"'

# 6. Vérifier buffer cache
cat /proc/sys/vm/dirty_ratio
```

#### Solutions

```bash
# ✓ Augmenter le timeout SSH
sshfs -C \
      -o ConnectTimeout=60 \
      -o ServerAliveInterval=300 \
      -o ServerAliveCountMax=5 \
      utilisateur@serveur:/data ~/mnt/data

# ✓ Désactiver cache si écritures intensives
sshfs -C -o direct_io utilisateur@serveur:/data ~/mnt/data

# ✓ Ou réduire le timeout du cache
sshfs -C -o cache_timeout=60 utilisateur@serveur:/data ~/mnt/data

# ✓ Limiter les sessions SSH
sshfs -C -o max_conns=2 utilisateur@serveur:/data ~/mnt/data

# ✓ Vérifier buffer TCP
sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
```

### Problème 5 : "Device or resource busy" au Démontage

#### Diagnostic

```bash
# 1. Voir les processus utilisant le montage
lsof ~/mnt/data
# Lister tous les FDs ouverts

# 2. Voir qui accède au montage
sudo fuser -m ~/mnt/data

# 3. Vérifier le répertoire courant
pwd
# Si c'est ~/mnt/data, changer de répertoire
cd ~

# 4. Lister les fichiers ouverts par applicaton
ps aux | grep -E "[s]shfs|[s]ftp" | awk '{print $2}' | xargs lsof -p 2>/dev/null | head -20
```

#### Solutions

```bash
# ✓ Fermer les applications qui utilisent le montage
lsof ~/mnt/data | awk 'NR>1 {print $2}' | xargs kill -9

# ✓ Ou identifier et fermer manuellement
lsof ~/mnt/data | grep -v COMMAND
# Tuer les PID listés

# ✓ Changer de répertoire courant
cd ~
ls

# ✓ Puis démontage normal
fusermount -u ~/mnt/data

# ✓ Si ça échoue, forcer
fusermount -uz ~/mnt/data

# ✓ Vérifier le démontage
mount | grep sshfs
```

---

## 🔐 Sécurité Avancée

### Montage avec SSH Agent et Passphrase

```bash
#!/bin/bash
# Utiliser SSH Agent pour gérer passphrase

# 1. Démarrer l'agent (si pas déjà fait)
eval "$(ssh-agent -s)"

# 2. Charger la clé
ssh-add ~/.ssh/id_sshfs
# Demande de passphrase

# 3. Montage (clé automatiquement fournie par agent)
sshfs -C -o reconnect utilisateur@serveur:/data ~/mnt/data

# 4. Vérifier la clé en agent
ssh-add -l

# 5. Plus tard, retirer du agent
ssh-add -d ~/.ssh/id_sshfs
```

### Restriction de Clé SSH (Options ANSSI)

```bash
# Sur le serveur, restreindre la clé publique
# Format : option1,option2 ssh-ed25519 AAAA... comment

# Restreindre à SFTP uniquement
command="/usr/lib/openssh/sftp-server",no-pty,restrict ssh-ed25519 AAAA... sshfs-user@client

# Restreindre par adresse IP
from="192.168.1.0/24" command="/usr/lib/openssh/sftp-server",no-pty,restrict ssh-ed25519 AAAA... sshfs-user@client

# Options de sécurité ANSSI
# command="..."               → Force SSH en SFTP seulement
# no-pty                      → Pas de terminal interactif
# restrict                    → Désactiver tunneling, agent forwarding
# from="..."                  → Limiter aux IPs autorisées
# no-port-forwarding         → Interdire port forwarding
# no-X11-forwarding          → Interdire X11
# no-user-rc                 → Ne pas charger .bashrc
```

### Montage Chiffré (Couche Supplémentaire)

```bash
#!/bin/bash
# Chiffrer le montage SSHFS avec encfs (couche supplémentaire)

MOUNT_POINT="$HOME/mnt/encrypted"
SSHFS_MOUNT="$HOME/mnt/sshfs-base"

# 1. Monter SSHFS normal
mkdir -p "$SSHFS_MOUNT"
sshfs -C utilisateur@serveur:/data "$SSHFS_MOUNT"

# 2. Installer encfs
sudo apt install -y encfs

# 3. Créer répertoire chiffré par-dessus SSHFS
mkdir -p "$MOUNT_POINT"
encfs "$SSHFS_MOUNT/.encfs" "$MOUNT_POINT"
# Crée une passphrase

# 4. Utiliser le montage chiffré
cp ~/sensitive-file "$MOUNT_POINT/"

# 5. Démonter dans l'ordre inverse
fusermount -u "$MOUNT_POINT"  # encfs d'abord
fusermount -u "$SSHFS_MOUNT"  # SSHFS ensuite
```

### Audit Sécurité Montage SSHFS

```bash
#!/bin/bash
# Vérifier la configuration sécurité SSHFS

echo "=== Audit Sécurité SSHFS ==="

# 1. Vérifier les clés existantes
echo "Clés SSHFS :"
ls -la ~/.ssh/id_sshfs*

# 2. Vérifier les fingerprints
echo -e "\nFingerprints :"
ssh-keygen -l -f ~/.ssh/id_sshfs
ssh-keygen -l -f ~/.ssh/id_sshfs.pub

# 3. Vérifier les montages actifs
echo -e "\nMontages SSHFS actifs :"
mount | grep sshfs

# 4. Vérifier les permissions des montages
echo -e "\nPermissions des points de montage :"
mount | grep sshfs | awk '{print $3}' | while read m; do
    echo -n "$m : "
    stat -c "%A" "$m"
done

# 5. Vérifier ~/.ssh/config
echo -e "\nHôtes SSHFS dans SSH config :"
grep -A 3 "Host.*" ~/.ssh/config 2>/dev/null | grep -E "Host|HostName|User|Identity"

# 6. Vérifier les processus
echo -e "\nProcessus SSHFS :"
ps aux | grep -E "[s]shfs"

# 7. Vérifier les connexions SSH
echo -e "\nConnexions SSH actives :"
netstat -tnp 2>/dev/null | grep ":22" | wc -l

# 8. Logs des tentatives
echo -e "\nDernières tentatives de connexion :"
sudo journalctl -u ssh --since "1 hour ago" | grep -E "Failed|Accepted" | tail -5
```

---

## 📊 Checklists Spécialisées

### Checklist Déploiement Production SSHFS

- [ ] Clé ED25519 dédiée générée
- [ ] Clé publique déployée sur serveur
- [ ] SSH Config (~/.ssh/config) configuré
- [ ] Options SSHFS ANSSI appliquées (reconnect, ServerAlive)
- [ ] Répertoire de montage créé (permissions 700)
- [ ] Montage fonctionne
- [ ] Accès fichier fonctionne
- [ ] Montage automatisé (cron ou systemd)
- [ ] Démontage automatisé de secours
- [ ] Logs configurés
- [ ] Documenté dans runbook

### Checklist Sécurité ANSSI

- [ ] Authentification par clé, pas mot de passe
- [ ] Clé ED25519 (pas RSA)
- [ ] Passphrase sur clé (≥20 chars)
- [ ] Permissions clé privée : 600
- [ ] Permissions clé publique : 644
- [ ] Utilisateur dédié non-root sur serveur
- [ ] Restrictions de clé SSH (command, from, no-pty)
- [ ] Chiffrement SSH activé (chacha20, aes256)
- [ ] Logging de toutes les connexions
- [ ] Monitoring des montages
- [ ] Politique de rotation clés
- [ ] Plan de récupération d'urgence

---

## 💡 Tips & Tricks Avancés

### Montage SSHFS dans Docker

```dockerfile
# Dockerfile avec SSHFS

FROM debian:12

RUN apt update && apt install -y sshfs openssh-client fuse

# Ajouter clé SSH
COPY id_sshfs /root/.ssh/id_sshfs
RUN chmod 600 /root/.ssh/id_sshfs

# Créer point de montage
RUN mkdir -p /mnt/data

# Script de démarrage
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
```

```bash
#!/bin/bash
# entrypoint.sh

# Monter SSHFS
sshfs -o allow_other utilisateur@serveur:/data /mnt/data

# Garder le conteneur actif
exec "$@"
```

### Montage SSHFS avec Retry Automatique

```bash
#!/bin/bash
# Script avec retry exponentiel

SSHFS_HOST="$1"
REMOTE_PATH="$2"
MOUNT_POINT="$3"
MAX_RETRIES=5
RETRY_DELAY=5

for attempt in $(seq 1 $MAX_RETRIES); do
    echo "[Tentative $attempt/$MAX_RETRIES] Montage de $SSHFS_HOST"
    
    if sshfs -C -o reconnect "$SSHFS_HOST:$REMOTE_PATH" "$MOUNT_POINT"; then
        echo "[✓] Montage réussi"
        exit 0
    fi
    
    if [ $attempt -lt $MAX_RETRIES ]; then
        sleep $((RETRY_DELAY * attempt))
    fi
done

echo "[✗] Échec après $MAX_RETRIES tentatives"
exit 1
```

### Monitoring Montage avec Prometheus

```bash
#!/bin/bash
# Exporter les métriques SSHFS pour Prometheus

# Métriques à récupérer
active_mounts=$(mount | grep -c sshfs)
sshfs_processes=$(ps aux | grep -c "[s]shfs")
total_size=$(df -h | grep sshfs | awk '{print $2}' | sed 's/G//' | awk '{s+=$1} END {print s}')

# Format Prometheus
echo "# HELP sshfs_active_mounts Number of active SSHFS mounts"
echo "# TYPE sshfs_active_mounts gauge"
echo "sshfs_active_mounts $active_mounts"

echo "# HELP sshfs_processes Number of SSHFS processes"
echo "# TYPE sshfs_processes gauge"
echo "sshfs_processes $sshfs_processes"

echo "# HELP sshfs_total_size_gb Total size of SSHFS mounts in GB"
echo "# TYPE sshfs_total_size_gb gauge"
echo "sshfs_total_size_gb $total_size"
```

---

**Document pratique - Mise à jour 16 novembre 2025**
**Pour questions avancées : Consulter Guide Complet ou documentation OpenSSH/FUSE**
