# SCP - Transfert de Fichiers Sécurisé par SSH
## Guide Complet et Rigoureux

---

## 📋 Table des Matières

1. [Fondamentaux du Transfert Sécurisé](#fondamentaux)
2. [Recommandations ANSSI](#anssi)
3. [Architecture et Protocole](#architecture)
4. [Installation et Prérequis](#installation)
5. [Syntaxe et Paramètres](#syntaxe)
6. [Transferts de Base](#transferts-base)
7. [Authentification par Clé](#authentification)
8. [Transferts Avancés](#avances)
9. [Performance et Optimisation](#performance)
10. [Sécurité et Audit](#securite)
11. [Persistance et Automatisation](#persistance)
12. [Dépannage et Monitoring](#debogage)

---

## 🔐 Fondamentaux du Transfert Sécurisé {#fondamentaux}

### Qu'est-ce que SCP ?

SCP (Secure CoPy) est un utilitaire de transfert de fichiers sécurisé qui utilise SSH (Secure Shell) pour établir une connexion chiffrée entre deux machines. Contrairement à FTP ou SFTP, SCP est optimisé pour :

- **Chiffrement obligatoire** : Tous les transferts sont chiffrés par défaut (TLS 1.3+)
- **Authentification cryptographique** : Utilise les clés SSH (ED25519 recommandé)
- **Simplicité d'utilisation** : Interface de ligne de commande intuitive
- **Performance** : Optimisé pour les transferts de masse
- **Portabilité** : Disponible nativement sur tous les systèmes UNIX
- **Intégration** : Facilement intégrable dans scripts et pipelines

### Cas d'Usage Courants

```
Scenario 1 : Sauvegarde quotidienne vers serveur distant
  scp ~/données utilisateur@backup:/backups/$(date +%Y%m%d)
  
Scenario 2 : Déploiement de fichiers sur serveurs multiples
  for srv in server{1..10}; do scp app.jar admin@$srv:/opt/app/; done
  
Scenario 3 : Récupération de logs d'audit pour analyse centralisée
  scp admin@serveur:/var/log/auth.log ~/audit/$(date +%Y%m%d).log
  
Scenario 4 : Synchronisation de configuration distribuée
  scp -r ~/config/* root@prod-nodes:/etc/app/config/
  
Scenario 5 : Transfert de bases données chiffrées
  scp dump.sql.gpg utilisateur@backup:/backups/
```

### Comparaison avec Alternatives

| Protocole | Chiffrage | Port | Serveur | Vitesse | Sécurité |
|-----------|-----------|------|---------|---------|----------|
| **SCP** | ✓ Natif | 22 | SSH std | Excellente | Excellente |
| SFTP | ✓ Natif | 22 | SSH std | Bonne | Excellente |
| FTP | ✗ Non | 21 | Dédié | Excellente | Très faible |
| RSYNC | ✓ Via SSH | 873 | Dédié | Excellente | Bonne |
| HTTP(S) | ✓ Optionnel | 80/443 | HTTP | Moyenne | Moyenne |

**Avantage SCP** : Chiffrage natif + port SSH unique + pas de serveur dédié

---

## 🛡️ Recommandations ANSSI {#anssi}

### Source Officielle ANSSI

**Document** : *Guide d'Hygiène Informatique* (édition 2023) et *Recommandations pour la Sécurité des Transferts Distants*

**Lien** : https://cyber.gouv.fr/ (rubrique publications - documents techniques)

### Recommandations Clés d'ANSSI pour SCP

#### 1️⃣ Authentification par Clé Obligatoire

```
✓ OBLIGATOIRE : Authentification par clé ED25519
✗ REFUSER : Authentification par mot de passe interactive
✓ OBLIGATOIRE : Passphrase sur clé privée (≥20 caractères)

Raison ANSSI :
- Mot de passe = risque brute-force sur chaque transfert
- Clé ED25519 = résistance cryptographique supérieure
- Passphrase = protection contre compromission poste local
```

**Implémentation** :
```bash
# Générer clé dédiée SCP
ssh-keygen -t ed25519 -f ~/.ssh/id_scp -C "scp-$(date +%Y%m%d)"

# Vérifier
chmod 600 ~/.ssh/id_scp
ls -la ~/.ssh/id_scp*
```

#### 2️⃣ Chiffrement du Trafic Fort

```
✓ OBLIGATOIRE : SSH Protocol 2 uniquement
✓ OBLIGATOIRE : Chiffrement strong (chacha20-poly1305, aes256-gcm)
✓ OBLIGATOIRE : Authentification de message (hmac-sha2-512-etm)

Configuration ANSSI minimale :
  KexAlgorithms curve25519-sha256
  Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
  MACs hmac-sha2-512-etm@openssh.com
```

#### 3️⃣ Vérification d'Intégrité

```
✓ OBLIGATOIRE : Vérifier l'empreinte SHA256 des fichiers après transfert
✓ OBLIGATOIRE : Comparer sur source et destination
✓ Raisonnement : Détecter les modifications en transit (même rare)

Commande ANSSI :
  sha256sum fichier | tee /tmp/checksum.txt
  scp utilisateur@serveur:/data/fichier ~/fichier
  ssh utilisateur@serveur "sha256sum /data/fichier"
  # Comparer les deux empreintes
```

#### 4️⃣ Restriction de Permissions

```
✓ OBLIGATOIRE : Permissions restrictives sur fichiers transférés
✓ OBLIGATOIRE : chmod correct immédiatement après transfert
✓ Refuser : Permissions 777 sur aucun fichier transféré

Raison ANSSI :
- Fichier en lecture seule (chmod 644) pendant transfert = risque minimal
- Exécutables (chmod 755) sur serveur de confiance uniquement
- Configuration (chmod 600) en lecture propriétaire uniquement
```

#### 5️⃣ Logging et Audit

```
✓ OBLIGATOIRE : Logger chaque transfert SCP
✓ OBLIGATOIRE : Enregistrer : timestamp, source, destination, taille, utilisateur
✓ Fréquence : Temps réel ou horaire minimum
✓ Rétention : 90 jours minimum

Configuration ANSSI :
  LogLevel VERBOSE dans /etc/ssh/sshd_config
  Journalctl -u ssh --since "24 hours ago"
```

#### 6️⃣ Transferts de Données Sensibles

```
✓ OBLIGATOIRE : Chiffrer avant SCP (GPG/OpenSSL)
✓ OBLIGATOIRE : Authentification mutuelle (certificats)
✓ Recommandé : Transferts uniquement depuis réseau sécurisé
✓ Refuser : SCP de données non chiffrées via réseau public

Workflow ANSSI pour données sensibles :
  1. Chiffrer : gpg -c fichier_sensible
  2. Transférer : scp fichier_sensible.gpg user@serveur:/
  3. Vérifier : sha256sum fichier_sensible.gpg
  4. Déchiffrer : gpg -d fichier_sensible.gpg
```

#### 7️⃣ Restriction de Répertoires

```
✓ OBLIGATOIRE : Créer utilisateur SCP dédié non-root
✓ OBLIGATOIRE : Restreindre à répertoires spécifiques (chroot)
✓ Refuser : Accès root pour transferts SCP

Configuration chroot sur serveur :
  Match User scp-user
      ChrootDirectory /data/scp-transfers
      ForceCommand /usr/lib/openssh/sftp-server
      AllowTcpForwarding no
      PermitTTY no
```

#### 8️⃣ Inspection des Fichiers

```
✓ OBLIGATOIRE : Analyser les fichiers reçus avant utilisation
✓ Refuser : Exécuter directement fichiers téléchargés
✗ Raisonnement : Possibilité de malware ou modification

Vérifications ANSSI :
  file fichier_recu           # Type du fichier
  file --mime-type fichier_recu  # MIME type
  strings fichier_recu | head  # Contenu texte si applicable
  clamav --scan fichier_recu  # Antivirus (si nécessaire)
```

---

## 🏗️ Architecture et Protocole {#architecture}

### Protocole SCP

SCP fonctionne selon le protocole RCP (Remote Copy) transmis via SSH :

```
┌─────────────────────────────────────────────────────────┐
│                    CLIENT LOCAL                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Utilisateur execute : scp local.file user@host:/dst    │
│          ↓                                               │
│  Client SCP parse la commande                           │
│          ↓                                               │
│  Établit connexion SSH vers host:22                     │
│          ↓                                               │
│  Authentification (clé ED25519)                         │
│          ↓                                               │
│  Lance scp serveur sur host (en arrière-plan)           │
│          ↓                                               │
│  Protocole RCP : échange fichiers                       │
│          ↓                                               │
│  Ferme connexion SSH                                    │
│                                                          │
└─────────────────────────────────────────────────────────┘
              ↓ SSH chiffré (chacha20-poly1305)
┌─────────────────────────────────────────────────────────┐
│                   SERVEUR DISTANT                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  SSH Daemon (sshd) accepte connexion                    │
│          ↓                                               │
│  Vérifie authentification                               │
│          ↓                                               │
│  Lance process scp serveur                              │
│          ↓                                               │
│  Reçoit/envoie fichiers selon RCP                       │
│          ↓                                               │
│  Ferme connexion SSH                                    │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Modes de Transfert SCP

**Mode Push** (Client → Serveur)
```
scp local_file utilisateur@serveur:/destination/
  - Valide fichier localement
  - Envoie via SSH
  - Reçoit confirmation serveur
```

**Mode Pull** (Serveur → Client)
```
scp utilisateur@serveur:/data/file ~/destination/
  - Demande fichier distant
  - Reçoit via SSH
  - Valide localement
```

**Mode Recursive** (Répertoires)
```
scp -r utilisateur@serveur:/data/dossier ~/destination/
  - Traverse récursivement les répertoires
  - Transfert tous les fichiers et sous-dossiers
  - Préserve structure de répertoires
```

---

## 📦 Installation et Prérequis {#installation}

### Vérification Prérequis

#### Client

```bash
# 1. Vérifier OpenSSH Client
which scp
scp -V
# Résultat attendu : OpenSSH_8.0+

# 2. Vérifier clés SSH
ls -la ~/.ssh/
# Doit contenir : id_rsa, id_ed25519, ou autre clé

# 3. Vérifier la connexion SSH
ssh -v utilisateur@serveur echo "OK"
# Doit se connecter sans erreur

# 4. Vérifier les permissions ~/.ssh
stat -c "%A" ~/.ssh/
# Résultat attendu : drwx------ (700)
```

#### Serveur

```bash
# 1. Vérifier OpenSSH Server
sudo systemctl status ssh
sshd -V

# 2. Vérifier le subsystem SCP
sudo grep -i "subsystem" /etc/ssh/sshd_config
# Doit contenir : Subsystem sftp /usr/lib/openssh/sftp-server

# 3. Vérifier les ports SSH
sudo ss -tlnp | grep ":22"
# Résultat : LISTEN sur port 22

# 4. Vérifier l'utilisateur SSH
getent passwd utilisateur-scp
```

### Installation sur Debian/Ubuntu

#### Client

```bash
# 1. OpenSSH est généralement inclus
sudo apt update
sudo apt install -y openssh-client

# 2. Vérifier l'installation
scp -V

# 3. Générer clé SSH si nécessaire
ssh-keygen -t ed25519 -f ~/.ssh/id_scp -C "scp-user@$(date +%Y%m%d)"

# 4. Permissions correctes
chmod 600 ~/.ssh/id_scp
chmod 644 ~/.ssh/id_scp.pub
```

#### Serveur

```bash
# 1. OpenSSH Server devrait déjà être installé
sudo systemctl status ssh

# 2. Si absent, installer
sudo apt install -y openssh-server openssh-sftp-server

# 3. Vérifier la configuration
sudo sshd -t
# Pas de message d'erreur = OK

# 4. Redémarrer si modifié
sudo systemctl restart ssh

# 5. Créer utilisateur SCP dédié
sudo adduser scp-user --shell /usr/sbin/nologin --no-create-home

# 6. Créer répertoire d'accès
sudo mkdir -p /data/scp-transfers
sudo chown scp-user:scp-user /data/scp-transfers
sudo chmod 750 /data/scp-transfers
```

---

## 🔤 Syntaxe et Paramètres {#syntaxe}

### Format de Base

```bash
# Syntaxe générale
scp [options] [[utilisateur@]hôte1:]fichier1 [[utilisateur@]hôte2:]fichier2

# Transfert local → distant
scp ~/fichier.txt utilisateur@serveur:/destination/

# Transfert distant → local
scp utilisateur@serveur:/data/fichier.txt ~/destination/

# Transfert récursif (répertoires)
scp -r ~/dossier utilisateur@serveur:/destination/

# Avec port alternatif
scp -P 2222 ~/fichier.txt utilisateur@serveur:/destination/

# Avec clé spécifique
scp -i ~/.ssh/id_scp ~/fichier.txt utilisateur@serveur:/destination/
```

### Paramètres Essentiels

```bash
# Paramètres courants
scp [OPTIONS] source destination

# Options principales
-P port             → Port SSH alternatif (défaut 22)
-p                  → Préserver timestamps et permissions
-r                  → Récursif (répertoires)
-C                  → Compression SSH
-v                  → Verbose (debug)
-i fichier_clé      → Utiliser fichier clé spécifique
-l limite           → Limiter bande passante (KB/s)
-F config_ssh       → Fichier SSH config alternatif
-4                  → Forcer IPv4
-6                  → Forcer IPv6

# Exemples complets
scp -P 2222 -i ~/.ssh/id_scp -C ~/file user@host:/dst
scp -r -p ~/dir/* user@host:/backup/
scp -l 1024 user@host:/data/huge.iso ~/downloads/
```

### Variables Utiles dans Scripts

```bash
#!/bin/bash
# Variables réutilisables

SCP_USER="utilisateur"
SCP_HOST="serveur.exemple.com"
SCP_PORT="22"
SCP_KEY="$HOME/.ssh/id_scp"
SCP_OPTIONS="-C -p"
DEST_PATH="/data/transfers"

# Utiliser dans scp
scp -P $SCP_PORT -i $SCP_KEY $SCP_OPTIONS \
    ~/file.txt $SCP_USER@$SCP_HOST:$DEST_PATH/

# Ou via alias
alias scp-prod="scp -P $SCP_PORT -i $SCP_KEY $SCP_OPTIONS"
scp-prod ~/file.txt $SCP_USER@$SCP_HOST:$DEST_PATH/
```

---

## 🚀 Transferts de Base {#transferts-base}

### Transfert Simple

```bash
# Push : Client → Serveur
scp ~/document.pdf utilisateur@serveur.exemple.com:/home/utilisateur/

# Pull : Serveur → Client
scp utilisateur@serveur.exemple.com:/etc/config.conf ~/config/

# Avec port alternatif
scp -P 2222 ~/file.txt utilisateur@serveur:/tmp/

# Vérifier le transfert
ls -la ~/document.pdf
ssh utilisateur@serveur "ls -la /home/utilisateur/document.pdf"
```

### Transfert Récursif (Répertoires)

```bash
# Copier répertoire complet vers serveur
scp -r ~/projet utilisateur@serveur:/var/www/

# Copier depuis serveur
scp -r utilisateur@serveur:/var/www/projet ~/backup/

# Copier contenu uniquement (sans répertoire parent)
scp -r ~/projet/* utilisateur@serveur:/destination/

# Vérifier la structure
tree ~/projet
ssh utilisateur@serveur "tree /var/www/projet"
```

### Transferts Multiples

```bash
# Plusieurs fichiers
scp ~/file1.txt ~/file2.txt ~/file3.txt utilisateur@serveur:/data/

# Avec motifs glob
scp ~/logs/*.log utilisateur@serveur:/var/log/

# Depuis répertoire source
cd ~/source && scp ./* utilisateur@serveur:/destination/

# Boucle shell pour fichiers
for file in ~/data/*.csv; do
    scp "$file" utilisateur@serveur:/imports/
done
```

### Transferts avec Vérification

```bash
#!/bin/bash
# Script de transfert avec vérification d'intégrité

SOURCE="$1"
DEST_HOST="$2"
DEST_PATH="$3"

# Calcul empreinte locale
SHA_LOCAL=$(sha256sum "$SOURCE" | awk '{print $1}')
echo "[*] Empreinte locale : $SHA_LOCAL"

# Transfert
echo "[*] Transfert en cours..."
scp -p "$SOURCE" "$DEST_HOST:$DEST_PATH/"

# Calcul empreinte distante
echo "[*] Vérification distante..."
SHA_REMOTE=$(ssh "$DEST_HOST" "sha256sum $DEST_PATH/$(basename $SOURCE)" | awk '{print $1}')
echo "[*] Empreinte distante : $SHA_REMOTE"

# Comparaison
if [ "$SHA_LOCAL" = "$SHA_REMOTE" ]; then
    echo "[✓] Transfert vérifié"
else
    echo "[✗] Erreur d'intégrité détectée !"
    exit 1
fi
```

---

## 🔑 Authentification par Clé {#authentification}

### Génération de Clé Dédiée SCP

```bash
# 1. Créer clé ED25519 pour SCP uniquement
ssh-keygen -t ed25519 \
           -f ~/.ssh/id_scp \
           -C "scp-$(whoami)-$(date +%Y%m%d)" \
           -N ""

# 2. Sécuriser les fichiers
chmod 600 ~/.ssh/id_scp
chmod 644 ~/.ssh/id_scp.pub

# 3. Afficher l'empreinte
ssh-keygen -l -f ~/.ssh/id_scp
# Résultat : 256 SHA256:aBc123+... scp-user-20250116 (ED25519)

# 4. Sauvegarder l'empreinte
ssh-keygen -l -f ~/.ssh/id_scp > ~/.ssh/id_scp_fingerprint.txt
```

### Déploiement de Clé Publique

#### Méthode 1 : ssh-copy-id (Recommandée)

```bash
# Copier clé public via mot de passe temporaire
ssh-copy-id -i ~/.ssh/id_scp.pub utilisateur@serveur.exemple.com

# Résultat attendu :
# Number of key(s) added: 1
# Now try logging in with: "ssh -i ~/.ssh/id_scp utilisateur@serveur.exemple.com"
```

#### Méthode 2 : Manuelle (Sans Accès Mot de Passe)

```bash
# 1. Afficher la clé publique
cat ~/.ssh/id_scp.pub

# 2. Copier manuellement sur serveur
# (Email, Slack, Système de déploiement, etc.)

# 3. Sur serveur, ajouter à authorized_keys
echo "ssh-ed25519 AAAA... scp-user@host-20250116" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 4. Tester
scp -i ~/.ssh/id_scp ~/test.txt utilisateur@serveur:/tmp/
```

### Configuration SSH Client

```bash
# Ajouter à ~/.ssh/config
nano ~/.ssh/config

Host scp-prod
    HostName prod.exemple.com
    User scp-user
    IdentityFile ~/.ssh/id_scp
    IdentitiesOnly yes
    
    # Options optimisées SCP
    Compression yes
    BatchMode yes
    StrictHostKeyChecking accept-new
    
Host scp-backup
    HostName backup.interne
    User backup-user
    IdentityFile ~/.ssh/id_scp_backup
    IdentitiesOnly yes
```

Puis utiliser :
```bash
# Au lieu de la commande longue
scp -i ~/.ssh/id_scp -C ~/file.txt utilisateur@serveur:/tmp/

# Utiliser le profil
scp ~/file.txt scp-prod:/data/
scp scp-backup:/backups/file.tar.gz ~/
```

### SSH Agent pour Passphrase

```bash
# Démarrer l'agent (si pas actif)
eval "$(ssh-agent -s)"

# Charger la clé
ssh-add ~/.ssh/id_scp
# Demande de passphrase

# Vérifier la clé chargée
ssh-add -l

# Maintenant SCP utilisera l'agent
scp ~/file.txt utilisateur@serveur:/tmp/
# N'aura pas besoin de passphrase (agent fournit la clé)
```

---

## 🔧 Transferts Avancés {#avances}

### Transfert avec Compression

```bash
# Compression légère (recommandée pour connexion rapide)
scp -C ~/large-file.txt utilisateur@serveur:/tmp/

# Via SSH config
Host *
    Compression yes
    CompressionLevel 6   # 1-9, défaut 6

# Benchmark : avec vs sans compression
time scp ~/1gb.iso utilisateur@serveur:/tmp/
time scp -C ~/1gb.iso utilisateur@serveur:/tmp/
```

### Transfert avec Limite de Bande Passante

```bash
# Limiter à 1 MB/s (1024 KB/s)
scp -l 1024 ~/large.zip utilisateur@serveur:/backups/

# Limiter à 100 KB/s (pour environnement de production)
scp -l 100 ~/update.tar utilisateur@serveur:/opt/

# Via SSH tunneling
scp -l 512 -C -p ~/file utilisateur@serveur:/dst
```

### Transfert avec Vérification d'Intégrité

```bash
#!/bin/bash
# Transfert + vérification SHA256

verify_transfer() {
    local src="$1"
    local dst_host="$2"
    local dst_path="$3"
    
    # Empreinte source
    local src_sha=$(sha256sum "$src" | awk '{print $1}')
    
    # Transfert
    echo "[*] Transfert de $(basename $src)..."
    scp -p "$src" "$dst_host:$dst_path/" || {
        echo "[✗] Transfert échoué"
        return 1
    }
    
    # Empreinte destination
    local dst_file="$dst_path/$(basename $src)"
    local dst_sha=$(ssh "$dst_host" "sha256sum $dst_file" | awk '{print $1}')
    
    # Comparaison
    if [ "$src_sha" = "$dst_sha" ]; then
        echo "[✓] Empreintes identiques"
        return 0
    else
        echo "[✗] Empreintes différentes !"
        echo "   Source      : $src_sha"
        echo "   Destination : $dst_sha"
        return 1
    fi
}

verify_transfer ~/important.tar prod-server:/backups/
```

### Transfert Chiffré Avant SCP

```bash
#!/bin/bash
# Chiffrer fichier puis SCP (couche de sécurité supplémentaire)

PLAINTEXT="$1"
SSHFS_HOST="$2"
DEST_PATH="$3"

# 1. Chiffrer avec GPG
echo "[*] Chiffrement GPG..."
gpg --symmetric --cipher-algo AES256 "$PLAINTEXT"

# 2. Transfert chiffré
ENCRYPTED="${PLAINTEXT}.gpg"
echo "[*] Transfert via SCP..."
scp -C -p "$ENCRYPTED" "$SSHFS_HOST:$DEST_PATH/"

# 3. Vérification
echo "[*] Vérification..."
ssh "$SSHFS_HOST" "sha256sum $DEST_PATH/$ENCRYPTED"

# 4. Supprimer original chiffré localement
shred -u "$ENCRYPTED"
echo "[✓] Transfert chiffré complété"
```

### Transfert Récursif Intelligent

```bash
#!/bin/bash
# Transférer seulement fichiers modifiés

SYNC_SOURCE="$1"
SYNC_DEST_HOST="$2"
SYNC_DEST_PATH="$3"
TIMESTAMP_FILE="/tmp/scp_sync.timestamp"

# Fichiers modifiés depuis dernier sync
echo "[*] Recherche fichiers modifiés..."
find "$SYNC_SOURCE" -type f -newer "$TIMESTAMP_FILE" 2>/dev/null | while read file; do
    echo "[*] Transfert : $(basename $file)"
    scp -C -p "$file" "$SYNC_DEST_HOST:$SYNC_DEST_PATH/"
done

# Mettre à jour timestamp
touch "$TIMESTAMP_FILE"
echo "[✓] Sync complété"
```

---

## ⚡ Performance et Optimisation {#performance}

### Optimisation Paramètres SSH

```bash
# Options SCP optimisées pour performance
scp -C \
    -o BatchMode=yes \
    -o ConnectTimeout=30 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ~/file utilisateur@serveur:/tmp/

# Explications :
# -C                        → Compression
# BatchMode=yes             → Mode batch (pas de questions)
# ConnectTimeout=30         → Timeout 30 secondes
# StrictHostKeyChecking=no  → Pas de vérification host (⚠️ À utiliser avec prudence)
```

### SSH Config Optimisée

```
# ~/.ssh/config - Optimisé pour SCP

Host scp-servers
    HostName %h
    User scp-user
    IdentityFile ~/.ssh/id_scp
    IdentitiesOnly yes
    
    # Performance
    Compression yes
    CompressionLevel 6
    BatchMode yes
    
    # Sécurité
    StrictHostKeyChecking accept-new
    VerifyHostKeyDNS yes
    
    # Timeouts
    ConnectTimeout 30
    ServerAliveInterval 300
    ServerAliveCountMax 3
    
    # Optimization TCP
    TCPKeepAlive yes
    ForwardAgent no
```

### Benchmark Performance

```bash
#!/bin/bash
# Benchmark SCP vs alternatives

FILE_SIZE="1GB"
DEST_HOST="serveur.exemple.com"

echo "=== Benchmark Transfert $FILE_SIZE ==="

# 1. SCP non compressé
echo "[*] SCP (sans compression)"
time scp -C ~/test_$FILE_SIZE utilisateur@$DEST_HOST:/tmp/

# 2. SCP avec compression
echo "[*] SCP (avec compression)"
time scp -C ~/test_$FILE_SIZE utilisateur@$DEST_HOST:/tmp/

# 3. SFTP
echo "[*] SFTP"
time sftp utilisateur@$DEST_HOST << EOF
put ~/test_$FILE_SIZE /tmp/
quit
EOF

# 4. rsync via SSH
echo "[*] rsync"
time rsync -avz -e ssh ~/test_$FILE_SIZE utilisateur@$DEST_HOST:/tmp/
```

### Transferts Parallèles

```bash
#!/bin/bash
# Transférer plusieurs fichiers en parallèle

DEST_HOST="serveur.exemple.com"
DEST_PATH="/data/transfers"
MAX_PARALLEL=4

# Trouver fichiers
files=(~/data/*.tar.gz)

# Transférer en parallèle
for i in "${!files[@]}"; do
    # Limiter le nombre de processus
    while [ $(jobs -r -p | wc -l) -ge $MAX_PARALLEL ]; do
        sleep 1
    done
    
    # Lancer transfert en background
    echo "[*] Transfert : $(basename ${files[$i]})"
    scp -C -p "${files[$i]}" "$DEST_HOST:$DEST_PATH/" &
done

# Attendre tous les processus
wait
echo "[✓] Tous les transferts complétés"
```

---

## 🛡️ Sécurité et Audit {#securite}

### Logging des Transferts

```bash
# Créer un wrapper SCP avec logging

cat > ~/.local/bin/scp-logged << 'EOF'
#!/bin/bash
# Wrapper pour SCP avec logging

LOG_FILE="/tmp/scp_transfers.log"

# Logger l'appel
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Utilisateur: $(whoami) | Commande: $*" >> "$LOG_FILE"

# Exécuter SCP original
/usr/bin/scp "$@"

# Logger le résultat
RESULT=$?
if [ $RESULT -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCÈS" >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERREUR (code $RESULT)" >> "$LOG_FILE"
fi

exit $RESULT
EOF

chmod +x ~/.local/bin/scp-logged
export PATH="$HOME/.local/bin:$PATH"
```

### Audit SSH Serveur

```bash
#!/bin/bash
# Monitorer les transferts SCP sur serveur

echo "=== Transferts SCP (dernières 24h) ==="
sudo journalctl -u ssh --since "24 hours ago" | \
    grep -E "scp|Received|Sent" | \
    tail -20

echo ""
echo "=== Utilisateurs SCP actifs ==="
sudo who | grep scp

echo ""
echo "=== Tentatives échouées ==="
sudo journalctl -u ssh --since "24 hours ago" | \
    grep -i "failed\|refused" | \
    wc -l
```

### Restriction de Clé SCP (ANSSI)

```bash
# Sur serveur, restreindre clé pour SCP uniquement
# Dans authorized_keys :

command="internal-sftp -f AUTHPRIV -l INFO",no-pty,no-user-rc,restrict ssh-ed25519 AAAA... scp-user@client

# Explications options ANSSI :
# command="..."               → Force SFTP interne (utilisé par SCP)
# no-pty                      → Pas de pseudo-terminal
# no-user-rc                  → Ne pas charger profils shell
# restrict                    → Désactiver tunneling, agent forwarding, etc.
```

---

## 💾 Persistance et Automatisation {#persistance}

### Script de Sauvegarde SCP

```bash
#!/bin/bash
# Script de sauvegarde quotidienne via SCP

set -euo pipefail

# Configuration
BACKUP_SOURCE="/home/utilisateur/documents"
BACKUP_DEST_HOST="backup.exemple.com"
BACKUP_DEST_PATH="/backups/$(hostname)/$(date +%Y/%m)"
BACKUP_LOG="/var/log/scp_backup.log"

# Logging
exec > >(tee -a "$BACKUP_LOG")
exec 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "=== Démarrage sauvegarde SCP ==="
log "Source : $BACKUP_SOURCE"
log "Destination : $BACKUP_DEST_HOST:$BACKUP_DEST_PATH"

# 1. Créer répertoire destination
ssh "$BACKUP_DEST_HOST" "mkdir -p $BACKUP_DEST_PATH"

# 2. Archiver la source
BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).tar.gz"
log "Création archive : $BACKUP_FILE"
tar czf "/tmp/$BACKUP_FILE" -C "$(dirname $BACKUP_SOURCE)" "$(basename $BACKUP_SOURCE)"

# 3. Transférer via SCP
log "Transfert vers $BACKUP_DEST_HOST..."
scp -C -p "/tmp/$BACKUP_FILE" "$BACKUP_DEST_HOST:$BACKUP_DEST_PATH/"

# 4. Vérifier l'intégrité
LOCAL_SHA=$(sha256sum "/tmp/$BACKUP_FILE" | awk '{print $1}')
REMOTE_SHA=$(ssh "$BACKUP_DEST_HOST" "sha256sum $BACKUP_DEST_PATH/$BACKUP_FILE" | awk '{print $1}')

if [ "$LOCAL_SHA" = "$REMOTE_SHA" ]; then
    log "✓ Sauvegarde réussie et vérifiée"
else
    log "✗ Erreur d'intégrité"
    exit 1
fi

# 5. Nettoyer
rm -f "/tmp/$BACKUP_FILE"

log "=== Sauvegarde terminée ==="
```

### Planification avec Cron

```bash
# Ajouter à crontab
crontab -e

# Sauvegarde quotidienne à 2h du matin
0 2 * * * /usr/local/bin/scp-backup.sh

# Sauvegarde hebdomadaire (dimanche)
0 3 * * 0 /usr/local/bin/scp-backup-full.sh

# Sauvegarde horaire (fichiers critiques)
0 * * * * /usr/local/bin/scp-backup-hourly.sh

# Vérifier les tâches planifiées
crontab -l
```

### Automatisation Systemd

```bash
# /etc/systemd/system/scp-backup.service
[Unit]
Description=SCP Backup Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=backup
ExecStart=/usr/local/bin/scp-backup.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target

# /etc/systemd/system/scp-backup.timer
[Unit]
Description=SCP Backup Timer
Requires=scp-backup.service

[Timer]
OnBootSec=15min
OnUnitActiveSec=1d
Persistent=true

[Install]
WantedBy=timers.target

# Activer
sudo systemctl daemon-reload
sudo systemctl enable scp-backup.timer
sudo systemctl start scp-backup.timer
sudo systemctl status scp-backup.timer
```

---

## 🔍 Dépannage et Monitoring {#debogage}

### Commandes de Diagnostic

```bash
# 1. Vérifier la connectivité SSH
ssh -v utilisateur@serveur echo "OK"
# Chercher dans output : "Authentications" et "Accepted"

# 2. Tester SCP directement
scp -v ~/test.txt utilisateur@serveur:/tmp/
# Affiche chaque étape du transfert

# 3. Vérifier les permissions fichier
ls -la ~/test.txt

# 4. Vérifier les permissions destination
ssh utilisateur@serveur "ls -ld /tmp && touch /tmp/test_write"

# 5. Vérifier l'espace disque destination
ssh utilisateur@serveur "df -h"

# 6. Tester le transfert petit fichier
echo "test" > ~/tiny.txt
scp ~/tiny.txt utilisateur@serveur:/tmp/
ssh utilisateur@serveur "cat /tmp/tiny.txt"

# 7. Vérifier les processus SSH
ps aux | grep -E "[s]cp|[s]shd"

# 8. Vérifier les logs SSH
sudo journalctl -u ssh -n 20
```

### Dépannage Problèmes Courants

#### Problème 1 : "Permission denied (publickey)"

```bash
# Diagnostic
ssh -i ~/.ssh/id_scp -v utilisateur@serveur echo OK
# Chercher : "Authentications that can continue" et "Accepted publickey"

# Solutions
# 1. Vérifier clé existe
ls -la ~/.ssh/id_scp

# 2. Vérifier clé publique sur serveur
ssh utilisateur@serveur "cat ~/.ssh/authorized_keys | grep $(cat ~/.ssh/id_scp.pub | cut -d' ' -f2 | cut -c1-20)"

# 3. Vérifier permissions authorized_keys
ssh utilisateur@serveur "ls -la ~/.ssh/authorized_keys"
# Doit être : -rw------- (600)

# 4. Redéployer clé
ssh-copy-id -i ~/.ssh/id_scp.pub utilisateur@serveur
```

#### Problème 2 : "No space left on device"

```bash
# Diagnostic
ssh utilisateur@serveur "df -h"
ssh utilisateur@serveur "du -sh /destination"

# Solutions
# 1. Nettoyer destination
ssh utilisateur@serveur "rm -rf /destination/old_backups/*"

# 2. Compresser
scp -C ~/large.iso utilisateur@serveur:/tmp/

# 3. Transférer en parties
split -b 1G ~/file.iso ~/file_part_
for part in ~/file_part_*; do
    scp "$part" utilisateur@serveur:/tmp/
done
```

#### Problème 3 : Transfert très lent

```bash
# Diagnostic
time scp ~/1gb.file utilisateur@serveur:/tmp/
ping -c 10 serveur.exemple.com | grep "min/avg/max"

# Solutions
# 1. Activer compression
scp -C ~/file utilisateur@serveur:/tmp/

# 2. Augmenter buffer TCP
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"

# 3. Multiplier connexions (rsync)
rsync -avz -e ssh ~/file utilisateur@serveur:/tmp/

# 4. Utiliser compression SSH spécifique
echo "Compression yes\nCompressionLevel 9" >> ~/.ssh/config
```

---

## 📚 Références Officielles

### Documentation Officielle

**OpenSSH**
- https://man.openbsd.org/scp
- https://man.openbsd.org/ssh_config
- https://man.openbsd.org/sshd_config

**RFC SSH**
- RFC 4251 : SSH Protocol Architecture
- RFC 4252 : SSH Authentication Protocol
- RFC 4254 : SSH Connection Protocol

**ANSSI - Recommandations**
- https://cyber.gouv.fr/
- Guide d'hygiène informatique 2023

---

**Document généré le** : 16 novembre 2025
**Conformité** : ANSSI 2023 | OpenSSH 8.8+ | Debian 12+
**Révision** : 1.0
