# SCP - Astuces, Dépannage et Solutions Avancées

---

## 🛠️ Astuces Pratiques

### Alias Bash pour SCP Récurrents

```bash
# Ajouter à ~/.bashrc

alias scp-prod="scp -C -p -i ~/.ssh/id_scp"
alias scp-backup="scp -C -p -l 2048 -i ~/.ssh/id_scp"
alias scp-fast="scp -C -p -i ~/.ssh/id_scp -o BatchMode=yes"

# Utilisation
scp-prod ~/file.txt user@prod:/data/
scp-backup ~/large.zip user@backup:/backups/
scp-fast ~/config.tar user@server:/opt/
```

### Variables Réutilisables SCP

```bash
# Créer ~/.config/scp-config

export SCP_USER="scp-user"
export SCP_HOST_PROD="prod.exemple.com"
export SCP_HOST_BACKUP="backup.interne"
export SCP_HOST_DEV="dev.lab"

export SCP_KEY="$HOME/.ssh/id_scp"
export SCP_DEFAULT_OPTS="-C -p -i $SCP_KEY"
export SCP_BACKUP_OPTS="-C -p -l 2048 -i $SCP_KEY"

# Source dans ~/.bashrc
source ~/.config/scp-config

# Utiliser
scp $SCP_DEFAULT_OPTS ~/file.txt $SCP_USER@$SCP_HOST_PROD:/data/
```

### Fonction Bash : Transfert avec Retry

```bash
# Ajouter à ~/.bashrc

scp_retry() {
    local file="$1"
    local dest="$2"
    local max_retries=3
    local retry_delay=5
    
    for attempt in $(seq 1 $max_retries); do
        echo "[Tentative $attempt/$max_retries] Transfert de $(basename $file)"
        
        if scp -C -p -i ~/.ssh/id_scp "$file" "$dest"; then
            echo "[✓] Transfert réussi"
            return 0
        fi
        
        if [ $attempt -lt $max_retries ]; then
            echo "[!] Attente de ${retry_delay}s avant retry..."
            sleep $retry_delay
        fi
    done
    
    echo "[✗] Échec après $max_retries tentatives"
    return 1
}

# Utilisation
scp_retry ~/important.tar user@backup:/backups/
```

### Fonction : Transfert avec Vérification

```bash
scp_verify() {
    local file="$1"
    local dest="$2"
    
    local sha_src=$(sha256sum "$file" | awk '{print $1}')
    echo "[*] Empreinte source : $sha_src"
    
    scp -C -p -i ~/.ssh/id_scp "$file" "$dest/" || return 1
    
    local filename=$(basename "$file")
    local host=$(echo "$dest" | cut -d: -f1)
    local path=$(echo "$dest" | cut -d: -f2)
    
    local sha_dst=$(ssh -i ~/.ssh/id_scp "$host" "sha256sum $path/$filename" | awk '{print $1}')
    echo "[*] Empreinte distante : $sha_dst"
    
    if [ "$sha_src" = "$sha_dst" ]; then
        echo "[✓] Intégrité vérifiée"
        return 0
    else
        echo "[✗] Erreur d'intégrité"
        return 1
    fi
}

# Utilisation
scp_verify ~/critical.db user@server:/backups/
```

### Transferts Parallèles Optimisés

```bash
#!/bin/bash
# Transférer plusieurs fichiers en parallèle avec limite

transfer_parallel() {
    local max_parallel=4
    local dest_host="$1"
    shift
    local files=("$@")
    
    echo "[*] Transfert de ${#files[@]} fichiers (max $max_parallel en parallèle)"
    
    for i in "${!files[@]}"; do
        # Limiter le nombre de processus
        while [ $(jobs -r -p | wc -l) -ge $max_parallel ]; do
            sleep 0.5
        done
        
        echo "[*] [$(($i+1))/${#files[@]}] Transfert : $(basename ${files[$i]})"
        scp -C -p -i ~/.ssh/id_scp "${files[$i]}" "$dest_host:/tmp/" &
    done
    
    # Attendre tous les processus
    wait
    echo "[✓] Tous les transferts complétés"
}

# Utilisation
transfer_parallel "user@server" ~/file1.tar ~/file2.tar ~/file3.tar
```

### Transfert avec Limite Bande Passante Dynamique

