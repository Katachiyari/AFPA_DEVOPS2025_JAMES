# Authentification SSH par Clé Cryptographique
## Guide Complet et Rigoureux

---

## 📋 Table des Matières

1. [Fondamentaux Cryptographiques](#fondamentaux)
2. [Recommandations ANSSI](#anssi)
3. [Préparation de l'Environnement](#préparation)
4. [Génération des Clés](#génération)
5. [Configuration Serveur SSH](#serveur)
6. [Configuration Client SSH](#client)
7. [Sécurisation Avancée](#avancée)
8. [Vérification et Tests](#tests)
9. [Maintenance et Rotation](#maintenance)

---

## 🔐 Fondamentaux Cryptographiques {#fondamentaux}

### Pourquoi l'Authentification par Clé ?

L'authentification par clé cryptographique offre plusieurs avantages fondamentaux par rapport à l'authentification par mot de passe :

- **Résistance aux attaques par force brute** : Les clés cryptographiques modernes (4096 bits RSA, 256 bits ECDSA/ED25519) présentent un espace de recherche si vaste que les attaques par force brute sont informatiquement infaisables
- **Pas de transmission de secret** : Contrairement aux mots de passe, la clé privée ne traverse jamais le réseau
- **Authentification mutuelle possible** : Permet une authentification bidirectionnelle
- **Automatisation sécurisée** : Permet l'authentification sans interaction humaine tout en maintenant la sécurité

### Types de Clés Disponibles

#### ED25519 (Recommandé - ANSSI)
- **Type** : Courbe elliptique (EdDSA)
- **Taille** : 256 bits (équivalent cryptographique : ~3072 bits RSA)
- **Avantages** : Performance supérieure, résistance quantique relative, signature déterministe
- **Documentation officielle** : https://tools.ietf.org/html/rfc8032
- **Statut ANSSI** : Recommandé pour le futur (ANSSI Guide Cryptographie 2020)

#### RSA 4096 (Acceptable)
- **Type** : Factorisation d'entiers
- **Taille** : 4096 bits
- **Avantages** : Large compatibilité, longuement éprouvé
- **Avantages** : Lent comparé à ED25519, taille des clés importante
- **Statut ANSSI** : Acceptable jusqu'en 2030 pour la signature

#### ECDSA P-256 (Déconseillé)
- **Raison du déconseillé** : Courbes spécifiques pouvant contenir des faiblesses (soupçons non confirmés de backdoor NSA NIST P-256)
- **Recommandation ANSSI** : Utiliser ED25519 plutôt que ECDSA

---

## 🛡️ Recommandations ANSSI {#anssi}

### Source Officielle ANSSI

**Document** : *Guide d'Hygiène Informatique* (Edition 2023) et *Recommandations pour la sécurité du SSH*

**Lien** : https://cyber.gouv.fr/ (rubrique publications - documents techniques)

### Recommandations Clés d'ANSSI

#### 1️⃣ Algorithme de Clé
```
✓ OBLIGATOIRE : ED25519 (courbe Curve25519)
✓ ACCEPTABLE : RSA 4096 bits minimum
✗ DÉCONSEILLÉ : ECDSA, DSA, RSA < 2048 bits
```

**Pourquoi ED25519** : Selon ANSSI, ED25519 offre une résistance quantique supérieure aux courbes elliptiques traditionnelles et présente des performances meilleures.

#### 2️⃣ Phrase de Passe (Passphrase)
```
✓ OBLIGATOIRE pour les clés privées stockées localement
✓ Longueur minimale : 20 caractères
✓ Complexité : Majuscules + minuscules + chiffres + caractères spéciaux
✓ Unicité : Jamais réutiliser une passphrase pour plusieurs clés
```

**Justification** : La passphrase protège contre l'accès à la clé privée en cas de compromission du poste de travail. Une clé privée sans passphrase qui tombe en mains malveillantes = compromission complète.

#### 3️⃣ Contrôle d'Accès Fichiers
```
~/.ssh/id_ed25519          → Permissions 600 (rw-------)
~/.ssh/id_ed25519.pub      → Permissions 644 (rw-r--r--)
~/.ssh/                    → Permissions 700 (rwx------)
~/.ssh/authorized_keys     → Permissions 600 (rw-------)
~/.ssh/config              → Permissions 600 (rw-------)
```

**Raison technique** : SSH refuse catégoriquement de fonctionner avec des permissions trop permissives. C'est une protection intentionnelle contre les clés compromises accidentellement.

#### 4️⃣ Serveur SSH - Configuration Sécurisée
```
✓ OBLIGATOIRE : PubkeyAuthentication yes
✓ OBLIGATOIRE : PasswordAuthentication no (après validation des clés)
✓ OBLIGATOIRE : PermitRootLogin no
✓ OBLIGATOIRE : PermitEmptyPasswords no
✓ OBLIGATOIRE : Protocol 2
✓ Recommandé : ListenAddress 0.0.0.0 :: (écoute IPv4 et IPv6)
✓ Recommandé : Port 22 (ou port alternatif documenté)
✓ Recommandé : LogLevel VERBOSE
```

#### 5️⃣ Chiffrement des Tunnels
```
✓ Acceptés (ANSSI) :
  - chacha20-poly1305@openssh.com (recommandé)
  - aes256-gcm@openssh.com (recommandé)
  - aes128-gcm@openssh.com (acceptable)

✗ Refuser :
  - aes256-cbc, aes128-cbc (pas d'intégrité)
  - 3des-cbc (obsolète)
```

#### 6️⃣ Échange de Clés (Key Exchange)
```
✓ Acceptés (ANSSI) :
  - curve25519-sha256
  - curve25519-sha256@libssh.org
  - diffie-hellman-group16-sha512
  
✗ Refuser :
  - diffie-hellman-group1-sha1 (obsolète)
  - diffie-hellman-group14-sha1 (faible)
```

---

## 🔧 Préparation de l'Environnement {#préparation}

### Prérequis Système

#### Sur le Client (Poste Local)
```bash
# Vérifier la présence d'OpenSSH
which ssh ssh-keygen ssh-copy-id

# Version minimale recommandée
ssh -V
# Résultat attendu : OpenSSH_8.0 ou supérieur (8.8+ recommandé)

# Vérifier le support ED25519
ssh-keygen -t ed25519 -N "" -f /tmp/test_key
# Devrait fonctionner sans erreur
```

#### Sur le Serveur
```bash
# Vérifier OpenSSH Server
systemctl status ssh      # Debian/Ubuntu
systemctl status sshd     # RHEL/CentOS/Rocky

# Vérifier la version
sshd -V

# Chemin du fichier de configuration
/etc/ssh/sshd_config
```

### Structure des Répertoires

```
Poste Client :
~/.ssh/
├── id_ed25519              (Clé privée - SECRET)
├── id_ed25519.pub          (Clé publique - peut être partagée)
├── authorized_keys_backup  (Sauvegarde - optionnel)
└── config                  (Configuration SSH client)

Serveur :
/home/utilisateur/.ssh/
├── authorized_keys         (Clés publiques autorisées)
├── known_hosts             (Empreintes des serveurs connus)
└── config                  (Configuration optionnelle)

/etc/ssh/
├── sshd_config             (Configuration du serveur SSH)
├── ssh_host_ed25519_key    (Clé privée serveur)
├── ssh_host_ed25519_key.pub (Clé publique serveur)
└── ssh_config              (Configuration système globale)
```

### Sauvegarde Préalable

⚠️ **AVANT toute manipulation**, effectuer une sauvegarde complète de la configuration SSH existante :

```bash
# Sur le client
tar czf ~/backup_ssh_client_$(date +%Y%m%d_%H%M%S).tar.gz ~/.ssh/

# Sur le serveur
sudo tar czf /root/backup_ssh_server_$(date +%Y%m%d_%H%M%S).tar.gz /etc/ssh/ /home/*/.ssh/

# Stocker les sauvegardes en lieu sûr
```

---

## 🔑 Génération des Clés {#génération}

### Méthode Recommandée : ED25519

#### Étape 1 : Génération de la Paire de Clés

```bash
# Commande complète
ssh-keygen -t ed25519 \
           -C "utilisateur@poste-local-$(date +%Y%m%d)" \
           -f ~/.ssh/id_ed25519 \
           -N ""

# Explication des paramètres :
# -t ed25519           → Type de clé (courbe elliptique ED25519)
# -C "commentaire"     → Commentaire identifiant la clé (idéal : email@date)
# -f ~/.ssh/id_ed25519 → Chemin et nom du fichier
# -N ""                → Passphrase initiale vide (sera changée)
```

**Résultat attendu** :
```
Generating public/private ed25519 key pair.
Your identification has been saved in /home/user/.ssh/id_ed25519
Your public key has been saved in /home/user/.ssh/id_ed25519.pub
The key fingerprint is:
SHA256:aBc123+DEF456gHiJkLmNoPqRsTuVwXyZ [utilisateur@poste-local-20250116]
The key's randomart image is:
+--[ED25519 256]--+
|        o.       |
|       o +       |
|        O .      |
|       B +       |
|      S o        |
|       . .       |
|                 |
+----[SHA256]-----+
```

#### Étape 2 : Ajout de la Passphrase

```bash
# Modifier la passphrase de la clé existante
ssh-keygen -p -t ed25519 -f ~/.ssh/id_ed25519 -N "" -P "nouvelle_passphrase"

# Ou méthode interactive (recommandée) :
ssh-keygen -p -f ~/.ssh/id_ed25519
# OpenSSH demandera : anciennes puis nouvelles passphrases

# Critères ANSSI pour la passphrase :
# ✓ Minimum 20 caractères
# ✓ Combinaison : Majuscules + minuscules + chiffres + spéciaux
# ✓ Pas de mots du dictionnaire
# ✓ Pas d'informations personnelles

# Exemple valide : "SecureSSH2025!@Prod#KeyAuth"
```

#### Étape 3 : Vérification des Permissions

```bash
# Vérifier les permissions générées
ls -la ~/.ssh/

# Résultat attendu :
# drwx------  2 user user 4096 Jan 16 10:15 .
# drwx------  3 user user 4096 Jan 16 10:10 ..
# -rw-------  1 user user  419 Jan 16 10:15 id_ed25519
# -rw-r--r--  1 user user  104 Jan 16 10:15 id_ed25519.pub

# Si permissions incorrectes, les corriger :
chmod 700 ~/.ssh/
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

#### Étape 4 : Affichage et Sauvegarde de la Clé Publique

```bash
# Afficher la clé publique pour partage
cat ~/.ssh/id_ed25519.pub

# Résultat attendu (format OpenSSH) :
# ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJx... utilisateur@poste-local-20250116

# Sauvegarder dans un fichier texte sécurisé
cat ~/.ssh/id_ed25519.pub > ~/id_ed25519_pub_backup.txt

# Format de la clé publique ED25519 :
# [type] [clé en base64] [commentaire]
# ssh-ed25519 (68 octets) (optionnel)
```

### Méthode Alternative : RSA 4096 (Compatibilité)

```bash
# Si compatibilité absolue requise
ssh-keygen -t rsa \
           -b 4096 \
           -C "utilisateur@poste-local-$(date +%Y%m%d)" \
           -f ~/.ssh/id_rsa

# ⚠️ Recommandation ANSSI : Préférer ED25519
# RSA 4096 reste acceptable jusqu'en 2030
```

### Vérification de la Clé Générée

```bash
# Afficher les informations de la clé privée
ssh-keygen -l -f ~/.ssh/id_ed25519

# Résultat :
# 256 SHA256:aBc123+DEF456gHiJkLmNoPqRsTuVwXyZ utilisateur@poste-local-20250116 (ED25519)

# Comparer les fingerprints (empreintes)
# Doit correspondre à celui affiché à la génération
```

---

## 🖥️ Configuration Serveur SSH {#serveur}

### Préparation du Serveur

#### Étape 1 : Connexion au Serveur

```bash
# Connexion initiale par mot de passe (temporaire)
ssh utilisateur@serveur.exemple.com

# Ou via IP
ssh utilisateur@192.168.1.100
```

#### Étape 2 : Création du Répertoire `.ssh`

```bash
# Sur le serveur, en tant qu'utilisateur
mkdir -p ~/.ssh

# Définir les permissions correctes
chmod 700 ~/.ssh

# Vérifier
ls -ld ~/.ssh
# Résultat : drwx------ X user user ...
```

#### Étape 3 : Import de la Clé Publique

**Option A : Utiliser ssh-copy-id (Recommandé)**

```bash
# Depuis le client, copier la clé publique sur le serveur
ssh-copy-id -i ~/.ssh/id_ed25519.pub utilisateur@serveur.exemple.com

# Résultat attendu :
# /usr/bin/ssh-copy-id: INFO: Source of key(s) to be updated: ~/.ssh/id_ed25519.pub
# /usr/bin/ssh-copy-id: INFO: Attempting to log in with the new key(s) to gather
# their fingerprints - will ask for password if needed
# [...] authorized_keys added.

# Avantages :
# ✓ Gère automatiquement les permissions
# ✓ Évite les erreurs de copie manuelle
# ✓ Crée authorized_keys si inexistant
```

**Option B : Copie Manuelle**

```bash
# 1. Récupérer la clé publique (depuis le client)
cat ~/.ssh/id_ed25519.pub

# 2. Sur le serveur, créer/modifier authorized_keys
nano ~/.ssh/authorized_keys

# 3. Coller la clé publique (une clé par ligne)
# ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJx... utilisateur@poste-local-20250116

# 4. Vérifier les permissions
chmod 600 ~/.ssh/authorized_keys

# 5. Enregistrer et quitter (Ctrl+O, Entrée, Ctrl+X pour nano)
```

#### Étape 4 : Vérification de l'Authentification par Clé

```bash
# Depuis le client, tester la connexion
ssh -i ~/.ssh/id_ed25519 utilisateur@serveur.exemple.com

# Ou simplement (si configuration SSH correcte) :
ssh utilisateur@serveur.exemple.com

# Résultat attendu :
# [Demande de passphrase pour la clé]
# Enter passphrase for key '/home/user/.ssh/id_ed25519': 
# [Connexion établie]
```

### Configuration Sécurisée du Serveur SSH

#### Fichier : `/etc/ssh/sshd_config`

```bash
# 1. Éditer le fichier de configuration
sudo nano /etc/ssh/sshd_config

# 2. Appliquer les paramètres ANSSI suivants
```

**Configuration Complète ANSSI (à insérer dans sshd_config)** :

```
# ======================================
# Configuration SSH Sécurisée - ANSSI
# ======================================

# 🔐 AUTHENTIFICATION
# Accepter uniquement l'authentification par clé
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM no
KerberosAuthentication no
GSSAPIAuthentication no

# Refuser l'authentification root
PermitRootLogin no

# Ne pas autoriser l'authentification par hôte
HostbasedAuthentication no

# 🔑 CLÉS D'HÔTE (Serveur)
# ED25519 prioritaire
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

# 🌐 RÉSEAU ET ÉCOUTE
# Écouter sur toutes les interfaces
ListenAddress 0.0.0.0
ListenAddress ::

# Port (garder 22 ou documenter si changé)
Port 22

# 📋 PROTOCOLE
# Uniquement SSH version 2
Protocol 2

# 🔄 ÉCHANGE DE CLÉS (Key Exchange)
# Algorithmes autorisés (ANSSI)
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512

# 🔐 CHIFFREMENT (Ciphers)
# Suites ANSSI recommandées
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com

# 🔑 AUTHENTIFICATION DE MESSAGE (MAC)
# Message Authentication Code
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# ⏱️ TIMEOUTS ET SESSIONS
# Timeout pour authentification (secondes)
LoginGraceTime 30

# Envoyer keep-alive toutes les 300 secondes
ClientAliveInterval 300
ClientAliveCountMax 2

# Nombre de sessions simultanées par utilisateur
MaxSessions 5

# 📝 LOGGING
# Verbosité augmentée
LogLevel VERBOSE
SyslogFacility AUTH

# 🔒 SÉCURITÉ SUPPLÉMENTAIRE
# Limiter les tentatives de connexion
MaxAuthTries 3
MaxStartups 10:30:100

# Refuser l'accès root par SSH
PermitUserEnvironment no
UsePrivilegeSeparation sandbox
StrictModes yes

# Refuser l'exécution de commandes
AllowAgentForwarding no
AllowTcpForwarding no
GatewayPorts no
PermitTunnel no
X11Forwarding no

# 👥 UTILISATEURS AUTORISÉS
# Optionnel : limiter aux utilisateurs spécifiques
# AllowUsers user1 user2
# DenyUsers root daemon bin

# 🔔 BANNIÈRE
# Banner /etc/ssh/banner.txt

# 📡 TRANSFERTS CHIFFRÉS
# Permettre port forwarding sécurisé si nécessaire
# AllowTcpForwarding yes
# PermitTunnel point-to-point

# ⏸️ SUBSYSTEM (SFTP)
Subsystem sftp /usr/lib/openssh/sftp-server -f AUTHPRIV -l INFO
```

#### Application de la Configuration

```bash
# 1. Vérifier la syntaxe du fichier (IMPORTANT !)
sudo sshd -t

# Résultat attendu :
# (aucun message = syntaxe correcte)

# 2. Redémarrer le service SSH
sudo systemctl restart ssh      # Debian/Ubuntu
sudo systemctl restart sshd     # RHEL/Rocky/CentOS

# 3. Vérifier que le service est actif
sudo systemctl status ssh

# 4. Vérifier l'écoute sur le port SSH
sudo ss -tlnp | grep ssh
# Résultat attendu :
# LISTEN 0.0.0.0:22  ...
# LISTEN [::]:22     ...

# ⚠️ NE PAS SE DÉCONNECTER immédiatement
# Garder la session ouverte pour tester depuis autre terminal
```

#### Test de Configuration (Nouvelle Fenêtre Terminal)

```bash
# Test 1 : Vérifier accès par clé (devrait fonctionner)
ssh -v utilisateur@serveur.exemple.com
# Devrait se connecter avec authentification par clé

# Test 2 : Vérifier refus par mot de passe
ssh -o PubkeyAuthentication=no -o PasswordAuthentication=yes utilisateur@serveur.exemple.com
# Devrait être refusé : "Permission denied (publickey)"

# Test 3 : Vérifier refus accès root
ssh root@serveur.exemple.com
# Devrait être refusé : "Permission denied (publickey)"
```

---

## 🖱️ Configuration Client SSH {#client}

### Fichier de Configuration : `~/.ssh/config`

#### Création et Structure

```bash
# Créer le fichier de configuration client
nano ~/.ssh/config

# Permissions correctes
chmod 600 ~/.ssh/config
```

#### Configuration Complète Recommandée

```
# ======================================
# Configuration SSH Client - Sécurisée
# ======================================

# 🔐 DÉFAUT GLOBAL (s'applique à tous les hôtes)
Host *
    # Authentification par clé uniquement
    PubkeyAuthentication yes
    PasswordAuthentication no
    
    # Algorithmes sécurisés
    HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
    
    # Sécurité
    StrictHostKeyChecking accept-new
    VerifyHostKeyDNS yes
    
    # Timeouts
    ServerAliveInterval 300
    ServerAliveCountMax 2
    
    # Performance
    Compression yes
    CompressionLevel 6
    
    # Forwarding
    ForwardAgent no
    ForwardX11 no
    ForwardX11Trusted no
    AllowLocalCommand no
    
    # Keep-alive
    TCPKeepAlive yes
    
    # Logging
    LogLevel INFO
    
    # Timeout de connexion (secondes)
    ConnectTimeout 10

# ======================================
# PROFIL 1 : Serveur Production
# ======================================
Host prod-web
    HostName prod-web.exemple.com
    User admin
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    
    # Paramètres spécifiques production
    StrictHostKeyChecking yes
    UserKnownHostsFile ~/.ssh/known_hosts_prod
    
    # Tunneling SSH si nécessaire
    # LocalForward 5432 localhost:5432

# ======================================
# PROFIL 2 : Serveur Développement
# ======================================
Host dev-lab
    HostName 192.168.1.100
    User developer
    Port 2222
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

# ======================================
# PROFIL 3 : Accès via Bastion
# ======================================
Host bastion-gate
    HostName bastion.exemple.com
    User admin
    Port 22
    IdentityFile ~/.ssh/id_ed25519

Host internal-* !internal-bastion
    ProxyCommand ssh -q -W %h:%p bastion-gate

Host internal-db-01
    HostName 10.0.1.50
    User dba
    ProxyCommand ssh -q -W %h:%p bastion-gate

# ======================================
# SYNTAXE CONFIGURATION
# ======================================

# Paramètres courants :
# Host [motif]              → Pattern de nom d'hôte (wildcards autorisés)
# HostName [adresse]        → Adresse réelle du serveur
# User [utilisateur]        → Utilisateur SSH (override -l)
# Port [numéro]             → Port SSH (override -p)
# IdentityFile [chemin]     → Fichier clé (peut répéter)
# IdentitiesOnly yes        → Utiliser SEULEMENT IdentityFile spécifiés
# ProxyCommand [commande]   → Tunnel SSH (relais)
# StrictHostKeyChecking     → (yes/no/accept-new)
# UserKnownHostsFile        → Fichier connu_hosts personnalisé
# ForwardAgent              → Forwarding de l'agent SSH
# LocalForward              → Tunnel local [local_port:remote_host:remote_port]
# RemoteForward             → Tunnel inverse
# Compression               → Compression de flux (yes/no)
```

#### Utilisation de la Configuration

```bash
# Avant (sans config) :
ssh -i ~/.ssh/id_ed25519 -p 2222 developer@192.168.1.100

# Après (avec config) :
ssh dev-lab

# Les paramètres de ~/.ssh/config s'appliquent automatiquement
```

### SSH Agent : Gestion Sécurisée de Passphrase

#### Démarrer l'Agent SSH

```bash
# Vérifier si l'agent est déjà en cours d'exécution
echo $SSH_AUTH_SOCK
# Résultat : /tmp/ssh-XXXXXXX/agent.XXXXX (socket de l'agent)

# Si vide, démarrer l'agent
eval "$(ssh-agent -s)"

# Résultat attendu :
# SSH_AUTH_SOCK=/tmp/ssh-XXXXXXX/agent.XXXXX; export SSH_AUTH_SOCK;
# SSH_AGENT_PID=12345; export SSH_AGENT_PID;
```

#### Ajouter la Clé à l'Agent

```bash
# Ajouter la clé privée avec passphrase
ssh-add ~/.ssh/id_ed25519

# Résultat attendu (première fois) :
# Enter passphrase for /home/user/.ssh/id_ed25519: 
# [Saisir la passphrase]
# Identity added: /home/user/.ssh/id_ed25519 (utilisateur@poste-local-20250116)

# Vérifier les clés ajoutées
ssh-add -l

# Résultat attendu :
# 256 SHA256:aBc123+DEF456gHiJkLmNoPqRsTuVwXyZ utilisateur@poste-local-20250116 (ED25519)

# Supprimer une clé de l'agent
ssh-add -d ~/.ssh/id_ed25519

# Supprimer TOUTES les clés
ssh-add -D
```

#### Configuration Automatique (Shell)

**Pour Bash (~/.bashrc)** :

```bash
# Démarrer ssh-agent automatiquement au démarrage
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    ssh-add ~/.ssh/id_ed25519 2>/dev/null
fi
```

**Pour Zsh (~/.zshrc)** :

```bash
# Démarrer ssh-agent avec Zsh
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    ssh-add ~/.ssh/id_ed25519 2>/dev/null
fi
```

**Pour Fish (~/.config/fish/config.fish)** :

```fish
# Démarrer ssh-agent avec Fish
if not set -q SSH_AUTH_SOCK
    eval (ssh-agent -c)
    ssh-add ~/.ssh/id_ed25519 2>/dev/null
end
```

### Clés Multiples

#### Cas d'Usage

```
Scenario : Clés différentes pour contextes différents
- Clé 1 (prod_ed25519)   → Serveurs production
- Clé 2 (dev_ed25519)    → Serveurs développement
- Clé 3 (personal_ed25519) → Serveurs personnels
```

#### Configuration Multi-Clés

```bash
# Générer plusieurs clés
ssh-keygen -t ed25519 -f ~/.ssh/id_prod_ed25519 -C "prod@2025"
ssh-keygen -t ed25519 -f ~/.ssh/id_dev_ed25519 -C "dev@2025"

# Configuration ~/.ssh/config
Host prod-*
    IdentityFile ~/.ssh/id_prod_ed25519
    IdentitiesOnly yes

Host dev-*
    IdentityFile ~/.ssh/id_dev_ed25519
    IdentitiesOnly yes

# Ajouter à l'agent
ssh-add ~/.ssh/id_prod_ed25519
ssh-add ~/.ssh/id_dev_ed25519

# Vérifier
ssh-add -l
```

---

## 🔒 Sécurisation Avancée {#avancée}

### Protection Contre les Attaques Courantes

#### 1️⃣ Attaque : Accès Non Autorisé à `authorized_keys`

**Menace** : Ajout d'une clé malveillante par un attaquant local

**Protection** :
```bash
# Rendre le fichier immuable (Linux)
sudo chattr +i ~/.ssh/authorized_keys

# Vérifier
lsattr ~/.ssh/authorized_keys
# Résultat : ----i---------e-- (le 'i' indique immuable)

# Pour modifier à nouveau :
sudo chattr -i ~/.ssh/authorized_keys
```

#### 2️⃣ Attaque : Clé Privée Compromise

**Menace** : Clé privée volée ou exposée accidentellement

**Protection** :
```bash
# 1. Ajouter une passphrase forte
ssh-keygen -p -f ~/.ssh/id_ed25519

# 2. Révoquer immédiatement la clé
# → Sur le serveur, supprimer la clé de authorized_keys
ssh utilisateur@serveur.exemple.com
nano ~/.ssh/authorized_keys
# [Supprimer la ligne contenant la clé compromise]

# 3. Générer une nouvelle clé
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_new

# 4. Importer la nouvelle clé
ssh-copy-id -i ~/.ssh/id_ed25519_new.pub utilisateur@serveur.exemple.com

# 5. Archiver l'ancienne clé
mkdir ~/.ssh/retired
mv ~/.ssh/id_ed25519 ~/.ssh/retired/id_ed25519_$(date +%Y%m%d_%s)
```

#### 3️⃣ Attaque : Man-in-the-Middle (MITM) sur `known_hosts`

**Menace** : Usurpation de serveur SSH

**Protection** :
```bash
# Vérifier les clés hôte du serveur PRÉ-PARTAGE
# 1. Admin serveur :
sudo ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub

# Résultat :
# 256 SHA256:AbCdEfGhIjKlMnOpQrStUvWxYz1234567890abcd root@serveur (ED25519)

# 2. Admin client : Comparer manuellement
ssh -v utilisateur@serveur.exemple.com 2>&1 | grep "fingerprint"

# Output :
# The authenticity of host 'serveur.exemple.com (192.168.1.100)' can't be established.
# ED25519 key fingerprint is SHA256:AbCdEfGhIjKlMnOpQrStUvWxYz1234567890abcd.

# 3. Vérifier correspondance → Accept

# Utiliser DNSSEC + SSHFP (avancé)
# cf. RFC 4255
```

#### 4️⃣ Attaque : Force Brute sur Authentification

**Menace** : Tentatives répétées de connexion

**Protection (coté serveur)** :
```bash
# Dans /etc/ssh/sshd_config :
MaxAuthTries 3              # Max 3 tentatives
MaxStartups 10:30:100       # Limiter les connexions parallèles
LoginGraceTime 30           # Timeout login 30 secondes

# Fail2Ban (détection automatique)
sudo apt install fail2ban
sudo nano /etc/fail2ban/jail.local

# Ajouter :
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
findtime = 600
bantime = 3600
```

### Audit et Monitoring

#### Logs SSH

```bash
# Sur le client
# Logs détaillés avec -v (verbose)
ssh -v utilisateur@serveur.exemple.com

# Logs détaillés avec -vv
ssh -vv utilisateur@serveur.exemple.com

# Logs très détaillés avec -vvv
ssh -vvv utilisateur@serveur.exemple.com

# Sur le serveur
# Fichier de logs SSH
sudo tail -f /var/log/auth.log | grep ssh

# Exemple de log réussi :
# Nov 16 10:15:23 serveur sshd[1234]: Accepted publickey for utilisateur from 192.168.1.50 port 54321 ssh2: ED25519 SHA256:aBc...

# Exemple de log échoué :
# Nov 16 10:16:00 serveur sshd[1235]: Invalid user attacker from 192.168.1.51 port 54322 ssh2
```

#### Audit des Clés Publiques

```bash
# Lister toutes les clés autorisées sur le serveur
cat ~/.ssh/authorized_keys

# Vérifier les empreintes des clés
ssh-keygen -l -f ~/.ssh/authorized_keys

# Archiver les clés anciennes
mkdir ~/.ssh/archived_keys
mv ~/.ssh/authorized_keys ~/.ssh/archived_keys/authorized_keys.$(date +%Y%m%d_%H%M%S)
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Mettre à jour avec nouvelles clés
ssh-copy-id -i ~/.ssh/id_ed25519.pub utilisateur@serveur.exemple.com
```

#### Vérification des Permissions (Audit Automatisé)

```bash
#!/bin/bash
# Script d'audit permissions SSH

echo "=== Audit Permissions SSH ==="

# Vérifier répertoire .ssh
SSHDIR="$HOME/.ssh"
EXPECTED_PERM_DIR="700"
ACTUAL_PERM_DIR=$(stat -c %a "$SSHDIR" 2>/dev/null || stat -f %OLp "$SSHDIR" | tail -c 4)

echo "Répertoire $SSHDIR :"
if [ "$ACTUAL_PERM_DIR" = "$EXPECTED_PERM_DIR" ]; then
    echo "  ✓ Permissions correctes : $ACTUAL_PERM_DIR"
else
    echo "  ✗ Permissions incorrectes : $ACTUAL_PERM_DIR (attendu : $EXPECTED_PERM_DIR)"
    chmod 700 "$SSHDIR"
fi

# Vérifier clé privée
for keyfile in "$SSHDIR"/id_*; do
    [ ! -f "$keyfile" ] && continue
    EXPECTED_PERM="600"
    ACTUAL_PERM=$(stat -c %a "$keyfile" 2>/dev/null || stat -f %OLp "$keyfile" | tail -c 4)
    
    echo "Clé $keyfile :"
    if [ "$ACTUAL_PERM" = "$EXPECTED_PERM" ]; then
        echo "  ✓ Permissions correctes : $ACTUAL_PERM"
    else
        echo "  ✗ Permissions incorrectes : $ACTUAL_PERM (attendu : $EXPECTED_PERM)"
        chmod 600 "$keyfile"
    fi
done

# Vérifier authorized_keys
AUTH_KEYS="$SSHDIR/authorized_keys"
if [ -f "$AUTH_KEYS" ]; then
    EXPECTED_PERM="600"
    ACTUAL_PERM=$(stat -c %a "$AUTH_KEYS" 2>/dev/null || stat -f %OLp "$AUTH_KEYS" | tail -c 4)
    
    echo "Fichier $AUTH_KEYS :"
    if [ "$ACTUAL_PERM" = "$EXPECTED_PERM" ]; then
        echo "  ✓ Permissions correctes : $ACTUAL_PERM"
    else
        echo "  ✗ Permissions incorrectes : $ACTUAL_PERM (attendu : $EXPECTED_PERM)"
        chmod 600 "$AUTH_KEYS"
    fi
fi

echo "=== Audit Terminé ==="
```

---

## ✅ Vérification et Tests {#tests}

### Checklist de Validation Complète

#### Phase 1 : Génération des Clés

- [ ] Clé ED25519 générée avec passphrase ANSSI (≥20 caractères)
- [ ] Permissions : `id_ed25519` = 600, `id_ed25519.pub` = 644
- [ ] Répertoire `~/.ssh/` = 700
- [ ] Empreinte (fingerprint) vérifiée et documentée

#### Phase 2 : Configuration Serveur

- [ ] Fichier `sshd_config` modifié avec paramètres ANSSI
- [ ] Syntaxe validée : `sudo sshd -t` (aucune erreur)
- [ ] Service SSH redémarré
- [ ] Écoute SSH vérifiée : `sudo ss -tlnp | grep ssh`

#### Phase 3 : Import Clé Publique

- [ ] Répertoire `~/.ssh/` créé sur serveur (700)
- [ ] Fichier `authorized_keys` créé/mis à jour (600)
- [ ] Clé publique importée correctement

#### Phase 4 : Authentification par Clé

- [ ] Connexion SSH par clé réussie
- [ ] Demande de passphrase fonctionnelle
- [ ] Authentification par mot de passe refusée (si configuré)

#### Phase 5 : Sécurité

- [ ] SSH Agent configuré et fonctionnel
- [ ] Clé ajoutée à l'agent
- [ ] `known_hosts` mis à jour après première connexion
- [ ] Logs SSH examinés (pas d'erreur anormale)

### Tests Pratiques

#### Test 1 : Connexion Basique avec Clé

```bash
# Depuis le client
ssh -v utilisateur@serveur.exemple.com

# Résultat attendu :
# Debug : Reading config data /home/user/.ssh/config
# Debug : Offering key: /home/user/.ssh/id_ed25519 ED25519 SHA256:...
# Debug : Server host key: ssh-ed25519 SHA256:...
# Authenticity of host verified.
# Welcome to serveur.exemple.com
# Last login: ...
```

#### Test 2 : Refus de Mot de Passe

```bash
# Forcer refus de clé, authenticatio par mot de passe
ssh -o PubkeyAuthentication=no -o PasswordAuthentication=yes utilisateur@serveur.exemple.com

# Résultat attendu :
# [demande de mot de passe]
# Permission denied (password). [x/y]
```

#### Test 3 : Refus Accès Root

```bash
# Essayer de se connecter en root
ssh root@serveur.exemple.com

# Résultat attendu :
# Permission denied (publickey).
```

#### Test 4 : Fingerprint Verification

```bash
# Afficher fingerprint serveur depuis le client
ssh-keyscan serveur.exemple.com 2>/dev/null | ssh-keygen -lf -

# Comparer avec fingerprint du serveur :
sudo ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub

# Résultat attendu : IDENTIQUES
```

#### Test 5 : Performance et Algorithme

```bash
# Diagnostic SSH détaillé
ssh -vvv utilisateur@serveur.exemple.com 2>&1 | grep -E "^debug.*key|^debug.*cipher"

# Résultat attendu :
# debug1: Offering public key: /home/user/.ssh/id_ed25519 ED25519 SHA256:...
# debug1: Authenticity of host ... can't be established.
# debug1: Found key in /home/user/.ssh/known_hosts
# debug1: rekey after 4294967296 bytes
# debug1: SSH2_MSG_SERVICE_ACCEPT received
# debug1: Using authentication method "publickey"
# [...]
```

---

## 🔄 Maintenance et Rotation {#maintenance}

### Rotation des Clés (Recommandé Annuellement)

#### Politique de Rotation ANSSI

**Fréquence recommandée** : 1 année

**Raison** : Limiter l'exposition en cas de fuite (compromission non détectée)

#### Procédure de Rotation Sécurisée

```bash
# Étape 1 : Générer nouvelle paire de clés
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_new -C "utilisateur@$(date +%Y-%m-%d)"

# Étape 2 : Ajouter la NOUVELLE clé à tous les serveurs
ssh-copy-id -i ~/.ssh/id_ed25519_new.pub utilisateur@serveur1.exemple.com
ssh-copy-id -i ~/.ssh/id_ed25519_new.pub utilisateur@serveur2.exemple.com
# ... pour tous les serveurs

# Étape 3 : Tester la nouvelle clé sur chaque serveur
ssh -i ~/.ssh/id_ed25519_new utilisateur@serveur1.exemple.com "echo TEST SUCCÈS"

# Étape 4 : Une fois CONFIRMÉE sur tous les serveurs
# → Remplacer l'ancienne clé
mv ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.old.$(date +%Y%m%d)
mv ~/.ssh/id_ed25519_new ~/.ssh/id_ed25519
mv ~/.ssh/id_ed25519_new.pub ~/.ssh/id_ed25519.pub

# Étape 5 : Supprimer l'ancienne clé des serveurs
# [Sur chaque serveur]
nano ~/.ssh/authorized_keys
# [Supprimer la ligne de l'ancienne clé]

# Étape 6 : Archiver l'ancienne clé
mkdir -p ~/.ssh/archive
cp ~/.ssh/id_ed25519.old.* ~/.ssh/archive/
# [Chiffrer et stocker en lieu sûr si besoin]

# Étape 7 : Mettre à jour la config SSH
nano ~/.ssh/config
# [Vérifier que IdentityFile pointe sur la bonne clé]

# Étape 8 : Vérifier les logs
sudo grep "Accepted publickey" /var/log/auth.log | tail -5
```

### Gestion des Clés Compromises

#### Scénario : Clé Compromise Détectée

```bash
# ⚠️ URGENT - Isolation immédiate

# 1. Déconnecter l'agent
ssh-add -d ~/.ssh/id_ed25519_compromised

# 2. Désactiver immédiatement sur tous les serveurs
# [Sur chaque serveur, connexion alternative]
ssh -i ~/.ssh/id_ed25519_backup utilisateur@serveur.exemple.com

# Supprimer la clé compromise
nano ~/.ssh/authorized_keys
# [Supprimer la ligne]

# 3. Archiver la clé compromise
mv ~/.ssh/id_ed25519_compromised ~/.ssh/retired/
echo "Clé compromise le : $(date)" > ~/.ssh/retired/id_compromised.txt

# 4. Générer une nouvelle clé
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519

# 5. Importer sur tous les serveurs
for server in serveur1 serveur2 serveur3; do
    ssh-copy-id -i ~/.ssh/id_ed25519.pub utilisateur@$server.exemple.com
done

# 6. Notifier les administrateurs (incident log)
echo "Incident - Clé compromise : $(date)" >> ~/.ssh/incident.log
```

### Sauvegarde et Récupération

#### Sauvegarde Sécurisée

```bash
# 1. Créer une sauvegarde chiffrée de la clé privée
gpg --symmetric --cipher-algo AES256 ~/.ssh/id_ed25519
# Demande d'une passphrase GPG (différente de SSH)

# Résultat : ~/.ssh/id_ed25519.gpg

# 2. Stocker la sauvegarde en lieu sûr
cp ~/.ssh/id_ed25519.gpg /media/secure_backup/
# ou
# scp ~/.ssh/id_ed25519.gpg admin@backup.secure.com:/backup/

# 3. Supprimer le fichier d'origine du disque (après vérification)
shred -u ~/.ssh/id_ed25519
# (Rendre l'fichier irrécupérable par des outils de récupération)

# 4. Garder seulement la clé publique
# ~/.ssh/id_ed25519.pub (peut être partagée)
```

#### Récupération de Clé Sauvegardée

```bash
# 1. Récupérer le fichier GPG
scp admin@backup.secure.com:/backup/id_ed25519.gpg ~/.ssh/

# 2. Déchiffrer
gpg --output ~/.ssh/id_ed25519 --decrypt ~/.ssh/id_ed25519.gpg
# Demande de passphrase GPG

# 3. Vérifier les permissions
chmod 600 ~/.ssh/id_ed25519

# 4. Tester
ssh-keygen -l -f ~/.ssh/id_ed25519

# 5. Supprimer le fichier GPG temporaire
shred -u ~/.ssh/id_ed25519.gpg
```

### Monitoring Continu

#### Script de Monitoring SSH

```bash
#!/bin/bash
# Script de monitoring SSH - À exécuter régulièrement (cron)

ALERT_EMAIL="admin@exemple.com"
LOG_FILE="/var/log/ssh_monitoring.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Début du monitoring SSH" >> $LOG_FILE

# 1. Vérifier service SSH
if ! systemctl is-active --quiet ssh; then
    echo "⚠️  ALERTE : Service SSH down!" >> $LOG_FILE
    echo "Service SSH est arrêté!" | mail -s "ALERTE SSH" $ALERT_EMAIL
fi

# 2. Vérifier permissions .ssh
SSHDIR="/home/utilisateur/.ssh"
ACTUAL=$(stat -c %a "$SSHDIR" 2>/dev/null)
if [ "$ACTUAL" != "700" ]; then
    echo "⚠️  ALERTE : Permissions $SSHDIR incorrectes ($ACTUAL != 700)" >> $LOG_FILE
fi

# 3. Vérifier taille authorized_keys
AUTHKEYS_SIZE=$(wc -l < "$SSHDIR/authorized_keys" 2>/dev/null || echo "0")
echo "Nombre de clés autorisées : $AUTHKEYS_SIZE" >> $LOG_FILE

# 4. Chercher tentatives échouées
FAILED_LOGINS=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
if [ $FAILED_LOGINS -gt 100 ]; then
    echo "⚠️  ALERTE : $FAILED_LOGINS tentatives de connexion échouées" >> $LOG_FILE
fi

# 5. Vérifier empreinte clé serveur
SERVER_FINGERPRINT=$(ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub 2>/dev/null)
echo "Empreinte serveur : $SERVER_FINGERPRINT" >> $LOG_FILE

# 6. Archiver les anciens logs SSH
find /var/log -name "auth.log*" -mtime +30 -exec gzip {} \;

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Fin du monitoring SSH" >> $LOG_FILE
```

#### Planifier le Monitoring (Cron)

```bash
# Éditer le fichier crontab
crontab -e

# Ajouter la ligne suivante (monitoring quotidien à 2h du matin)
0 2 * * * /path/to/ssh_monitoring.sh

# Vérifier les tâches cron actives
crontab -l
```

---

## 📚 Références Officielles et Documentation

### Documentation Officielle

**1. RFC OpenSSH Standards**
- RFC 4251 : The Secure Shell (SSH) Protocol Architecture
- RFC 4252 : The Secure Shell (SSH) Authentication Protocol
- RFC 8032 : Edwards-Curve Digital Signature Algorithm (EdDSA)

**2. Recommandations ANSSI**
- Guide d'hygiène informatique (ANSSI, 2023)
- Recommandations de sécurité relatives à SSH (ANSSI)
- Document : https://cyber.gouv.fr/publications

**3. Man pages (Référence locale)**
```bash
man ssh                 # Client SSH
man sshd                # Serveur SSH
man ssh-keygen          # Génération de clés
man ssh_config          # Configuration client
man sshd_config         # Configuration serveur
man authorized_keys     # Format authorized_keys
man ssh-agent           # Agent SSH
```

**4. Site Officiel OpenSSH**
- https://www.openssh.com/
- https://man.openbsd.org/ssh

### Commandes de Référence

```bash
# Génération
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "commentaire"

# Copie de clé
ssh-copy-id -i ~/.ssh/id_ed25519.pub utilisateur@serveur

# Connexion
ssh utilisateur@serveur
ssh -i ~/.ssh/id_ed25519 utilisateur@serveur
ssh -v utilisateur@serveur          # Verbose
ssh -vvv utilisateur@serveur        # Très verbose

# Agent SSH
ssh-agent                           # Démarrer
ssh-add ~/.ssh/id_ed25519           # Ajouter clé
ssh-add -l                          # Lister clés
ssh-add -d ~/.ssh/id_ed25519        # Supprimer clé

# Vérification
ssh-keygen -l -f ~/.ssh/id_ed25519  # Afficher fingerprint
sshd -t                             # Tester config serveur
ssh-keyscan serveur                 # Scanner clés serveur

# Secure Copy
scp -i ~/.ssh/id_ed25519 fichier.txt utilisateur@serveur:/destination/
scp -r utilisateur@serveur:/source/ ./destination/
```

---

**Document généré le** : 16 novembre 2025
**Conformité** : ANSSI 2023 | OpenSSH 8.8+
**Révision** : 1.0
