# Guide Complet : Installation Automatisée de Fail2Ban avec Recommandations ANSSI

## 📋 Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Prérequis](#prérequis)
3. [Installation](#installation)
4. [Utilisation du Script](#utilisation-du-script)
5. [Vérification et Tests](#vérification-et-tests)
6. [Configuration Avancée](#configuration-avancée)
7. [Troubleshooting](#troubleshooting)
8. [Recommandations ANSSI Appliquées](#recommandations-anssi-appliquées)

---

## Vue d'ensemble

Ce script **fail2ban-install.sh** installe et configure automatiquement :

- ✅ **Fail2Ban** : protection contre les attaques par brute-force
- ✅ **SSH sécurisé** : port changé de 22 à 2545, authentification par clé uniquement
- ✅ **Configuration ANSSI** : cryptographie forte, algorithmes recommandés
- ✅ **Dépendances** : iptables, python3, systemd
- ✅ **Jails configurées** : SSH, récidivistes

### Ce qu'il y a à l'intérieur

Le script est organisé en **9 sections principales** :

| Section | Description |
|---------|-------------|
| 1 | Initialisation et vérifications préalables |
| 2 | Vérification des permissions et du système |
| 3 | Mise à jour du système |
| 4 | Installation des dépendances |
| 5 | Modification de la configuration SSH |
| 6 | Installation et configuration de fail2ban |
| 7 | Activation et démarrage des services |
| 8 | Vérifications et tests |
| 9 | Information finale et récapitulatif |

---

## Prérequis

### Avant d'exécuter le script

1. **Système d'exploitation** : Debian 10+ ou Ubuntu 18.04+
2. **Accès root** : Le script doit être exécuté en tant que root (ou via sudo)
3. **Connexion réseau** : Nécessaire pour télécharger les paquets
4. **Espace disque** : ~50 MB minimum

### Vérifier votre système

```bash
# Afficher la version du système
cat /etc/os-release

# Vérifier l'accès root
whoami  # Doit afficher "root"

# Vérifier la connexion réseau
ping -c 1 google.com
```

---

## Installation

### Étape 1 : Télécharger le script

```bash
# Option 1 : Créer le fichier directement
sudo cat > /opt/scripts/fail2ban-install.sh << 'EOF'
# Copiez-collez le contenu du script ici
EOF

# Option 2 : Télécharger depuis une source
sudo wget -O /opt/scripts/fail2ban-install.sh https://votre-serveur/fail2ban-install.sh
```

### Étape 2 : Rendre le script exécutable

```bash
# Donner les permissions d'exécution
chmod +x /opt/scripts/fail2ban-install.sh

# Vérifier les permissions
ls -la /opt/scripts/fail2ban-install.sh
# Doit afficher : -rwxr-xr-x
```

### Étape 3 : Créer une sauvegarde avant d'exécuter

```bash
# Très important ! Faire une sauvegarde de SSH avant
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup-avant-script
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.backup-avant-script
```

---

## Utilisation du Script

### Exécution basique

```bash
# Exécuter le script
sudo bash /opt/scripts/fail2ban-install.sh

# Avec mode debug (affiche chaque commande)
sudo bash -x /opt/scripts/fail2ban-install.sh
```

### Que fait le script ?

Le script exécute **automatiquement** les étapes suivantes :

#### 1️⃣ Mise à jour du système
```bash
apt-get update -y
apt-get upgrade -y
```

#### 2️⃣ Installation des dépendances
```bash
apt-get install -y fail2ban iptables python3 systemd
```

#### 3️⃣ Configuration de SSH
- Change le port de 22 à 2545
- Désactive l'authentification par mot de passe
- Force l'utilisation de clés publiques
- Configure les algorithmes ANSSI

#### 4️⃣ Installation de fail2ban
- Crée `/etc/fail2ban/jail.local` avec les paramètres par défaut
- Crée `/etc/fail2ban/jail.d/sshd.local` pour surveiller SSH
- Crée `/etc/fail2ban/jail.d/recidive.local` pour les récidivistes

#### 5️⃣ Redémarrage des services
- SSH redémarre sur le port 2545
- Fail2ban démarre et est configuré pour l'auto-start

---

## Vérification et Tests

### Après l'exécution du script

#### ✓ Vérifier que SSH fonctionne sur le nouveau port

```bash
# Depuis votre machine locale
ssh -p 2545 user@votre-serveur

# Si vous êtes déjà sur le serveur
systemctl status ssh
sudo netstat -tlnp | grep 2545
```

#### ✓ Vérifier que fail2ban est actif

```bash
# Status global
sudo fail2ban-client status

# Status de la jail SSH
sudo fail2ban-client status sshd

# Affichage attendu :
# Status for the jail: sshd
# |- Filter      : currently failed: 0
# |- Actions     : currently banned: 0
```

#### ✓ Vérifier les règles iptables

```bash
# Voir les règles créées par fail2ban
sudo iptables -S | grep f2b

# Voir les IPs bannies
sudo iptables -L f2b-sshd -n
```

#### ✓ Vérifier les fichiers de configuration

```bash
# Vérifier la syntaxe SSH
sudo sshd -t
# Doit retourner sans erreur

# Vérifier la syntaxe fail2ban
sudo fail2ban-client -t
# Doit retourner : Configuration appears to be OK.
```

### Test fonctionnel de fail2ban

```bash
# Sur votre machine locale, tenter plusieurs connexions échouées
for i in {1..5}; do
  ssh -p 2545 -o StrictHostKeyChecking=no user@votre-serveur "wrong"
done

# Attendre 10 secondes
sleep 10

# Sur le serveur, vérifier les IPs bannies
sudo fail2ban-client status sshd

# Vous devriez voir votre IP dans "Banned IP list"
```

---

## Configuration Avancée

### Modifier le port SSH

Le script utilise le port **2545**. Pour le changer :

```bash
# Éditer le script
sudo nano fail2ban-install.sh

# Trouver la ligne :
# PORT_NOUVEAU="2545"

# Changer à votre port préféré (ex: 2022)
# PORT_NOUVEAU="2022"

# Re-exécuter le script
sudo bash fail2ban-install.sh
```

### Modifier les paramètres de fail2ban

Après l'installation, éditer les fichiers de configuration :

```bash
# Configuration générale
sudo nano /etc/fail2ban/jail.local

# Configuration SSH spécifique
sudo nano /etc/fail2ban/jail.d/sshd.local

# Configuration des récidivistes
sudo nano /etc/fail2ban/jail.d/recidive.local
```

#### Paramètres importants

| Paramètre | Valeur Actuelle | Signification |
|-----------|-----------------|---------------|
| `bantime` | 3600 | Durée du ban (secondes) : 3600 = 1 heure |
| `findtime` | 600 | Fenêtre de temps (10 minutes) |
| `maxretry` | 3 | Nombre de tentatives avant ban |
| `ignoreip` | 127.0.0.1/8 ::1 | IPs à ignorer |

#### Exemples de modification

```bash
# Augmenter la durée du ban à 24 heures (86400 sec)
sudo sed -i 's/bantime = 3600/bantime = 86400/' /etc/fail2ban/jail.d/sshd.local

# Augmenter les tentatives à 5 pour moins de faux positifs
sudo sed -i 's/maxretry = 3/maxretry = 5/' /etc/fail2ban/jail.d/sshd.local

# Ajouter votre IP à la whitelist (remplacer 203.0.113.0)
sudo sed -i 's/ignoreip = 127.0.0.1\/8 ::1/ignoreip = 127.0.0.1\/8 ::1 203.0.113.0/' /etc/fail2ban/jail.local

# Appliquer les changements
sudo systemctl restart fail2ban
```

### Ajouter d'autres jails

Vous pouvez ajouter d'autres jails (Apache, Nginx, fail2ban lui-même, etc.)

```bash
# Créer une jail pour Apache
sudo nano /etc/fail2ban/jail.d/apache.local
```

```ini
[apache-auth]
enabled  = true
port     = http,https
filter   = apache-auth
logpath  = /var/log/apache2/error.log
maxretry = 5

[apache-limit-request]
enabled  = true
port     = http,https
filter   = apache-limit-request
logpath  = /var/log/apache2/access.log
maxretry = 5
bantime  = 600
findtime = 600
```

### Activer les notifications par email

```bash
# Éditer jail.local
sudo nano /etc/fail2ban/jail.local

# Décommenter et configurer :
# destemail = admin@example.com
# sendername = Fail2Ban Server

# Ensuite modifier la section ACTION pour activer les emails
# action = %(action_mw)s
```

---

## Troubleshooting

### ❌ Problème : "Permission denied (publickey)"

**Cause** : Votre clé publique n'est pas dans `~/.ssh/authorized_keys`

```bash
# Sur la machine locale, copier la clé publique
ssh-copy-id -p 2545 user@votre-serveur

# Ou manuellement
# 1. Afficher votre clé publique locale
cat ~/.ssh/id_rsa.pub

# 2. Sur le serveur, ajouter la clé
echo "YOUR_PUBLIC_KEY" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### ❌ Problème : "Connection refused" ou "timeout"

**Cause** : SSH ne démarre pas sur le nouveau port ou fail2ban vous bannit

```bash
# Vérifier que SSH écoute vraiment sur le port 2545
sudo netstat -tlnp | grep 2545

# Si vide, SSH n'est pas en écoute
sudo systemctl status ssh

# Vérifier la syntaxe SSH
sudo sshd -t

# Voir les erreurs SSH
sudo journalctl -u ssh -n 20
```

### ❌ Problème : "Je me suis banni moi-même"

**Solution** : Accéder au serveur via une autre méthode et débannir

```bash
# Via la console physique ou un accès de secours

# Afficher les IPs bannies
sudo fail2ban-client status sshd

# Débannir une IP
sudo fail2ban-client set sshd unbanip 203.0.113.50

# Ou désactiver temporairement fail2ban
sudo systemctl stop fail2ban
```

### ❌ Problème : "Script fails with permission error"

**Cause** : Vous n'exécutez pas en root

```bash
# Vérifier que vous êtes en root
whoami  # Doit afficher "root"

# Sinon, utiliser sudo
sudo bash fail2ban-install.sh

# Ou devenir root
sudo su -
bash fail2ban-install.sh
```

### ❌ Problème : "fail2ban-client -t" returns error

**Cause** : Erreur de syntaxe dans les fichiers de configuration

```bash
# Vérifier les fichiers de config
sudo cat /etc/fail2ban/jail.local | head -50

# Chercher les erreurs (pas de doublons, syntaxe correcte)
sudo fail2ban-client -d

# Restaurer depuis une sauvegarde
sudo cp /etc/fail2ban/jail.local.backup-* /etc/fail2ban/jail.local
```

---

## Recommandations ANSSI Appliquées

### 🔐 Configuration SSH selon ANSSI

Le script applique les recommandations du guide [ANSSI OpenSSH](https://cyber.gouv.fr) :

#### Authentification
- ✅ Authentification par clé publique **obligatoire**
- ✅ Authentification par mot de passe **désactivée**
- ✅ Root ne peut **pas** se connecter avec mot de passe
- ✅ Clés vides **interdites**

#### Cryptographie (ANSSI RGS)
- ✅ **Ciphers** : AES-256-CTR, AES-192-CTR, AES-128-CTR (pas de CBC)
- ✅ **MACs** : HMAC-SHA512-ETM, HMAC-SHA256-ETM
- ✅ **KexAlgorithms** : Curve25519, ECDH

#### Limite des attaques
- ✅ **MaxAuthTries** : limité à 3 tentatives
- ✅ **LoginGraceTime** : 30 secondes
- ✅ **Port** : changé à 2545 (sécurité par l'obscurité)

### 🛡️ Configuration Fail2Ban selon ANSSI

- ✅ **Backend** : systemd (plus efficace que fichiers)
- ✅ **Jail SSH** : 3 tentatives → 1h ban
- ✅ **Jail Récidivistes** : 2 bans en 24h → 7 jours ban
- ✅ **Ignorer localhost** : éviter les faux positifs

### 📊 Paramètres configurés

```bash
# Fail2Ban defaults
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
bantime = 3600           # 1 heure
findtime = 600           # 10 minutes
maxretry = 3             # 3 tentatives

# SSH jail
[sshd]
enabled = true
port = 2545
filter = sshd
maxretry = 3
bantime = 3600
mode = normal

# Récidivistes
[recidive]
enabled = true
maxretry = 2
findtime = 86400         # 24 heures
bantime = 604800         # 7 jours
```

---

## Commandes Utiles Post-Installation

```bash
# Voir le status de fail2ban
sudo fail2ban-client status

# Voir le status d'une jail
sudo fail2ban-client status sshd

# Voir les IPs bannies
sudo fail2ban-client status sshd | grep "Banned IP"

# Débannir une IP
sudo fail2ban-client set sshd unbanip 203.0.113.50

# Voir les logs fail2ban
sudo tail -f /var/log/fail2ban.log

# Voir les logs SSH
sudo tail -f /var/log/auth.log

# Redémarrer fail2ban
sudo systemctl restart fail2ban

# Arrêter fail2ban
sudo systemctl stop fail2ban

# Vérifier la syntaxe SSH
sudo sshd -t

# Vérifier les IPs actives sur le port 2545
sudo netstat -tlnp | grep 2545

# Voir les règles iptables de fail2ban
sudo iptables -S | grep f2b
```

---

## Support et Documentation

- **ANSSI** : https://cyber.gouv.fr
- **Fail2Ban** : https://www.fail2ban.org/
- **OpenSSH** : https://www.openssh.com/
- **Debian** : https://www.debian.org/