```bash
scp_bw_limited() {
    local file="$1"
    local dest="$2"
    local bandwidth_limit="${3:-512}"  # KB/s, défaut 512
    
    # Mesurer la bande passante disponible
    local available_bw=$(speedtest-cli --simple 2>/dev/null | cut -d',' -f2)
    
    if [ -n "$available_bw" ]; then
        # Utiliser 50% de la bande disponible
        bandwidth_limit=$(echo "$available_bw * 512 / 1" | bc)
    fi
    
    echo "[*] Limite bande passante : ${bandwidth_limit} KB/s"
    
    scp -C -p -l "$bandwidth_limit" -i ~/.ssh/id_scp "$file" "$dest/"
}

# Utilisation
scp_bw_limited ~/large.iso user@server:/backups/
```

---

## 🔍 Dépannage Détaillé

### Problème 1 : "Permission denied (publickey)"

#### Diagnostic Complet

```bash
# 1. Vérifier que la clé existe
ls -la ~/.ssh/id_scp
# Doit afficher : -rw------- (permissions 600)

# 2. Tester SSH directement
ssh -i ~/.ssh/id_scp -v scp-user@serveur echo "OK"
# Chercher dans output : "Authentications" et "Accepted"

# 3. Vérifier authorized_keys sur serveur
ssh scp-user@serveur "cat ~/.ssh/authorized_keys | wc -l"

# 4. Vérifier que la clé publique est présente
cat ~/.ssh/id_scp.pub
ssh scp-user@serveur "grep $(cat ~/.ssh/id_scp.pub | cut -d' ' -f2 | cut -c1-20) ~/.ssh/authorized_keys"

# 5. Vérifier les permissions authorized_keys
ssh scp-user@serveur "ls -la ~/.ssh/authorized_keys"
# Doit être : -rw------- (600)

# 6. Vérifier les permissions ~/.ssh
ssh scp-user@serveur "ls -ld ~/.ssh/"
# Doit être : drwx------ (700)
```

#### Solutions

```bash
# ✓ Régénérer et redéployer la clé
ssh-keygen -t ed25519 -f ~/.ssh/id_scp -C "scp-$(date +%Y%m%d)" -N ""

# ✓ Copier la clé publique
ssh-copy-id -i ~/.ssh/id_scp.pub scp-user@serveur

# ✓ Ou manuellement
cat ~/.ssh/id_scp.pub | ssh scp-user@serveur 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'

# ✓ Fixer permissions sur serveur
ssh scp-user@serveur 'chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys'

# ✓ Tester directement
scp -v -i ~/.ssh/id_scp ~/test.txt scp-user@serveur:/tmp/
```

### Problème 2 : "No space left on device"

#### Diagnostic

```bash
# 1. Vérifier l'espace disponible
ssh scp-user@serveur "df -h"

# 2. Vérifier l'utilisation du répertoire destination
ssh scp-user@serveur "du -sh /data /backups"

# 3. Lister les gros fichiers
ssh scp-user@serveur "find /data -size +1G -type f"

# 4. Vérifier les inodes
ssh scp-user@serveur "df -i"
```

#### Solutions

```bash
# ✓ Nettoyer l'espace
ssh scp-user@serveur "rm -rf /data/old_backups/*"

# ✓ Archiver les anciens fichiers
ssh scp-user@serveur "tar czf /archive/old_backups.tar.gz /data/old_backups && rm -rf /data/old_backups"

# ✓ Compresser avant transfert
gzip ~/large.file
scp -C ~/large.file.gz scp-user@serveur:/data/

# ✓ Transférer en parties
split -b 1G ~/large.iso ~/large_part_
for part in ~/large_part_*; do
    scp -C "$part" scp-user@serveur:/data/
done
ssh scp-user@serveur "cat /data/large_part_* > /data/large.iso && rm /data/large_part_*"
```

### Problème 3 : Transfert Très Lent

#### Diagnostic Performance

```bash
# 1. Mesurer la latence
ping -c 5 serveur.exemple.com | grep "min/avg/max"

# 2. Tester petit fichier
time scp -C ~/tiny.txt scp-user@serveur:/tmp/

# 3. Tester gros fichier
time scp -C ~/1gb.file scp-user@serveur:/tmp/

# 4. Tester sans compression
time scp ~/1gb.file scp-user@serveur:/tmp/

# 5. Vérifier la charge serveur
ssh scp-user@serveur "uptime && free -h"

# 6. Vérifier le débit TCP
iperf3 -c serveur.exemple.com -t 10

# 7. Profiler la session SSH
ssh -v scp-user@serveur "echo OK" 2>&1 | grep -E "kex|cipher|mac|compress"
```

