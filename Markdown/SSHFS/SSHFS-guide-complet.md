# SSHFS - Montage de Systèmes de Fichiers Distants Sécurisés
## Guide Complet et Rigoureux

---

## 📋 Table des Matières

1. [Fondamentaux du Montage Réseau](#fondamentaux)
2. [Recommandations ANSSI](#anssi)
3. [Architecture et Fonctionnement](#architecture)
4. [Installation et Prérequis](#installation)
5. [Configuration de Base](#configuration)
6. [Authentification par Clé](#authentification)
7. [Montage Sécurisé](#montage-securise)
8. [Performance et Optimisation](#performance)
9. [Gestion Avancée](#avancee)
10. [Sécurité Réseau](#securite-reseau)
11. [Persistance et Automatisation](#persistance)
12. [Dépannage et Audit](#debogage)

---

## 🔐 Fondamentaux du Montage Réseau {#fondamentaux}

### Qu'est-ce que SSHFS ?

SSHFS (SSH FileSystem) est un système de fichiers en espace utilisateur qui permet de monter un répertoire distant sur un serveur SSH comme s'il était un répertoire local. Contrairement aux protocoles NFS ou SMB, SSHFS :

- **Chiffre tout le trafic** : Chaque octet est chiffré via SSH (TLS 1.3+)
- **Ne nécessite pas de port supplémentaire** : Utilise uniquement SSH (port 22)
- **Aucun serveur supplémentaire** : Fonctionne avec n'importe quel serveur SSH standard
- **Authentification cryptographique** : Utilise les clés SSH (ED25519 recommandé)
- **Transparence d'utilisation** : Intégration POSIX complète avec le système de fichiers
- **Portabilité** : Fonctionne sur Linux, macOS, BSD, Windows (WSL2)

### Cas d'Usage

```
Scenario 1 : Développeur qui travaille sur code source distant
  Local: ~/projet → montage SSHFS → Serveur distant:/home/dev/projet
  Outil habituel (VSCode, IDE) fonctionne naturellement
  
Scenario 2 : Administrateur qui gère des logs sur plusieurs serveurs
  Local: /mnt/serveur1/ → montage SSHFS → Serveur1:/var/log/
  Local: /mnt/serveur2/ → montage SSHFS → Serveur2:/var/log/
  Analyse centralisée et unifiée
  
Scenario 3 : Sauvegardes avec rsync sur montage SSHFS
  rsync -avz ~/données /mnt/serveur_backup/
  Utilise SSHFS pour transfert sécurisé sans accès root
```

### Comparaison avec Alternatives

| Protocole | Chiffrage | Serveur | Complexité | Sécurité |
|-----------|-----------|--------|-----------|----------|
| **SSHFS** | ✓ Natif | SSH std | Simple | Excellente |
| NFS | ✗ Optionnel | Dédié | Moyenne | Faible |
| SMB/CIFS | ✓ Natif | Dédié | Moyenne | Bonne |
| SFTP | ✓ Natif | SSH std | Simple | Excellente |
| WebDAV | ✓ Optionnel | HTTP | Moyenne | Moyenne |

**Avantage SSHFS** : Chiffrage natif + serveur SSH standard = moins d'attaque de surface

---

## 🛡️ Recommandations ANSSI {#anssi}

### Source Officielle ANSSI

**Document** : *Guide d'Hygiène Informatique* (édition 2023) et *Recommandations pour le Télétravail Sécurisé*

**Lien** : https://cyber.gouv.fr/ (rubrique publications)

### Recommandations Clés d'ANSSI pour SSHFS

#### 1️⃣ Authentification Obligatoire par Clé

```
✓ OBLIGATOIRE : Authentification par clé ED25519
✗ REFUSER : Authentification par mot de passe pour montage automatisé
✓ OBLIGATOIRE : Passphrase sur clé privée (≥20 caractères)

Raison ANSSI :
- Authentification par mot de passe = risque brute-force
- Clés ED25519 = résistance cryptographique prouvée
- Passphrase = protection contre compromission de poste local
```

**Implémentation** :
```bash
# Générer clé dédiée SSHFS (ne pas réutiliser clé SSH administrative)
ssh-keygen -t ed25519 -f ~/.ssh/id_sshfs -C "sshfs-user@$(date +%Y%m%d)"
chmod 600 ~/.ssh/id_sshfs

# ⚠️ Ajouter à passphrase=... dans config = RISQUE
# Toujours utiliser SSH Agent pour déverrouiller
```

#### 2️⃣ Isolation et Contrôle d'Accès

```
✓ OBLIGATOIRE : Compte utilisateur dédié pour SSHFS (non root)
✓ OBLIGATOIRE : Permissions de répertoire strictes
✓ OBLIGATOIRE : Documenter les volumes montés et leurs usages

Raison ANSSI :
- Un compte compromis ≠ accès root
- Limitation de superficie d'attaque
- Traçabilité des montages
```

**Implémentation** :
```bash
# Sur le serveur distant
sudo adduser sshfs-user --shell /usr/sbin/nologin

# Définir les permissions du répertoire à exporter
sudo chown sshfs-user:sshfs-user /data/export/
sudo chmod 755 /data/export/
sudo chmod 700 /home/sshfs-user/.ssh/

# Restreindre la clé SSH avec options (voir section authentification)
```

#### 3️⃣ Chiffrement du Trafic

```
✓ OBLIGATOIRE : SSH protocol 2 uniquement
✓ OBLIGATOIRE : Chiffrement strong (chacha20-poly1305, aes256-gcm)
✓ OBLIGATOIRE : Vérification d'intégrité (hmac-sha2-512-etm)

Configuration ANSSI minimale :
  KexAlgorithms curve25519-sha256
  Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
  MACs hmac-sha2-512-etm@openssh.com
```

#### 4️⃣ Monitoring et Logging

```
✓ OBLIGATOIRE : Logger tous les montages SSHFS
✓ OBLIGATOIRE : Logs de qui/quand/depuis/vers quoi
✓ Fréquence : Temps réel ou horaire minimum
✓ Rétention : 90 jours minimum
```

#### 5️⃣ Timeout et Limitation

```
✓ OBLIGATOIRE : Timeout inactivité pour montages distants
✓ OBLIGATOIRE : Limiter les tentatives de reconnexion
✓ Recommandé : Démonter les montages inutilisés

Raison :
- Libérer connexions SSH qui traînent
- Prévenir les attaques DOS sur montage détruit
- Détacher proprement en cas de perte réseau
```

#### 6️⃣ Isolation Réseau

```
✓ OBLIGATOIRE : Montages uniquement depuis réseau interne
✓ OBLIGATOIRE : Interdire les tunnels SSHFS depuis DMZ
✓ Refuser : Accès SSHFS via VPN sans authentification forte

Raison ANSSI :
- SSHFS = accès direct aux fichiers (pas d'API d'interception)
- DMZ doit être isolée des données sensibles
- VPN doit avoir MFA pour accès fichiers
```

---

## 🏗️ Architecture et Fonctionnement {#architecture}

### Flux de Données SSHFS

```
┌─────────────────────────────────────────────────────────┐
│                    CLIENT LOCAL                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Application locale (IDE, VSCode, rsync, etc.)         │
│          ↓ (appels système : open, read, write)         │
│                                                          │
│  Noyau Linux (Virtual File System - VFS)               │
│          ↓ (routing POSIX → montage)                    │
│                                                          │
│  FUSE (Filesystem in User Space)                       │
│          ↓ (envoi IPC vers daemon sshfs)               │
│                                                          │
│  Daemon SSHFS (processus utilisateur)                  │
│          ↓ (conversion en protocole SFTP)               │
│                                                          │
│  SSH Client (OpenSSH)                                  │
│          ↓ (chiffrement TLS 1.3+)                       │
└─────────────────────────────────────────────────────────┘
                        ↓ Réseau TCP port 22
┌─────────────────────────────────────────────────────────┐
│                   SERVEUR DISTANT                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  SSH Server (OpenSSH sshd)                             │
│          ↓ (déchiffrement, authentification)            │
│                                                          │
│  SFTP Subsystem (intégré dans sshd)                    │
│          ↓ (conversion SFTP → appels système)           │
│                                                          │
│  Noyau Linux (VFS réel)                                │
│          ↓                                               │
│                                                          │
│  Système de fichiers réel (ext4, btrfs, etc.)          │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Protocole SFTP (SSH File Transfer Protocol)

**SFTP** est un sous-système de SSH qui offre :
- Transfert de fichiers sécurisé
- Lister des répertoires
- Créer/supprimer des fichiers et répertoires
- Obtenir/fixer les attributs (permissions, timestamps)
- **Non à confondre** : FTP non chiffré ≠ SFTP

**Implémentation** :
```bash
# SFTP est souvent actif par défaut dans OpenSSH
# Vérifier sur le serveur :
grep -i "subsystem.*sftp" /etc/ssh/sshd_config
# Résultat attendu : Subsystem sftp /usr/lib/openssh/sftp-server

# Tester SFTP (alternative : sftp utilisateur@serveur)
sftp utilisateur@serveur.exemple.com
> ls
> cd /data/
> get fichier.txt
> quit
```

### Couches de Sécurité SSHFS

```
Niveau 1 : Authentification SSH
  └─ Clé ED25519 + passphrase

Niveau 2 : Chiffrement du canal
  └─ ChaCha20-Poly1305 ou AES256-GCM

Niveau 3 : Protocole SFTP
  └─ Vérification d'intégrité de chaque paquet

Niveau 4 : Permissions du système de fichiers
  └─ Respect POSIX uid/gid/mode de destination

Niveau 5 : Isolation au montage
  └─ Mountpoint local avec droits restreints
```

---

## 📦 Installation et Prérequis {#installation}

### Vérification Prérequis

#### Sur le Client

```bash
# 1. Vérifier FUSE disponible
ls -la /dev/fuse
# Résultat attendu : crw-rw---- 1 root fuse

# 2. Vérifier le groupe fuse
getent group fuse

# 3. Vérifier OpenSSH Client
which ssh
ssh -V

# 4. Vérifier les modules noyau
modprobe -n fuse
# (Pas de message d'erreur = disponible)
```

#### Sur le Serveur

```bash
# 1. Vérifier OpenSSH Server
which sshd
sshd -V

# 2. Vérifier SFTP Subsystem
grep -i "subsystem.*sftp" /etc/ssh/sshd_config
# Résultat : Subsystem sftp /usr/lib/openssh/sftp-server

# 3. Vérifier l'utilisateur peut exécuter /usr/lib/openssh/sftp-server
ls -la /usr/lib/openssh/sftp-server
# Résultat : -rwxr-xr-x (lecture execute pour tout)

# 4. Vérifier structure /etc/ssh/sshd_config.d/
ls -la /etc/ssh/sshd_config.d/
```

### Installation sur Debian/Ubuntu

#### Client (Poste Local)

```bash
# 1. Installer SSHFS et dépendances
sudo apt update
sudo apt install -y sshfs

# 2. Installer OpenSSH Client (généralement présent)
sudo apt install -y openssh-client

# 3. Installer les outils optionnels
sudo apt install -y \
    openssh-sftp-server \
    openssh-server \
    ssh-utils

# 4. Vérifier l'installation
which sshfs
sshfs --version

# 5. Ajouter l'utilisateur au groupe fuse
sudo usermod -aG fuse $USER
# Log out et log back in pour que le changement prenne effet

# 6. Vérifier l'appartenance au groupe
id | grep fuse
# Résultat : gid=X(fuse) (si présent)
```

#### Serveur (Distant)

```bash
# 1. OpenSSH Server devrait déjà être installé
sudo systemctl status ssh
sudo systemctl status sshd

# 2. Vérifier SFTP subsystem
grep -i subsystem /etc/ssh/sshd_config
# Si absent, ajouter :
echo "Subsystem sftp /usr/lib/openssh/sftp-server" | sudo tee -a /etc/ssh/sshd_config

# 3. Redémarrer SSH
sudo systemctl restart ssh

# 4. Vérifier que SFTP fonctionne
sftp utilisateur@localhost
> quit
```

### Configuration du Groupe FUSE

```bash
# ⚠️ Important pour monter sans sudo

# 1. Vérifier le groupe fuse existe
sudo getent group fuse

# Si n'existe pas, le créer (rare sur Debian récent)
sudo groupadd fuse

# 2. Ajouter l'utilisateur au groupe
sudo usermod -aG fuse $USER

# 3. Vérifier les droits /etc/fuse.conf
sudo cat /etc/fuse.conf

# Si user_allow_other commenté, le décommenter
sudo sed -i 's/^# user_allow_other/user_allow_other/' /etc/fuse.conf

# 4. Recharger les groupes (ou se déconnecter/reconnecter)
newgrp fuse

# 5. Test sans sudo
mkdir -p ~/mnt/test
sshfs utilisateur@serveur:/tmp ~/mnt/test
ls ~/mnt/test
umount ~/mnt/test
```

---

## ⚙️ Configuration de Base {#configuration}

### Configuration SSH Client (~/.ssh/config)

**Pourquoi** : Centraliser la configuration SSHFS pour chaque serveur

```
# ~/.ssh/config

# Profil SSHFS général
Host *
    # Authentification par clé
    PubkeyAuthentication yes
    PasswordAuthentication no
    
    # Algorithmes sécurisés
    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
    MACs hmac-sha2-512-etm@openssh.com
    
    # Timeouts
    ServerAliveInterval 300
    ServerAliveCountMax 2
    
    # Compression (optionnel mais recommandé pour SSHFS)
    Compression yes
    CompressionLevel 6

# Profil spécifique : Serveur de données
Host data-prod
    HostName data.prod.exemple.com
    User sshfs-user
    IdentityFile ~/.ssh/id_sshfs
    IdentitiesOnly yes
    Port 22
    
    # Options spécifiques SSHFS
    ForwardAgent no
    ForwardX11 no
    AllowLocalCommand no

# Profil spécifique : Serveur de développement
Host dev-lab
    HostName 192.168.1.50
    User dev-user
    IdentityFile ~/.ssh/id_sshfs_dev
    IdentitiesOnly yes
    Port 2222
    
    # Options strictes
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/known_hosts_dev
```

### Répertoire de Montage Local

**Hiérarchie recommandée** :

```bash
# Structure de montage SSHFS
~/mnt/
├── prod/
│   ├── data-prod/
│   ├── logs-prod/
│   └── backup-prod/
├── dev/
│   ├── dev-lab/
│   └── dev-test/
└── temp/
    └── workspace/

# Créer la structure
mkdir -p ~/mnt/{prod,dev,temp}/{data-prod,logs-prod,dev-lab,workspace}

# Définir les permissions
chmod 700 ~/mnt/
chmod 700 ~/mnt/prod/
chmod 700 ~/mnt/dev/
chmod 700 ~/mnt/temp/
```

### Script de Montage Automatisé

```bash
#!/bin/bash
# Script : ~/bin/sshfs-mount.sh

set -e

# Configuration
SSHFS_HOST="${1:?Usage: $0 <host> [remote_path] [local_path]}"
REMOTE_PATH="${2:-/home}"
LOCAL_PATH="${3:-~/mnt/$(echo $SSHFS_HOST | cut -d@ -f2)}"

# Créer le répertoire s'il n'existe pas
mkdir -p "$LOCAL_PATH"

# Vérifier que le répertoire est vide
if [ "$(ls -A $LOCAL_PATH)" ]; then
    echo "[!] Erreur : $LOCAL_PATH n'est pas vide"
    exit 1
fi

# Options SSHFS recommandées
SSHFS_OPTS=(
    "-C"                              # Compression
    "-o reconnect"                    # Reconnecter si déconnecté
    "-o ServerAliveInterval=300"      # Keep-alive
    "-o allow_other"                  # Accessible à d'autres users
    "-o uid=$(id -u)"                # UID de montage
    "-o gid=$(id -g)"                # GID de montage
)

echo "[*] Montage de $SSHFS_HOST:$REMOTE_PATH vers $LOCAL_PATH"

sshfs "${SSHFS_OPTS[@]}" \
    "$SSHFS_HOST:$REMOTE_PATH" \
    "$LOCAL_PATH"

if [ $? -eq 0 ]; then
    echo "[✓] Montage réussi"
    mount | grep sshfs
else
    echo "[✗] Erreur lors du montage"
    rmdir "$LOCAL_PATH" 2>/dev/null || true
    exit 1
fi
```

---

## 🔑 Authentification par Clé {#authentification}

### Génération de Clé Dédiée SSHFS

```bash
# 1. Créer une clé ED25519 pour SSHFS uniquement
# (Ne pas réutiliser la clé SSH administrative)

ssh-keygen -t ed25519 \
           -f ~/.ssh/id_sshfs \
           -C "sshfs-$(whoami)-$(hostname)-$(date +%Y%m%d)" \
           -N ""

# 2. Sécuriser la clé privée
chmod 600 ~/.ssh/id_sshfs
chmod 644 ~/.ssh/id_sshfs.pub

# 3. Afficher l'empreinte pour documentation
ssh-keygen -l -f ~/.ssh/id_sshfs
# Résultat : 256 SHA256:aBc123+... sshfs-user-host-20250116 (ED25519)

# 4. Sauvegarder l'empreinte
ssh-keygen -l -f ~/.ssh/id_sshfs > ~/.ssh/id_sshfs_fingerprint.txt
```

### Configuration Avancée de Clé SSH (Restriction ANSSI)

**Concept** : Restreindre une clé publique pour SSHFS uniquement (pas SSH interactif)

#### Option 1 : Restreindre à Commande SFTP Uniquement

```bash
# Sur le serveur distant, modifier authorized_keys :
sudo nano ~/.ssh/authorized_keys

# Ajouter les restrictions avant la clé :
# Format : option1,option2 ssh-ed25519 AAAA...

command="/usr/lib/openssh/sftp-server",no-pty,no-user-rc,restrict ssh-ed25519 AAAA... sshfs-user@host-20250116

# Explications des options :
# command="..."           → Force l'exécution d'une commande
# no-pty                  → Pas de pseudo-terminal (SSH interactif impossible)
# no-user-rc              → Ne pas charger .bashrc/.profile
# restrict                → Désactiver tunneling, agent forwarding, etc.
```

#### Option 2 : Restreindre par Adresse IP Source

```bash
# Restreindre la clé à certaines IPs uniquement
# Sur le serveur :

from="192.168.1.0/24,203.0.113.0/24" ssh-ed25519 AAAA... sshfs-user@host-20250116

# Raison ANSSI :
# - Même clé compromise ne fonctionne que depuis IPs autorisées
# - Limite la latéralité en cas de compromission
```

#### Option 3 : Restreindre à Répertoire Spécifique

```bash
# Si chroot disponible sur serveur :
# Dans /etc/ssh/sshd_config, ajouter :

Match User sshfs-user
    ChrootDirectory /var/sshfs/%u
    ForceCommand /usr/lib/openssh/sftp-server
    AllowTcpForwarding no
    AllowAgentForwarding no
    PermitTTY no

# Puis créer la structure chroot :
sudo mkdir -p /var/sshfs/sshfs-user
sudo chown root:root /var/sshfs/sshfs-user
sudo chmod 755 /var/sshfs/sshfs-user

# Créer les liens vers les répertoires autorisés
sudo mkdir -p /var/sshfs/sshfs-user/data
sudo mount --bind /data/export /var/sshfs/sshfs-user/data

# Redémarrer SSH
sudo systemctl restart ssh
```

### Déploiement de Clé Publique

#### Méthode 1 : Copie Sécurisée

```bash
# Client :
# 1. Afficher la clé publique
cat ~/.ssh/id_sshfs.pub

# 2. Copier (manuel : email chiffré, physique, etc.)

# Serveur :
# 3. Ajouter au authorized_keys
echo "ssh-ed25519 AAAA... sshfs-user@host-20250116" >> ~/.ssh/authorized_keys

# 4. Vérifier les permissions
chmod 600 ~/.ssh/authorized_keys

# 5. Tester
ssh -i ~/.ssh/id_sshfs sshfs-user@localhost
```

#### Méthode 2 : ssh-copy-id (Si Accès Mot de Passe Temporaire)

```bash
# Client :
ssh-copy-id -i ~/.ssh/id_sshfs.pub sshfs-user@serveur.exemple.com

# Résultat attendu :
# Number of key(s) added: 1
```

### Gestion SSH Agent pour SSHFS

```bash
# Déverrouiller la clé pour la session
ssh-add ~/.ssh/id_sshfs
# Demande de passphrase

# Vérifier que la clé est chargée
ssh-add -l

# Signature de montage SSHFS (clé sera fournie par agent)
sshfs utilisateur@serveur:/data ~/mnt/data

# Déverrouiller automatiquement au démarrage
# Ajouter à ~/.bashrc :

if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    ssh-add ~/.ssh/id_sshfs 2>/dev/null
fi
```

---

## 🔒 Montage Sécurisé {#montage-securise}

### Options SSHFS Sécurisées ANSSI

```bash
# Montage basic sécurisé
sshfs -C \
      -o reconnect \
      -o ServerAliveInterval=300 \
      -o idmap=user \
      -o cache=yes \
      -o cache_timeout=600 \
      utilisateur@serveur:/data ~/mnt/data

# Explication des options :
# -C                    → Compression SSH
# reconnect             → Reconnecter automatiquement
# ServerAliveInterval   → Keep-alive toutes les 5 min
# idmap=user            → Mapper les UID/GID
# cache=yes             → Cache local (améliore perf)
# cache_timeout         → Durée du cache (10 min)
```

### Script de Montage Sécurisé Complet

```bash
#!/bin/bash
# Script : ~/bin/sshfs-mount-secure.sh

set -euo pipefail

# Configuration ANSSI
SSHFS_USER="${1:?Usage: $0 <user@host> [remote_path]}"
REMOTE_PATH="${2:-/home}"
LOCAL_PATH="~/mnt/$(echo $SSHFS_USER | cut -d@ -f2)"
SSH_CONFIG_PROFILE="${SSHFS_USER%%@*}"

# Logging
LOG_FILE="/tmp/sshfs-mount.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*"
}

log_info "=== Montage SSHFS Sécurisé ==="
log_info "Utilisateur : $SSHFS_USER"
log_info "Chemin distant : $REMOTE_PATH"
log_info "Point de montage : $LOCAL_PATH"

# Étape 1 : Vérifier la connectivité SSH
log_info "Vérification de la connectivité SSH..."
if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
         "$SSHFS_USER" exit 2>/dev/null; then
    log_error "Impossible de se connecter via SSH"
    exit 1
fi
log_info "✓ Connectivité SSH OK"

# Étape 2 : Créer le répertoire de montage
log_info "Préparation du répertoire de montage..."
mkdir -p "$LOCAL_PATH" 2>/dev/null || true

if [ ! -d "$LOCAL_PATH" ]; then
    log_error "Impossible de créer $LOCAL_PATH"
    exit 1
fi

if [ "$(ls -A $LOCAL_PATH 2>/dev/null)" ]; then
    log_error "Le répertoire $LOCAL_PATH n'est pas vide"
    exit 1
fi
log_info "✓ Répertoire prêt"

# Étape 3 : Monter SSHFS avec options ANSSI
log_info "Montage SSHFS..."

SSHFS_OPTS=(
    "-C"                              # Compression
    "-o reconnect"                    # Reconnexion automatique
    "-o ServerAliveInterval=300"      # Keep-alive 5 min
    "-o ServerAliveCountMax=3"        # 3 tentatives
    "-o ConnectTimeout=30"            # Timeout 30 sec
    "-o idmap=user"                   # Mappage UID/GID
    "-o cache=yes"                    # Cache
    "-o cache_timeout=600"            # Cache timeout 10 min
    "-o allow_other"                  # Accessible aux autres users
    "-o default_permissions"          # Respect POSIX permissions
    "-o IdentityFile ~/.ssh/id_sshfs" # Clé dédiée
)

if ! sshfs "${SSHFS_OPTS[@]}" \
    "$SSHFS_USER:$REMOTE_PATH" \
    "$LOCAL_PATH"; then
    log_error "Montage échoué"
    exit 1
fi

log_info "✓ Montage réussi"

# Étape 4 : Vérifier l'accessibilité
log_info "Vérification post-montage..."
if ! touch "$LOCAL_PATH"/.sshfs-test 2>/dev/null; then
    log_error "Impossible d'accéder au montage"
    fusermount -u "$LOCAL_PATH"
    exit 1
fi
rm -f "$LOCAL_PATH"/.sshfs-test

log_info "✓ Vérification OK"
log_info "Montage complété avec succès"
log_info "Point de montage : $LOCAL_PATH"
log_info "Pour démonter : fusermount -u $LOCAL_PATH"
```

### Montage avec Limites de Ressources

```bash
# Limiter l'utilisation réseau (throttling)
sshfs -o bandwidth=10240 \  # 10 MB/s max
      utilisateur@serveur:/data ~/mnt/data

# Limiter les connexions simultanées
sshfs -o max_conns=5 \
      utilisateur@serveur:/data ~/mnt/data

# Combiner avec autres options
sshfs -C \
      -o reconnect \
      -o ServerAliveInterval=300 \
      -o bandwidth=10240 \
      -o max_conns=5 \
      utilisateur@serveur:/data ~/mnt/data
```

---

## ⚡ Performance et Optimisation {#performance}

### Tuning des Paramètres SSHFS

```bash
# Paramètres pour performance maximale
sshfs -C \
      -o reconnect \
      -o ServerAliveInterval=300 \
      -o ServerAliveCountMax=3 \
      -o ConnectTimeout=30 \
      -o idmap=user \
      -o cache=yes \
      -o cache_timeout=600 \
      -o follow_symlinks \
      -o transform_symlinks \
      -o allow_other \
      -o direct_io \
      utilisateur@serveur:/data ~/mnt/data
```

### Comparaison Direct I/O vs Buffered

```bash
# Direct I/O : Pas de cache (para synchrone, lent)
sshfs -C -o direct_io utilisateur@serveur:/data ~/mnt/data

# Buffered I/O : Cache kernel (rapide, risque de perte)
sshfs -C -o cache=yes utilisateur@serveur:/data ~/mnt/data

# Recommandé :
# - Cache=yes pour raading/écriture normale
# - Direct_io pour streaming ou fichiers énormes
```

### Benchmark SSHFS vs Alternative

```bash
#!/bin/bash
# Script de benchmark

echo "=== Benchmark SSHFS ==="

# 1. Montage
sshfs -C utilisateur@serveur:/data ~/mnt/data

# 2. Test de lecture
echo "Lecture 1 GB :"
time dd if=~/mnt/data/test_1gb.bin of=/dev/null bs=1M

# 3. Test d'écriture
echo "Écriture 1 GB :"
time dd if=/dev/zero of=~/mnt/data/test_write.bin bs=1M count=1000

# 4. Compression
echo "Comparaison avec SSH direct :"
time scp utilisateur@serveur:/data/test_1gb.bin ~/test_scp.bin

# 5. Nettoyer
rm -f ~/mnt/data/test_write.bin ~/test_scp.bin
fusermount -u ~/mnt/data
```

### Optimisation Réseau et SSH

```bash
# Paramètres SSH pour SSHFS
export SSH_AUTH_SOCK="$HOME/.ssh/ssh_agent.sock"
export SSHFS_SSH_CMD="ssh -C -o StrictHostKeyChecking=no -o Compression=yes"

# Ou dans ~/.ssh/config
Host sshfs-servers
    Compression yes
    CompressionLevel 6
    TCPKeepAlive yes
    ServerAliveInterval 300
    ServerAliveCountMax 3

# Limiter congestion TCP
sshfs -C \
      -o TCPKeepAlive=yes \
      -o ForkProcess=no \
      utilisateur@serveur:/data ~/mnt/data
```

---

## 🔧 Gestion Avancée {#avancee}

### Montage Multiples Serveurs

```bash
#!/bin/bash
# Script de montage multiple sécurisé

declare -A SERVERS=(
    ["prod-data"]="sshfs-user@prod.exemple.com:/data"
    ["prod-logs"]="sshfs-user@prod.exemple.com:/var/log"
    ["dev-lab"]="dev@lab.interne:/home/dev"
)

MOUNT_BASE="$HOME/mnt"
mkdir -p "$MOUNT_BASE"

for alias in "${!SERVERS[@]}"; do
    mount_point="$MOUNT_BASE/$alias"
    sshfs_path="${SERVERS[$alias]}"
    
    echo "[*] Montage : $alias -> $sshfs_path"
    
    mkdir -p "$mount_point"
    sshfs -C \
          -o reconnect \
          -o ServerAliveInterval=300 \
          -o idmap=user \
          -o cache=yes \
          "$sshfs_path" "$mount_point"
    
    if [ $? -eq 0 ]; then
        echo "[✓] OK"
    else
        echo "[✗] Erreur"
    fi
done

# Lister les montages
mount | grep sshfs
```

### Démontage Sécurisé

```bash
#!/bin/bash
# Script de démontage avec synchronisation

MOUNT_POINT="$1"

if [ ! -d "$MOUNT_POINT" ]; then
    echo "Erreur : $MOUNT_POINT n'existe pas"
    exit 1
fi

echo "[*] Synchronisation des fichiers..."
sync

echo "[*] Vérification des processus utilisant le montage..."
lsof "$MOUNT_POINT" 2>/dev/null | grep -v COMMAND || echo "[*] Aucun processus"

echo "[*] Démontage..."
fusermount -u "$MOUNT_POINT"

if [ $? -eq 0 ]; then
    echo "[✓] Démontage réussi"
    rmdir "$MOUNT_POINT" 2>/dev/null || true
else
    echo "[✗] Erreur lors du démontage (forcer)"
    fusermount -uz "$MOUNT_POINT"
fi
```

### Montage avec Reconnexion Automatique

```bash
#!/bin/bash
# Script de monitoring avec reconnexion

SSHFS_USER="utilisateur@serveur"
REMOTE_PATH="/data"
MOUNT_POINT="$HOME/mnt/data"
PID_FILE="/tmp/sshfs_monitor_$SSHFS_USER.pid"

check_and_mount() {
    if [ ! -d "$MOUNT_POINT" ] || ! mountpoint -q "$MOUNT_POINT"; then
        echo "[$(date)] Remontage..."
        mkdir -p "$MOUNT_POINT"
        
        sshfs -C \
              -o reconnect \
              -o ServerAliveInterval=300 \
              "$SSHFS_USER:$REMOTE_PATH" \
              "$MOUNT_POINT"
    fi
}

# Boucle de monitoring
while true; do
    check_and_mount
    sleep 30  # Vérifier toutes les 30 secondes
done &

echo $! > "$PID_FILE"
echo "Monitoring démarré (PID : $(cat $PID_FILE))"
```

---

## 🛡️ Sécurité Réseau {#securite-reseau}

### Isolation SSHFS via Pare-feu

```bash
# NFTABLES : Autoriser SSHFS seulement depuis IPs de confiance

sudo nano /etc/nftables.conf

# Ajouter :
table inet filter {
    set trusted_sshfs_clients {
        type ipv4_addr
        flags interval
        elements = {
            192.168.1.0/24,      # Réseau interne
            203.0.113.1          # VPN gateway
        }
    }
    
    chain INPUT {
        # SSHFS (SSH sur port 22) depuis IPs de confiance
        tcp dport 22 ip saddr @trusted_sshfs_clients accept
        
        # SSH depuis autre part = refuser
        tcp dport 22 drop
    }
}
```

### VPN + SSHFS pour Accès Distant

```bash
# Scénario : Télétravail sécurisé

# 1. Se connecter au VPN
sudo wg-quick up vpn-client

# 2. Attendre que la connexion soit établie
sleep 2

# 3. Monter SSHFS uniquement après VPN
sshfs -C \
      -o reconnect \
      -o ServerAliveInterval=300 \
      utilisateur@serveur-interne:/data \
      ~/mnt/data

# Script complet
#!/bin/bash
vpn_up() {
    sudo wg-quick up vpn-client
    sleep 3
    ping -c 1 serveur-interne > /dev/null 2>&1
}

sshfs_up() {
    sshfs -C -o reconnect utilisateur@serveur-interne:/data ~/mnt/data
}

if vpn_up; then
    sshfs_up
else
    echo "VPN non disponible"
    exit 1
fi
```

### Monitoring des Connexions SSHFS

```bash
#!/bin/bash
# Monitor les connexions SSH/SSHFS actives

echo "=== Processus SSHFS actifs ==="
ps aux | grep -E "[s]shfs|sftp-server"

echo ""
echo "=== Montages SSHFS actifs ==="
mount | grep sshfs

echo ""
echo "=== Connexions SSH vers serveurs SSHFS ==="
netstat -tlnp 2>/dev/null | grep ":22" || ss -tlnp 2>/dev/null | grep ":22"

echo ""
echo "=== Tentatives échouées (logs) ==="
sudo journalctl -u ssh --since "1 hour ago" | grep -i "failed\|refused" | tail -5
```

---

## 💾 Persistance et Automatisation {#persistance}

### Fichier /etc/fstab pour Montage au Démarrage

```bash
# ⚠️ Attention : requires ssh-keygen sans passphrase OU ssh-agent

# Créer clé sans passphrase pour utilisateur root (non recommandé)
# OU

# Méthode sécurisée : Script de montage appelé au démarrage

# 1. Créer script
sudo nano /usr/local/bin/mount-sshfs.sh

#!/bin/bash
# Script de montage sécurisé au démarrage

USER_TO_MOUNT="utilisateur-normal"
HOME_DIR="/home/$USER_TO_MOUNT"
MOUNT_POINT="$HOME_DIR/mnt/data"

# Attendre que le réseau soit prêt
sleep 10

# Monter le système de fichiers
sudo -u "$USER_TO_MOUNT" sshfs \
    -C \
    -o reconnect \
    -o ServerAliveInterval=300 \
    -o idmap=user \
    utilisateur@serveur:/data \
    "$MOUNT_POINT"

# 2. Rendre exécutable
sudo chmod +x /usr/local/bin/mount-sshfs.sh

# 3. Créer service systemd
sudo nano /etc/systemd/system/mount-sshfs.service

[Unit]
Description=Mount SSHFS after network is ready
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mount-sshfs.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target

# 4. Activer et démarrer
sudo systemctl daemon-reload
sudo systemctl enable mount-sshfs.service
sudo systemctl start mount-sshfs.service
```

### Automatisation via Cron

```bash
# Script de vérification/remontage périodique
cat > ~/bin/ensure-sshfs-mounted.sh << 'EOF'
#!/bin/bash

MOUNT_POINT="$HOME/mnt/data"
SSHFS_SERVER="utilisateur@serveur:/data"

# Si pas monté, monter
if ! mountpoint -q "$MOUNT_POINT"; then
    mkdir -p "$MOUNT_POINT"
    sshfs -C -o reconnect -o ServerAliveInterval=300 "$SSHFS_SERVER" "$MOUNT_POINT"
    echo "[$(date)] SSHFS remonté" >> ~/.sshfs.log
fi
EOF

chmod +x ~/bin/ensure-sshfs-mounted.sh

# Ajouter à crontab
crontab -e

# Toutes les 5 minutes
*/5 * * * * $HOME/bin/ensure-sshfs-mounted.sh

# Toutes les heures
0 * * * * $HOME/bin/ensure-sshfs-mounted.sh
```

### Migration de Données sur SSHFS

```bash
#!/bin/bash
# Migration sécurisée de données via SSHFS

SOURCE="$1"
DEST_MOUNT="$2"
LOG_FILE="/tmp/sshfs-migration.log"

exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "[$(date)] === Migration SSHFS démarrée ==="
echo "Source : $SOURCE"
echo "Destination : $DEST_MOUNT"

# Vérifications
[ -d "$SOURCE" ] || { echo "Source n'existe pas"; exit 1; }
[ -d "$DEST_MOUNT" ] || { echo "Destination n'existe pas"; exit 1; }

# Sync avec rsync
echo "[*] Synchronisation..."
rsync -avz --progress \
      --delete \
      --partial \
      "$SOURCE/" \
      "$DEST_MOUNT/" \
      2>&1 | tail -20

echo "[✓] Migration terminée"
echo "[*] Taille totale transférée :"
du -sh "$DEST_MOUNT"

echo "[$(date)] === Migration complétée ==="
```

---

## 🔍 Dépannage et Audit {#debogage}

### Commandes de Diagnostic

```bash
# 1. Vérifier les montages actifs
mount | grep sshfs
# ou
df -h | grep sshfs

# 2. Lister les handles de montage
mount | grep sshfs | awk '{print $3}'

# 3. Vérifier les processus SSHFS
ps aux | grep -E "[s]shfs"

# 4. Lister les connexions SSH
netstat -tlnp | grep ":22" || ss -tlnp | grep ":22"

# 5. Fichiers ouverts sur montage
lsof /home/utilisateur/mnt/

# 6. Inodes utilisés
df -i /home/utilisateur/mnt/

# 7. Test de latence vers serveur
ping -c 5 serveur.exemple.com

# 8. Vérifier la bande passante SSH
iperf3 -c serveur-iperf.exemple.com -P 4
```

### Debugging SSHFS en Détail

```bash
# Montage avec verbose

sshfs -d -o debug,sshfs_debug \
      -C \
      -o reconnect \
      utilisateur@serveur:/data \
      ~/mnt/data \
      2>&1 | tee ~/sshfs_debug.log

# Options de debug :
# -d                 → FUSE debug
# -o debug           → SSHFS debug
# -o sshfs_debug     → Très verbeux

# Afficher les logs du kernel
dmesg | tail -50
journalctl -f | grep fuse
```

### Résolution des Problèmes Courants

```bash
# Problème 1 : "permission denied (publickey)"
ssh -i ~/.ssh/id_sshfs utilisateur@serveur
# Vérifier authorized_keys sur serveur

# Problème 2 : "Transport endpoint is not connected"
# Reconnexion automatique activée ?
sshfs -C -o reconnect ...

# Problème 3 : "No such file or directory" au montage
# Vérifier le répertoire distant existe
ssh utilisateur@serveur ls -la /data

# Problème 4 : "Read-only file system"
# Vérifier les permissions
ssh utilisateur@serveur ls -ld /data

# Problème 5 : Démontage impossible ("Device or resource busy")
lsof /home/utilisateur/mnt/
# Fermer les processus utilisant le montage
fusermount -uz /home/utilisateur/mnt/
```

---

## 📚 Références Officielles

### Documentation Officielle

**SSHFS - GitHub**
- https://github.com/libfuse/sshfs
- https://github.com/libfuse/libfuse

**OpenSSH Documentation**
- https://man.openbsd.org/ssh
- https://man.openbsd.org/sshd_config
- https://man.openbsd.org/sftp-server

**FUSE Documentation**
- https://github.com/libfuse/libfuse/wiki
- https://github.com/libfuse/libfuse/blob/master/README.md

**ANSSI - Recommandations**
- https://cyber.gouv.fr/
- Guide d'hygiène informatique 2023

---

**Document généré le** : 16 novembre 2025
**Conformité** : ANSSI 2023 | OpenSSH 8.8+ | SSHFS/FUSE 3.x+
**Révision** : 1.0
