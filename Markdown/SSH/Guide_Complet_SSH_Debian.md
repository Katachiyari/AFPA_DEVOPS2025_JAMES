# 🔐 Guide Complet : Installation et Configuration de l'Authentification SSH par Clé sur Debian

---

## 📋 Table des matières

1. [Introduction et contexte](#introduction)
2. [Principes fondamentaux de SSH](#principes)
3. [Architecture de l'authentification par clé](#architecture)
4. [Prérequis et environnement](#prerequis)
5. [Étape 1 : Installation de OpenSSH](#installation-openssh)
6. [Étape 2 : Génération de la paire de clés (Client)](#generation-cles)
7. [Étape 3 : Déploiement de la clé publique sur le serveur](#deploiement-cle)
8. [Étape 4 : Configuration du serveur SSH](#configuration-serveur)
9. [Étape 5 : Test et validation](#test-validation)
10. [Étape 6 : Sécurisation avancée](#securisation-avancée)
11. [Dépannage et solutions](#depannage)
12. [Bonnes pratiques et gestion des clés](#bonnes-pratiques)
13. [Sources officielles et références](#references)

---

## 1. Introduction et contexte {#introduction}

### 🎯 Objectif du guide

Ce guide vous enseignera à mettre en place l'authentification par **clé publique/privée SSH** sur un système **Debian**. Cette méthode remplace l'authentification par mot de passe et offre plusieurs avantages :

- ✅ **Sécurité renforcée** : aucune transmission de mot de passe sur le réseau
- ✅ **Automatisation sans surveillance** : idéal pour scripts et déploiements
- ✅ **Gestion centralisée des accès** : ajout/suppression simple des utilisateurs
- ✅ **Protection contre les attaques par force brute** : les clés sont mathématiquement complexes

### 📖 Références officielles

- **Documentation Debian officielle** : https://wiki.debian.org/SSH
- **OpenSSH documentation** : https://man.openbsd.org/ssh
- **Recommandations ANSSI** : https://cyber.gouv.fr (Document NT OpenSSH)

---

## 2. Principes fondamentaux de SSH {#principes}

### 🔑 Qu'est-ce que SSH ?

**SSH (Secure Shell)** est un protocole de communication chiffré permettant de se connecter à un serveur distant de manière sécurisée. Il remplace les anciens protocoles non chiffrés comme Telnet.

### 🛡️ Qu'est-ce que l'authentification par clé ?

L'authentification par clé repose sur la **cryptographie asymétrique** :

- **Clé publique** : mathématiquement générée avec la clé privée, elle est partagée au serveur
- **Clé privée** : secret à conserver précieusement, elle signe les demandes de connexion
- **Algorithme** : Lors d'une connexion, le serveur défie le client. Seul le détenteur de la clé privée peut répondre correctement.

### 📊 Comparaison des méthodes d'authentification

| Critère | Mot de passe | Clé SSH |
|---------|-------------|---------|
| **Sécurité** | Faible (sensible aux attaques par force brute) | Très élevée (cryptographie asymétrique) |
| **Usabilité** | Simple (à taper) | Complexe (à stocker) |
| **Automatisation** | Difficile (interaction requise) | Facile (sans intervention) |
| **Transport** | Mot de passe sur le réseau | Aucun secret ne transite |
| **Conformité** | Non recommandée par l'ANSSI | Recommandée (ANSSI) |

---

## 3. Architecture de l'authentification par clé {#architecture}

### 🔄 Flux de connexion SSH par clé

```
┌──────────────────┐                           ┌──────────────────┐
│   CLIENT (Vous)  │                           │   SERVEUR (SSH)  │
│                  │                           │                  │
│  Clé privée 🔒   │────────────────────────→ │ Clé publique ✓   │
│  Clé publique ✓  │  Demande de connexion     │ (authorized_keys)│
│                  │  + signature              │                  │
│                  │                           │                  │
│                  │ ← Défi cryptographique ── │ Challenge        │
│                  │                           │ (nonce aléatoire)|
│                  │                           │                  │
│  Signe avec      │                           │                  │
│  clé privée ─────→ Réponse signée           │  Vérifie avec    │
│  (preuve)        │  (proof)                  │  clé publique    │
│                  │                           │                  │
│  ✅ Connecté !   │ ← Accès autorisé ─────── │  Enregistrement  │
│                  │                           │  de session      │
└──────────────────┘                           └──────────────────┘
```

### 🏗️ Structure des fichiers clés

Sur le **client** (`~/.ssh/`) :

```
~/.ssh/
├── id_ed25519          ← Clé PRIVÉE (ne jamais partager !)
├── id_ed25519.pub      ← Clé PUBLIQUE (à copier sur serveur)
├── config              ← Configuration SSH client
└── known_hosts         ← Empreintes des serveurs connus
```

Sur le **serveur** (`~/.ssh/`) :

```
~/.ssh/
├── authorized_keys     ← Clés publiques autorisées (une par ligne)
└── authorized_keys2    ← Ancien format (compatible)
```

Sur le **serveur** (`/etc/ssh/`) :

```
/etc/ssh/
├── sshd_config         ← Configuration du serveur SSH
├── ssh_host_ed25519_key   ← Clé d'identité du serveur (privée)
├── ssh_host_ed25519_key.pub  ← Clé d'identité du serveur (publique)
└── ... (autres fichiers de clés et config)
```

---

## 4. Prérequis et environnement {#prerequis}

### ✔️ Pré-requis système

- Un **système Debian** (version 10 Buster, 11 Bullseye, 12 Bookworm ou supérieur)
- **Accès root ou sudo** sur le serveur cible
- Un **terminal** fonctionnel sur le client
- Une **connexion réseau** entre client et serveur (SSH port 22 par défaut)

### 🖥️ Environnement de test supposé

Pour ce guide, nous utilisons les variables suivantes :

```
CLIENT_MACHINE  = mon-ordinateur (192.168.1.100)
SERVER_IP       = 203.0.113.50 (serveur Debian distant)
USERNAME        = admin (utilisateur sur le serveur)
SSH_PORT        = 22 (port standard, modifiable)
```

**Adaptez ces valeurs à votre infrastructure.**

### 🔍 Vérification de l'environnement

**Sur le client :**

```bash
# Vérifier que SSH client est installé
ssh -V
# Output: OpenSSH_9.0p1 Debian-1, OpenSSL 3.0.8 16 Jan 2023
```

**Sur le serveur :**

```bash
# Vérifier que SSH serveur est installé
sudo systemctl status ssh
# Vérifier la version
sshd -v
# Output: OpenSSH_9.0p1 Debian-1, OpenSSL 3.0.8 16 Jan 2023
```

---

## 5. Étape 1 : Installation de OpenSSH {#installation-openssh}

### 📦 Sur le serveur Debian

OpenSSH est souvent pré-installé sur Debian. Vérifiez d'abord :

```bash
# Vérifier l'état du service SSH
sudo systemctl status ssh
```

**Si SSH n'est pas installé, l'installer :**

```bash
# Mettre à jour la liste des paquets
sudo apt update

# Installer openssh-server et openssh-client
sudo apt install -y openssh-server openssh-client

# Vérifier l'installation
sudo systemctl status ssh
```

**Sortie attendue :**

```
● ssh.service - OpenSSH Secure Shell Protocol server
     Loaded: loaded (/lib/systemd/system/ssh.service; enabled; vendor preset: enabled)
     Active: active (running) since Sun 2025-11-16 22:00:00 CET; 5min ago
```

### 🚀 Démarrage du service SSH

```bash
# Démarrer le service SSH immédiatement
sudo systemctl start ssh

# Activer le démarrage automatique au redémarrage
sudo systemctl enable ssh

# Vérifier que c'est actif
sudo systemctl is-active ssh
# Output: active

sudo systemctl is-enabled ssh
# Output: enabled
```

### 🔍 Vérification que SSH écoute

```bash
# Vérifier que SSH écoute sur le port 22
sudo netstat -tlnp | grep ssh
# ou avec ss (plus moderne)
sudo ss -tlnp | grep ssh

# Sortie attendue :
# tcp    0    0 0.0.0.0:22    0.0.0.0:*    LISTEN    1234/sshd
# tcp6   0    0 [::]:22       [::]:*       LISTEN    1234/sshd
```

---

## 6. Étape 2 : Génération de la paire de clés (Client) {#generation-cles}

### 🔐 Générer la paire de clés sur la machine client

**Sur votre ordinateur local (client)**, générez une paire de clés SSH.

#### Recommandations de l'ANSSI (Agence Nationale de la Sécurité des Systèmes d'Information)

L'**ANSSI recommande l'algorithme Ed25519** pour sa robustesse moderne :

- **Ed25519** : 256 bits, courbe elliptique rapide et sûre ✅ Recommandé
- **RSA** : 4096 bits minimum (algorithme plus ancien) ⚠️ Accepté
- **ECDSA** : 256 bits (moyen de remplacement) ⚠️ Acceptable

### 📝 Commande de génération Ed25519

```bash
# Générer une clé Ed25519 avec 100 itérations (ANSSI-compliant)
ssh-keygen -t ed25519 -a 100 -C "user@machine-client" -f ~/.ssh/id_ed25519
```

**Explications des paramètres :**

| Paramètre | Signification |
|-----------|---------------|
| `-t ed25519` | Type de clé : Ed25519 (cryptographie moderne) |
| `-a 100` | Nombre d'itérations pour renforcer la clé privée contre les attaques par force brute |
| `-C "user@machine-client"` | Commentaire pour identifier la clé (email, machine, etc.) |
| `-f ~/.ssh/id_ed25519` | Chemin du fichier clé à générer |

### 🔐 Saisie du mot de passe (Passphrase)

Lors de l'exécution, SSH vous demande :

```
Enter passphrase (empty for no passphrase):
```

**Recommandation** : ✅ **Entrez une passphrase forte** pour protéger votre clé privée

```
Passphrase exemple (minimum 12 caractères avec majuscules, minuscules, chiffres, symboles) :
p@ssW0rd_SSH_2025_Secure!
```

**Sortie complète d'exécution :**

```bash
$ ssh-keygen -t ed25519 -a 100 -C "admin@client" -f ~/.ssh/id_ed25519

Generating public/private ed25519 key pair.
Enter file in which to save the key (/home/admin/.ssh/id_ed25519): 
Enter passphrase (empty for no passphrase): ••••••••••••
Enter same passphrase again: ••••••••••••
Your identification has been saved in /home/admin/.ssh/id_ed25519
Your public key has been saved in /home/admin/.ssh/id_ed25519.pub
The key fingerprint is:
SHA256:R3XkZ9jK2mL8pQ4vW5xY1aB2cD3eF4gH5iJ6kL7mN8oP admin@client
The key's randomart image is:
+--[ED25519 256]--+
|        .o.      |
|       . o.o     |
|      o  o . .   |
|     . o .  .    |
|      . S .      |
|       o o E     |
|      . o   o    |
|     o   . .o    |
|    o .  ..      |
+----[SHA256]-----+
```

### ✅ Vérification de la création

```bash
# Lister les fichiers créés
ls -la ~/.ssh/

# Sortie attendue :
# -rw------- 1 admin admin  411 Nov 16 22:05 id_ed25519
# -rw-r--r-- 1 admin admin   97 Nov 16 22:05 id_ed25519.pub
```

**Important :** Notez les **permissions** :
- Clé privée `id_ed25519` : `600` (propriétaire seul)
- Clé publique `id_ed25519.pub` : `644` (lisible par tous)

### 🔍 Consulter le contenu de la clé publique

```bash
# Afficher la clé publique (à partager)
cat ~/.ssh/id_ed25519.pub

# Sortie :
# ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... admin@client
```

**Cette sortie sera copiée sur le serveur.**

---

## 7. Étape 3 : Déploiement de la clé publique sur le serveur {#deploiement-cle}

### 🔄 Méthode 1 : Automatique avec ssh-copy-id (Recommandée)

**La commande `ssh-copy-id` automatise complètement le processus :**

```bash
# Copier la clé publique sur le serveur
ssh-copy-id -i ~/.ssh/id_ed25519.pub -p 22 admin@203.0.113.50
```

**Paramètres :**

| Paramètre | Signification |
|-----------|---------------|
| `-i ~/.ssh/id_ed25519.pub` | Chemin de la clé publique à copier |
| `-p 22` | Port SSH du serveur (22 par défaut) |
| `admin@203.0.113.50` | Utilisateur et adresse IP du serveur |

**Exécution et sortie :**

```bash
$ ssh-copy-id -i ~/.ssh/id_ed25519.pub admin@203.0.113.50

/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s)
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now to supply a password, that is ok - it will be installed in a secure manner.
admin@203.0.113.50's password:  # ← Entrez le mot de passe de l'utilisateur admin

Number of key(s) added: 1

Now try logging in with:   "ssh 'admin@203.0.113.50'"
and check to make sure that only the key(s) you wanted were added.
```

**Ce que `ssh-copy-id` fait en arrière-plan :**

1. Se connecte au serveur avec mot de passe
2. Crée le répertoire `~/.ssh` s'il n'existe pas
3. Crée le fichier `~/.ssh/authorized_keys`
4. Ajoute la clé publique à `authorized_keys`
5. Définit les permissions correctes (`600` pour authorized_keys, `700` pour `.ssh`)

### 🔄 Méthode 2 : Manuelle (Dépannage ou accès limité)

**Si `ssh-copy-id` ne fonctionne pas, procédez manuellement :**

#### Étape 2.1 : Afficher la clé publique

```bash
# Sur le CLIENT, afficher la clé publique
cat ~/.ssh/id_ed25519.pub

# Copier la sortie entière (commençant par ssh-ed25519)
```

#### Étape 2.2 : Créer la structure .ssh sur le serveur

```bash
# Sur le SERVEUR, créer le dossier .ssh
mkdir -p ~/.ssh

# Définir les permissions appropriées
chmod 700 ~/.ssh
```

#### Étape 2.3 : Ajouter la clé au fichier authorized_keys

```bash
# Sur le SERVEUR, ouvrir l'éditeur
nano ~/.ssh/authorized_keys

# Coller la clé publique du client (une clé par ligne)
# Exemple de contenu :
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... admin@client

# Sauvegarder : Ctrl+X → Y → Entrée
```

#### Étape 2.4 : Configurer les permissions finales

```bash
# Sur le SERVEUR, définir les permissions strictes
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh

# Vérifier
ls -la ~/.ssh/
# -rw------- 1 admin admin  411 Nov 16 22:10 authorized_keys
# drwx------ 2 admin admin 4096 Nov 16 22:10 .
```

---

## 8. Étape 4 : Configuration du serveur SSH {#configuration-serveur}

### 📄 Fichier de configuration principal

Le fichier de configuration serveur SSH se situe à : `/etc/ssh/sshd_config`

### 🔐 Vérifier les paramètres d'authentification par clé

```bash
# Sur le SERVEUR, ouvrir le fichier de configuration
sudo nano /etc/ssh/sshd_config
```

**Vérifier ou activer les lignes suivantes :**

```bash
# 1. Autoriser l'authentification par clé publique
PubkeyAuthentication yes

# 2. Localisation du fichier authorized_keys
AuthorizedKeysFile      .ssh/authorized_keys .ssh/authorized_keys2

# 3. (Optionnel) Désactiver l'authentification par mot de passe
# PasswordAuthentication no    # À décommenter APRÈS validation avec clé

# 4. (Sécurité) Désactiver l'accès root en SSH
PermitRootLogin no
```

### 🛡️ Configuration de sécurité renforcée (ANSSI-compliant)

Pour une sécurité maximale, ajoutez à `/etc/ssh/sshd_config` :

```bash
# ========== SÉCURITÉ OPENSSH (ANSSI) ==========

# Algorithmes de clés hôte autorisées
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

# Authentification
PubkeyAuthentication yes
PasswordAuthentication no  # ⚠️ À valider en clé d'abord !
PermitRootLogin no

# Algorithmes d'échange de clés (Key Exchange) recommandés
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512

# Chiffrement autorisé
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr

# Codes d'authentification de message (MAC)
MACs hmac-sha2-512,hmac-sha2-256

# Délai d'inactivité
ClientAliveInterval 300
ClientAliveCountMax 3

# Logging
SyslogFacility AUTH
LogLevel VERBOSE
```

### ✅ Vérifier la syntaxe de configuration

```bash
# Avant de redémarrer, vérifier la syntaxe
sudo sshd -t

# Si OK, pas d'output. Sinon, affiche les erreurs.
```

### 🔄 Appliquer les modifications

```bash
# Redémarrer le service SSH
sudo systemctl restart ssh

# Vérifier que le service redémarrage sans erreur
sudo systemctl status ssh

# Sortie attendue :
# ● ssh.service - OpenSSH Secure Shell Protocol server
#      Loaded: loaded (/lib/systemd/system/ssh.service; enabled; vendor preset: enabled)
#      Active: active (running) since Sun 2025-11-16 22:15:00 CET; 1s ago
```

---

## 9. Étape 5 : Test et validation {#test-validation}

### 🧪 Première connexion avec la clé

**Sur le CLIENT, tenter la connexion :**

```bash
# Connexion SSH avec la clé Ed25519
ssh -i ~/.ssh/id_ed25519 admin@203.0.113.50
```

**Sortie attendue (première connexion) :**

```bash
The authenticity of host '203.0.113.50 (203.0.113.50)' can't be established.
ED25519 key fingerprint is SHA256:aBc1De2fG3hI4jK5lM6nO7pQ8rS9tU0vW1xY2z3aB4c.
This key is not known to any other hosts.
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

**Taper `yes` pour accepter et enregistrer la clé du serveur :**

```bash
yes
```

**Entrée de la passphrase :**

```bash
Enter passphrase for key '/home/admin/.ssh/id_ed25519':
••••••••••••
```

**Succès ! Vous êtes connecté :**

```bash
admin@serveur:~$
# Vous pouvez maintenant exécuter des commandes sur le serveur
```

### 🔍 Diagnostiquer les problèmes avec -v (Verbose)

Si la connexion échoue, activez le mode verbose :

```bash
# Connexion avec sortie détaillée
ssh -v -i ~/.ssh/id_ed25519 admin@203.0.113.50

# Sortie détaillée montrant chaque étape :
# OpenSSH_8.0p1 Debian-6, OpenSSL 1.1.1g  21 Apr 2020
# debug1: Authentications that can continue: publickey,password
# debug1: Trying private key: /home/admin/.ssh/id_ed25519
# debug1: Offering public key: /home/admin/.ssh/id_ed25519 ED25519 SHA256:...
# debug1: Server accepts key: /home/admin/.ssh/id_ed25519 ED25519 SHA256:...
# Authenticated with partial success.
# Authenticated to 203.0.113.50 ([203.0.113.50]:22).
```

### ✅ Vérifications du côté serveur

**Sur le SERVEUR, vérifier le fichier `authorized_keys` :**

```bash
# Afficher le contenu (admin doit être connecté)
cat ~/.ssh/authorized_keys

# Vérifier les permissions
ls -la ~/.ssh/authorized_keys
# -rw------- 1 admin admin 411 Nov 16 22:10 authorized_keys
```

**Vérifier les logs du serveur :**

```bash
# Voir les tentatives SSH
sudo tail -20 /var/log/auth.log

# Exemple de log réussi :
# Nov 16 22:17:00 serveur sshd[1234]: Accepted publickey for admin from 192.168.1.100 port 50123 ssh2: ED25519 SHA256:...
```

---

## 10. Étape 6 : Sécurisation avancée {#securisation-avancée}

### 🚫 Désactiver l'authentification par mot de passe

**⚠️ IMPORTANT : Ne faites cette étape QUE si vous avez confirmé que la clé fonctionne !**

```bash
# Sur le SERVEUR, éditer la configuration
sudo nano /etc/ssh/sshd_config

# Trouver la ligne PasswordAuthentication et la modifier
PasswordAuthentication no

# Sauvegarder et redémarrer
sudo systemctl restart ssh
```

**Vérifier :**

```bash
# Sur le CLIENT, cette commande doit échouer :
ssh admin@203.0.113.50
# Permission denied (publickey).
```

### 🔒 Protection supplémentaire de la clé privée locale

```bash
# Sur le CLIENT, ajouter une passphrase supplémentaire
ssh-keygen -p -i ~/.ssh/id_ed25519 -o

# Ou changer le format de chiffrement
ssh-keygen -p -i ~/.ssh/id_ed25519 -Z aes256-ctr -N "nouvellePassphrase"
```

### 🔐 Utiliser un agent SSH (ssh-agent)

**Pour éviter de retaper la passphrase à chaque connexion :**

```bash
# Sur le CLIENT, démarrer l'agent SSH
eval $(ssh-agent)

# Ajouter la clé à l'agent
ssh-add ~/.ssh/id_ed25519

# Vous serez demandé de taper la passphrase une fois
Enter passphrase for /home/admin/.ssh/id_ed25519: ••••••••••••
# Identity added: /home/admin/.ssh/id_ed25519 (admin@client)

# À présent, les connexions SSH ne demanderont plus la passphrase
ssh admin@203.0.113.50
# ✅ Connecté sans demande de passphrase !
```

### 📋 Configuration SSH client avancée (~/.ssh/config)

**Pour simplifier les connexions avec plusieurs serveurs :**

```bash
# Sur le CLIENT, créer/éditer ~/.ssh/config
nano ~/.ssh/config

# Ajouter :
Host serveur1
    HostName 203.0.113.50
    User admin
    IdentityFile ~/.ssh/id_ed25519
    Port 22
    AddKeysToAgent yes
    IdentitiesOnly yes

Host serveur2
    HostName 203.0.113.51
    User root
    IdentityFile ~/.ssh/id_rsa_legacy
    Port 2222

# Définir les permissions
chmod 600 ~/.ssh/config

# Maintenant, se connecter est simple :
ssh serveur1
# Au lieu de : ssh -i ~/.ssh/id_ed25519 admin@203.0.113.50
```

---

## 11. Dépannage et solutions {#depannage}

### ❌ Erreur : "Permission denied (publickey)"

**Causes possibles et solutions :**

#### Cause 1 : Clé publique non copié ou mal formatée

```bash
# Sur le SERVEUR, vérifier le contenu du authorized_keys
cat ~/.ssh/authorized_keys

# ✅ Correct : une clé par ligne, commençant par ssh-ed25519 ou ssh-rsa
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... admin@client

# ❌ Incorrect : clé cassée ou vide
# Line trop longue ou coupée à la mauvaise place
```

**Solution :**

```bash
# Supprimer authorized_keys et recréer
rm ~/.ssh/authorized_keys

# Utiliser ssh-copy-id depuis le client
ssh-copy-id -i ~/.ssh/id_ed25519.pub admin@203.0.113.50
```

#### Cause 2 : Permissions incorrectes

```bash
# Sur le SERVEUR, vérifier les permissions
ls -la ~/.ssh/
# ✅ Correct :
# drwx------ 2 admin admin  .ssh
# -rw------- 1 admin admin  authorized_keys

# ❌ Incorrect :
# drwxr-xr-x 2 admin admin  .ssh  ← Trop permissif !
# -rw-r--r-- 1 admin admin  authorized_keys  ← Lisible par tous !

# Corriger :
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

#### Cause 3 : Mauvais utilisateur

```bash
# Sur le CLIENT, vérifier que vous utilisez le bon utilisateur
# ❌ Faux :
ssh -i ~/.ssh/id_ed25519 root@203.0.113.50
# ✅ Correct :
ssh -i ~/.ssh/id_ed25519 admin@203.0.113.50
```

### ❌ Erreur : "Could not resolve hostname"

```bash
# Problème : adresse IP ou nom d'hôte incorrect
# ❌ Faux :
ssh admin@203.0.113.500  # IP invalide

# ✅ Correct :
ssh admin@203.0.113.50   # IP valide
```

### ❌ Erreur : "Connection refused"

```bash
# Problème : SSH n'écoute pas sur le port ou pare-feu
# Solution 1 : Vérifier que SSH est actif sur le serveur
sudo systemctl status ssh

# Solution 2 : Vérifier que le port écoute
sudo ss -tlnp | grep sshd
# tcp    0    0 0.0.0.0:22    0.0.0.0:*    LISTEN    1234/sshd

# Solution 3 : Vérifier le pare-feu Debian
sudo ufw status
# Autoriser SSH si nécessaire :
sudo ufw allow 22
```

### ❌ Erreur : "Authentications that can continue: password"

```bash
# Problème : PubkeyAuthentication est désactivé dans sshd_config
# Solution :
sudo nano /etc/ssh/sshd_config
# S'assurer que : PubkeyAuthentication yes
sudo systemctl restart ssh
```

### 🔧 Mode de diagnostic complet

```bash
# Sur le CLIENT, utiliser -vvv pour encore plus de détails
ssh -vvv -i ~/.ssh/id_ed25519 admin@203.0.113.50

# Cette sortie montrera chaque étape de négociation, utile pour les experts
```

---

## 12. Bonnes pratiques et gestion des clés {#bonnes-pratiques}

### 🛡️ Règles de sécurité essentielles

1. **Ne jamais partager la clé privée**
   ```bash
   # ❌ Ne JAMAIS faire cela :
   scp ~/.ssh/id_ed25519 ami@autre-machine.com
   cat ~/.ssh/id_ed25519 | mail ami@example.com
   
   # ✅ À la place, générer une clé pour chaque machine
   ```

2. **Protéger la clé privée avec une passphrase**
   ```bash
   # ❌ Pas de passphrase = clé accessible en cas de vol
   ssh-keygen -t ed25519 -C "user" -N ""
   
   # ✅ Avec passphrase = clé protégée
   ssh-keygen -t ed25519 -C "user" -a 100
   ```

3. **Utiliser des clés différentes par contexte**
   ```bash
   # Pour travail :
   ssh-keygen -f ~/.ssh/id_travail_ed25519
   
   # Pour personnel :
   ssh-keygen -f ~/.ssh/id_personnel_ed25519
   
   # Pour serveurs sensibles :
   ssh-keygen -f ~/.ssh/id_critique_ed25519
   ```

4. **Maintenir un inventaire des clés**
   ```bash
   # Sur le serveur, conserver un inventaire des utilisateurs
   cat ~/.ssh/authorized_keys
   
   # Exemple de commentaire utile (4e champ) :
   ssh-ed25519 AAAAC3... admin@workstation (2025-01-15, travail)
   ssh-ed25519 AAAAC3... admin@laptop (2025-02-20, perso)
   ```

### 🔄 Gestion des accès multiples

#### Ajouter un nouvel utilisateur

```bash
# Créer le nouvel utilisateur
sudo useradd -m -s /bin/bash nouveau_user
sudo passwd nouveau_user

# L'utilisateur génère sa propre clé
su - nouveau_user
ssh-keygen -t ed25519 -a 100

# L'utilisateur envoie sa clé publique (id_ed25519.pub) à l'admin

# L'admin ajoute la clé au fichier authorized_keys
echo "contenu_cle_publique_nouvel_utilisateur" >> ~/.ssh/authorized_keys

# Tester la connexion
ssh nouveau_user@203.0.113.50
```

#### Révoquer l'accès d'un utilisateur

```bash
# Supprimer la clé du fichier authorized_keys
nano ~/.ssh/authorized_keys
# Supprimer la ligne contenant la clé à révoquer

# Ou utiliser grep pour la supprimer automatiquement
grep -v "ancien_utilisateur" ~/.ssh/authorized_keys > authorized_keys.tmp
mv authorized_keys.tmp ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 🔐 Rotation des clés

**Effectuer une rotation tous les 6-12 mois :**

```bash
# 1. Générer une nouvelle clé
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_new -a 100

# 2. Copier la nouvelle clé publique sur les serveurs
ssh-copy-id -i ~/.ssh/id_ed25519_new.pub admin@serveur

# 3. Tester la nouvelle clé
ssh -i ~/.ssh/id_ed25519_new admin@serveur

# 4. Supprimer l'ancienne clé des serveurs et des fichiers locaux
# (après confirmation que la nouvelle fonctionne)

# 5. Archiver l'ancienne clé (si besoin historique)
mv ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.archive.2024
```

### 📊 Audit des clés installées

```bash
# Sur chaque serveur, auditer les clés
wc -l ~/.ssh/authorized_keys  # Nombre de clés

# Afficher toutes les clés avec informations
cat ~/.ssh/authorized_keys | while read line; do
  echo "Clé : ${line: -30}"
  echo "---"
done
```

---

## 13. Sources officielles et références {#references}

### 📚 Documentation officielle

1. **Debian Wiki - SSH**
   - URL : https://wiki.debian.org/SSH
   - Contenu : Installation, configuration, dépannage pour Debian

2. **OpenSSH Man Pages**
   - ssh-keygen : https://man.openbsd.org/ssh-keygen
   - sshd_config : https://man.openbsd.org/sshd_config
   - ssh_config : https://man.openbsd.org/ssh_config

3. **ANSSI - Recommandations OpenSSH**
   - Document : NT OpenSSH (Note Technique)
   - URL : https://cyber.gouv.fr
   - Contenus : Recommandations de sécurité officielles françaises

### 🔐 Bonnes pratiques supplémentaires

- NIST SP 800-121 (Guide de sécurité pour les développeurs)
- RFC 4253 (SSH Transport Layer Protocol)
- RFC 4419 (SSH Diffie-Hellman Group Exchange Method)

### 🛠️ Outils complémentaires

- **ssh-audit** : Audit de configuration SSH
- **fail2ban** : Protection contre les attaques par force brute
- **SELinux/AppArmor** : Confinement du service SSH

---

## 📌 Résumé des fichiers modifiés

| Emplacement | Rôle | Permissions |
|-------------|------|-----------|
| `~/.ssh/id_ed25519` (CLIENT) | Clé privée | `600` |
| `~/.ssh/id_ed25519.pub` (CLIENT) | Clé publique | `644` |
| `~/.ssh/authorized_keys` (SERVEUR) | Clés autorisées | `600` |
| `~/.ssh` (SERVEUR) | Répertoire utilisateur | `700` |
| `/etc/ssh/sshd_config` (SERVEUR) | Configuration serveur | `644` |

---

## 🎓 Conclusion

Vous avez maintenant une authentification SSH par clé entièrement fonctionnelle et sécurisée sur Debian. Cette méthode offre :

✅ Accès sécurisé sans mot de passe  
✅ Automatisation d'exploitation simplifiée  
✅ Conformité avec les recommandations ANSSI  
✅ Base solide pour scaling infrastructure  

**Prochaines étapes :**
- Implémenter MFA (Multi-Factor Authentication) pour encore plus de sécurité
- Configurer fail2ban pour les attaques par force brute
- Automatiser les déploiements avec Ansible/SSH
- Mettre en place une PKI (Public Key Infrastructure) d'entreprise

---

**Document généré le : 16 novembre 2025**  
**Basé sur :** Debian 10+, OpenSSH 8.0+, Recommandations ANSSI  
**Auteur :** Guide complet académique - Tutoriel SSH Debian