#### Solutions Performance

```bash
# ✓ Activer compression
scp -C ~/file scp-user@serveur:/tmp/

# ✓ Désactiver compression (parfois plus rapide)
scp -o Compression=no ~/file scp-user@serveur:/tmp/

# ✓ Utiliser rsync (plus rapide pour fichiers)
rsync -avz -e "ssh -i ~/.ssh/id_scp -C" ~/file scp-user@serveur:/tmp/

# ✓ Augmenter buffer TCP kernel
sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"

# ✓ Utiliser protocole SSH3 si disponible
# Recompiler OpenSSH avec support SSH3

# ✓ Multiplier les connexions SSH
for i in {1..4}; do
    scp -C ~/part$i scp-user@serveur:/tmp/ &
done
wait
```

### Problème 4 : "Connection refused" ou "Connection timed out"

#### Diagnostic Réseau

```bash
# 1. Vérifier la connexion basique
ping -c 3 serveur.exemple.com

# 2. Tester le port SSH
telnet serveur.exemple.com 22
# ou
nc -zv serveur.exemple.com 22

# 3. Vérifier avec route
traceroute serveur.exemple.com

# 4. Vérifier les pare-feu
sudo iptables -L | grep ":22"
sudo nftables list ruleset | grep "port 22"

# 5. Sur serveur, vérifier SSH écoute
sudo ss -tlnp | grep ":22"

# 6. Vérifier les logs SSH serveur
sudo journalctl -u ssh -n 20
```

#### Solutions Connectivité

```bash
# ✓ Utiliser port alternatif
scp -P 2222 ~/file scp-user@serveur:/tmp/

# ✓ Via bastion SSH
scp -o ProxyCommand="ssh -i ~/.ssh/id_scp jumphost ssh %h %p" ~/file scp-user@serveur:/tmp/

# ✓ Vérifier firewall client
sudo firewall-cmd --list-all

# ✓ Vérifier firewall serveur
sudo nft list ruleset | grep "22"

# ✓ Ouvrir port sur serveur
sudo ufw allow 22/tcp
sudo nft add rule inet filter INPUT tcp dport 22 accept
```

### Problème 5 : "Stalled" ou Transfert Figé

#### Diagnostic Timeout

```bash
# 1. Vérifier les timeouts SSH
cat ~/.ssh/config | grep -E "Timeout|Alive"

# 2. Vérifier la connexion en cours
netstat -tnp 2>/dev/null | grep ":22"

# 3. Voir les processus SCP
ps aux | grep -E "[s]cp|ssh"

# 4. Logs en temps réel
sudo journalctl -u ssh -f

# 5. Monitor avec timeout
timeout 30 scp ~/file scp-user@serveur:/tmp/
# Si > 30 sec, tue la commande
```

#### Solutions Timeout

```bash
# ✓ Ajouter keep-alive SSH
scp -o ServerAliveInterval=300 -o ServerAliveCountMax=3 ~/file scp-user@serveur:/tmp/

# ✓ Via SSH config
echo "ServerAliveInterval 300" >> ~/.ssh/config
echo "ServerAliveCountMax 3" >> ~/.ssh/config

# ✓ Utiliser BatchMode
scp -o BatchMode=yes ~/file scp-user@serveur:/tmp/

# ✓ Timeout global
timeout 300 scp ~/large.file scp-user@serveur:/tmp/

# ✓ Tuer processus stuck
pkill -9 scp
pkill -9 ssh
```

---

## 🔐 Sécurité Avancée

### Transfert Chiffré Double (GPG + SCP)

```bash
#!/bin/bash
# Chiffrer avant SCP pour donnée sensible

FILE="$1"
DEST_HOST="$2"
DEST_PATH="${3:-.}"

echo "[*] Chiffrement GPG..."
gpg --symmetric --cipher-algo AES256 "$FILE"

ENCRYPTED="${FILE}.gpg"

echo "[*] Transfert SCP..."
scp -C -p -i ~/.ssh/id_scp "$ENCRYPTED" "$DEST_HOST:$DEST_PATH/"

echo "[*] Vérification..."
SHA_SRC=$(sha256sum "$ENCRYPTED" | awk '{print $1}')
SHA_DST=$(ssh -i ~/.ssh/id_scp "$DEST_HOST" "sha256sum $DEST_PATH/$ENCRYPTED" | awk '{print $1}')

if [ "$SHA_SRC" = "$SHA_DST" ]; then
    echo "[✓] Transfert sécurisé complété"
    shred -u "$ENCRYPTED"  # Supprimer localement
else
    echo "[✗] Erreur d'intégrité"
fi
```

### Audit Logging SCP

```bash
#!/bin/bash
# Logger tous les transferts SCP

wrapper_scp_logged() {
    local log_file="/tmp/scp_transfers.log"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Logger l'appel
    echo "[$timestamp] User: $(whoami) | Command: scp $@" >> "$log_file"
    
    # Exécuter SCP
    /usr/bin/scp "$@"
    local result=$?
    
    # Logger le résultat
    if [ $result -eq 0 ]; then
        echo "[$timestamp] SUCCÈS" >> "$log_file"
    else
        echo "[$timestamp] ERREUR (code $result)" >> "$log_file"
    fi
    
    return $result
}

# Utiliser
wrapper_scp_logged ~/file scp-user@serveur:/tmp/
```

---

## 📊 Checklists Spécialisées

### Checklist Déploiement SCP Production

- [ ] Clé ED25519 dédiée générée
- [ ] Clé publique déployée sur serveur
- [ ] SSH Config (~/.ssh/config) configuré
- [ ] Utilisateur SCP non-root créé
- [ ] Répertoire destination créé (permissions 750)
- [ ] Test transfert petit fichier réussi
- [ ] Vérification d'intégrité fonctionne
- [ ] Logs SSH configurés
- [ ] Monitoring des transferts actif
- [ ] Script de sauvegarde automatisé
- [ ] Planification cron configurée
- [ ] Documentation runbook complète

### Checklist Sécurité ANSSI

- [ ] Authentification par clé ED25519
- [ ] Pas d'authentification par mot de passe
- [ ] Passphrase sur clé privée
- [ ] Permissions clé privée : 600
- [ ] Permissions clé publique : 644
- [ ] Chiffrement SSH activé (chacha20, aes256)
- [ ] Vérification intégrité après chaque transfert
- [ ] Logging de tous les transferts
- [ ] Utilisateur SCP dédié (non-root)
- [ ] Accès restreint à répertoires spécifiques
- [ ] Analyse des fichiers après réception
- [ ] Politique de rotation des clés

---

## 💡 Tips & Tricks Avancés

### SCP dans Pipeline Shell

```bash
# Chaîner les commandes
tar czf - ~/data | scp -C - user@server:/tmp/backup.tar.gz

# Décompresser directement après réception
scp user@server:/tmp/backup.tar.gz - | tar xzf -

# Pipeline multi-étapes
cat ~/sensitive.data | gpg -c | scp -C - user@server:/backups/
```

### SCP avec GNU Parallel

```bash
# Utiliser parallel pour transferts parallèles avancés

ls ~/data/*.tar | parallel -j 4 scp -C {} user@server:/backups/

# Ou avec find
find ~/data -name "*.tar" -print0 | parallel -0 -j 4 scp -C {} user@server:/backups/
```

### Monitoring Transfert Temps Réel

```bash
# Via pv (pipe viewer)
pv ~/large.iso | scp -C -q - user@server:/tmp/

# Voir le progress
cat ~/large.iso | pv -L 10m | scp -C -q - user@server:/tmp/
# Limite à 10 MB/s avec visualisation
```

### SCP dans Dockerfile

```dockerfile
FROM debian:12

RUN apt update && apt install -y openssh-client

COPY id_scp /root/.ssh/id_scp
RUN chmod 600 /root/.ssh/id_scp

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
```

```bash
#!/bin/bash
# entrypoint.sh

SCP_FILE="$1"
SCP_DEST="$2"

scp -C -p -i /root/.ssh/id_scp "$SCP_FILE" "$SCP_DEST/"
```

---

**Document pratique - Mise à jour 16 novembre 2025**
**Pour questions avancées : Consulter Guide Complet ou documentation OpenSSH**
