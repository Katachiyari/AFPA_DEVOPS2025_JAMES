# Let's Encrypt + Certbot - Certificats SSL/TLS Sécurisés et Automatisés
## Guide Complet et Rigoureux

---

## 📋 Table des Matières

1. [Fondamentaux de la Cryptographie TLS](#fondamentaux)
2. [Let's Encrypt et Certbot](#letsencrypt)
3. [Recommandations ANSSI](#anssi)
4. [Architecture et Protocole](#architecture)
5. [Installation et Prérequis](#installation)
6. [Configuration de Base](#configuration)
7. [Validation ACME](#validation)
8. [Renouvellement Automatisé](#renouvellement)
9. [Sécurisation Avancée](#securite)
10. [Performance et Optimisation](#performance)
11. [Monitoring et Audit](#monitoring)
12. [Dépannage et Troubleshooting](#debogage)

---

## 🔐 Fondamentaux de la Cryptographie TLS {#fondamentaux}

### Pourquoi HTTPS/TLS ?

Le protocole TLS (Transport Layer Security) offre les propriétés essentielles :

- **Confidentialité** : Chiffrement du trafic (impossible à lire en transit)
- **Intégrité** : Vérification que les données n'ont pas été modifiées
- **Authentification** : Vérification que le serveur est bien celui qu'il prétend être
- **Protection contre MITM** : Impossible d'intercepter/modifier sans détection
- **Compliance légale** : Obligatoire pour RGPD, PCI-DSS, conformité

### Chaîne de Confiance X.509

```
┌─────────────────────────────────────────────────────┐
│            Racine CA (Root CA)                       │
│   Autorité de Certification racine de confiance     │
│   Pré-installée dans navigateurs/OS                 │
├─────────────────────────────────────────────────────┤
│              ↓ Signe cryptographiquement             │
├─────────────────────────────────────────────────────┤
│      CA Intermédiaire (Intermediate CA)             │
│   Permet délégation de signature                    │
│   Augmente flexibilité et sécurité                  │
├─────────────────────────────────────────────────────┤
│              ↓ Signe cryptographiquement             │
├─────────────────────────────────────────────────────┤
│        Certificat Serveur (End-Entity Cert)         │
│   Certificat HTTPS pour votre domaine               │
│   Valide pour : exemple.com, www.exemple.com, etc.  │
│   Expiration : 90 jours (Let's Encrypt standard)    │
└─────────────────────────────────────────────────────┘
```

### Types de Certificats

| Type | Validation | Domaines | Coût | Sécurité |
|------|-----------|----------|------|----------|
| **DV** (Domain Validation) | Propriétaire domaine | 1 ou ∞ (wildcard) | ✓ Gratuit (Let's Encrypt) | ✓ Excellente |
| **OV** (Organization Validation) | Identité org | 1 ou ∞ | Payant | ✓ Excellente |
| **EV** (Extended Validation) | Audit complet | 1 | Payant | ✓ Excellente |
| **Self-Signed** | Aucune | Tous | Gratuit | ✗ Non fiable |

**Recommandation ANSSI** : Certificats DV Let's Encrypt = suffisant et gratuit

---

## 💡 Let's Encrypt et Certbot {#letsencrypt}

### Qu'est-ce que Let's Encrypt ?

**Let's Encrypt** est une autorité de certification gratuite, automatisée et ouverte :

- **Gratuit** : Aucun coût contrairement aux CA commerciales
- **Automatisé** : Protocole ACME (Automated Certificate Management Environment)
- **À renouvellement court** : 90 jours (force renouvellement régulier = plus de sécurité)
- **Largement reconnu** : Accepté par tous les navigateurs modernes
- **Open Source** : Code disponible sur GitHub (audit de sécurité possible)

### Qu'est-ce que Certbot ?

**Certbot** est un client ACME développé par l'EFF (Electronic Frontier Foundation) :

- **Entièrement gratuit** : Aucune dépendance commerciale
- **Cross-plateforme** : Linux, macOS, Windows (WSL)
- **Automatisation complète** : Installation, validation, renouvellement automatique
- **Support multiples serveurs web** : Nginx, Apache, Standalone, etc.
- **Sécurité** : Authentification ACME via Let's Encrypt
- **Respect ANSSI** : Chiffrement fort, courtes durées, audit possible

---

## 🛡️ Recommandations ANSSI {#anssi}

### Source Officielle ANSSI

**Document** : *Guide d'Hygiène Informatique* (édition 2023) et *Recommandations pour les Certificats Numériques*

**Lien** : https://cyber.gouv.fr/ (rubrique publications)

### Recommandations Clés d'ANSSI pour TLS/Let's Encrypt

#### 1️⃣ Version TLS Obligatoire

```
✓ OBLIGATOIRE : TLS 1.2 minimum
✓ RECOMMANDÉ : TLS 1.3 (plus sécurisé et rapide)
✗ REFUSER : SSL 3.0, TLS 1.0, TLS 1.1

Raison ANSSI :
- TLS 1.0-1.1 = vulnérabilités connues (BEAST, POODLE)
- TLS 1.2 = standard de sécurité depuis 2008
- TLS 1.3 = dernier standard (2018), plus rapide et robuste
```

**Vérification** :
```bash
# Tester la version TLS d'un site
openssl s_client -connect exemple.com:443 -tls1_2
openssl s_client -connect exemple.com:443 -tls1_3
```

#### 2️⃣ Suites de Chiffrement (Cipher Suites)

```
✓ OBLIGATOIRE (TLS 1.3) :
  TLS_AES_256_GCM_SHA384
  TLS_CHACHA20_POLY1305_SHA256
  TLS_AES_128_GCM_SHA256

✓ ACCEPTABLE (TLS 1.2) :
  ECDHE-ECDSA-AES256-GCM-SHA384
  ECDHE-RSA-AES256-GCM-SHA384
  ECDHE-ECDSA-CHACHA20-POLY1305
  ECDHE-RSA-CHACHA20-POLY1305

✗ REFUSER (OBSOLÈTE) :
  3DES-CBC, RC4, MD5, SHA1, DH < 2048
```

#### 3️⃣ Certificats et Chaîne ANSSI

```
✓ OBLIGATOIRE : Certificat signé par CA reconnue
✓ OBLIGATOIRE : Certificat intermédiaire inclus (fullchain)
✓ OBLIGATOIRE : Chaîne complète jusqu'à racine

Fichiers Certbot :
  /etc/letsencrypt/live/exemple.com/fullchain.pem  ← Avec chaîne
  /etc/letsencrypt/live/exemple.com/cert.pem       ← Sans chaîne
  /etc/letsencrypt/live/exemple.com/privkey.pem    ← Clé privée
  /etc/letsencrypt/live/exemple.com/chain.pem      ← Intermédiaires
```

**Configuration correcte** :
```nginx
# Nginx - ANSSI compliant
server {
    ssl_certificate /etc/letsencrypt/live/exemple.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/exemple.com/privkey.pem;
    
    # TLS 1.3 et 1.2
    ssl_protocols TLSv1.3 TLSv1.2;
    
    # Suites de chiffrement ANSSI
    ssl_ciphers 'TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
}
```

#### 4️⃣ Durée de Validité

```
✓ ACCEPTABLE : 90 jours (standard Let's Encrypt)
✓ RECOMMANDÉ : Renouvellement chaque 60 jours
✗ DÉCONSEILLÉ : > 1 an (trop long, révocation impossible)

Raison ANSSI :
- Courtes durées = force renouvellement régulier
- Renouvellement = force révision des processus
- Revocation rapid possible si clé compromise
```

#### 5️⃣ Clé Privée ANSSI

```
✓ OBLIGATOIRE : Clé RSA 2048 bits minimum
✓ RECOMMANDÉ : ECDSA P-256 ou P-384
✓ OBLIGATOIRE : Permissions strictes (600)
✓ OBLIGATOIRE : Propriétaire = root ou utilisateur service

Permissions correctes :
  /etc/letsencrypt/live/*/privkey.pem   → -rw------- (600)
  /etc/letsencrypt/live/*/fullchain.pem → -rw-r--r-- (644)
```

#### 6️⃣ Renouvellement Automatisé

```
✓ OBLIGATOIRE : Renouvellement automatisé via cron/systemd
✓ OBLIGATOIRE : Monitoring de l'expiration
✓ OBLIGATOIRE : Alertes avant expiration (30 jours)

Raison ANSSI :
- Renouvellement manuel = risque d'oubli
- Expiration certificat = perte confiance/service
- Automatisation = processus fiable et auditables
```

#### 7️⃣ HSTS (HTTP Strict Transport Security)

```
✓ OBLIGATOIRE : Activer HSTS
✓ Durée minimale : 31536000 secondes (1 an)
✓ Inclure les sous-domaines : includeSubDomains
✓ Précharge officiel HSTS : preload

Header HTTP :
  Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

**Raison ANSSI** : Force HTTPS même si utilisateur tape http://

#### 8️⃣ Validation ACME ANSSI

```
✓ OBLIGATOIRE : Validation ACME robuste (HTTP-01 ou DNS-01)
✓ RECOMMANDÉ : DNS-01 pour wildcard et multi-domaines
✓ ACCEPTABLE : HTTP-01 pour domaine unique public

Validation methods :
  HTTP-01   → Requête HTTP sur port 80 → fichier .well-known
  DNS-01    → TXT record DNS → preuve modification DNS
  ALPN-01   → Validation via ALPN TLS → plus sûr
```

---

## 🏗️ Architecture et Protocole {#architecture}

### Protocole ACME (Automated Certificate Management Environment)

```
Étape 1 : Découverte
  Client Certbot → Let's Encrypt : "Quelles sont vos capacités ?"
  ← Réponse : endpoints disponibles, algorithms acceptés

Étape 2 : Compte
  Client → LE : Créer/charger compte ACME
  ← Compte créé avec clé de signature

Étape 3 : Demande (Order)
  Client → LE : "Je veux certificat pour exemple.com"
  ← Réponse : authorization required

Étape 4 : Défi (Challenge)
  LE → Client : "Prouve que tu es owner de exemple.com"
         Choix :
         - HTTP-01 : crée fichier /.well-known/acme-challenge/TOKEN
         - DNS-01 : crée TXT record _acme-challenge.exemple.com = TOKEN

Étape 5 : Validation
  Client résout le défi (crée fichier HTTP ou TXT DNS)
  Client répond au défi
  LE valide (teste HTTP ou query DNS)

Étape 6 : Certificat
  Client → LE : Finalise la commande
  LE signe le certificat
  ← Certificat délivré avec chaîne intermédiaire

Étape 7 : Renouvellement
  30 jours avant expiration, répéter étapes 1-6
```

### Interactions Certbot-Let's Encrypt

```
┌──────────────────────────┐
│   Certbot (Client)       │
├──────────────────────────┤
│ /etc/letsencrypt/        │
│ ├─ accounts/             │ ← Clés de compte
│ ├─ live/                 │ ← Symlinks certificats courants
│ ├─ archive/              │ ← Tous les certificats historiques
│ └─ renewal/              │ ← Configuration renouvellement
└──────────────────────────┘
         ↓ ACME protocol (HTTPS)
┌──────────────────────────┐
│ Let's Encrypt API        │
├──────────────────────────┤
│ https://acme-v02.api.    │
│ letsencrypt.org/         │
│                          │
│ Root CA : ISRG Root X1   │
│ (2048-bit RSA)           │
│                          │
│ Intermediate CAs :       │
│ - R3 (utilisé)           │
│ - R4, R5, R6 (backup)    │
└──────────────────────────┘
```

---

## 📦 Installation et Prérequis {#installation}

### Vérification Prérequis

#### Serveur Web

```bash
# 1. Vérifier le serveur web
sudo systemctl status nginx
# ou
sudo systemctl status apache2

# 2. Vérifier que port 80/443 écoutent
sudo ss -tlnp | grep -E ":80|:443"
# Résultat attendu : LISTEN sur les deux ports

# 3. Vérifier le domaine
ping exemple.com
# Résultat : résolution DNS OK

# 4. Tester l'accès HTTP
curl -v http://exemple.com
# Résultat : 200 OK (ou redirection HTTP)

# 5. Vérifier les permissions /var/www/
ls -la /var/www/html/
# Doit être lisible par nginx/apache
```

#### Système

```bash
# 1. Vérifier la version Python
python3 --version
# Résultat : Python 3.6+

# 2. Vérifier les modules Python
python3 -m pip list | grep -i certbot

# 3. Vérifier les ports disponibles
sudo netstat -tlnp | grep -E ":80|:443"

# 4. Vérifier l'horloge système
timedatectl status
# Résultat : clock synchronized = yes
# (Important pour validation ACME)

# 5. Vérifier l'accès DNS
nslookup letsencrypt.org
dig letsencrypt.org
```

### Installation sur Debian/Ubuntu

#### Installation Certbot

```bash
# 1. Ajouter le dépôt Certbot
sudo apt update
sudo apt install -y certbot python3-certbot-nginx python3-certbot-apache

# 2. Installer les plugins spécifiques
# Pour Nginx
sudo apt install -y python3-certbot-nginx

# Pour Apache
sudo apt install -y python3-certbot-apache

# Pour DNS (Route53, CloudFlare, etc.)
sudo apt install -y python3-certbot-dns-route53
sudo apt install -y python3-certbot-dns-cloudflare

# 3. Vérifier l'installation
certbot --version
# Résultat : certbot 2.x.x

# 4. Vérifier les plugins disponibles
certbot plugins
# Résultat : nginx, apache, standalone, etc.

# 5. Test de sécurité
sudo certbot -n --test-mode --dry-run -d exemple.com --agree-tos -m admin@exemple.com
# Résultat : Simulation réussie sans certificat réel
```

#### Configuration Prérequis

```bash
# 1. Créer un utilisateur dédié (optionnel)
sudo adduser certbot --shell /usr/sbin/nologin --no-create-home

# 2. Créer répertoire de travail
sudo mkdir -p /var/cache/certbot
sudo chown certbot:certbot /var/cache/certbot
sudo chmod 700 /var/cache/certbot

# 3. Créer répertoire logs
sudo mkdir -p /var/log/certbot
sudo chown certbot:certbot /var/log/certbot
sudo chmod 700 /var/log/certbot

# 4. Vérifier la configuration ACME
cat /etc/letsencrypt/cli.ini
# Ou si n'existe pas, le créer

# 5. S'assurer que /etc/letsencrypt a les bonnes permissions
sudo chmod 755 /etc/letsencrypt
sudo chmod 755 /etc/letsencrypt/live
sudo chmod 755 /etc/letsencrypt/archive
```

---

## ⚙️ Configuration de Base {#configuration}

### Configuration CLI Certbot

**Fichier** : `/etc/letsencrypt/cli.ini`

```bash
# Créer/éditer le fichier
sudo nano /etc/letsencrypt/cli.ini

# Configuration recommandée ANSSI
```

```ini
# Let's Encrypt CLI Configuration - ANSSI Compliant

# Email pour notifications d'expiration
email = admin@exemple.com

# Agréer les conditions d'usage Let's Encrypt
agree-tos = True

# Mode non-interactif (scripts automatisés)
non-interactive = True

# Server ACME
server = https://acme-v02.api.letsencrypt.org/directory

# Domaines à protéger
# domains = exemple.com, www.exemple.com

# Plugins
authenticator = nginx
installer = nginx

# Logging
verbose = True
logs-dir = /var/log/letsencrypt

# Certificat et clé
cert-path = /etc/letsencrypt/live/
key-type = rsa
rsa-key-size = 2048

# Sécurité
preferred-challenges = http
# ou pour DNS :
# preferred-challenges = dns

# Performance
max-log-backups = 12
```

### Configuration Nginx

```nginx
# /etc/nginx/sites-available/exemple.com

server {
    listen 80;
    listen [::]:80;
    server_name exemple.com www.exemple.com;
    
    # Rediriger HTTP vers HTTPS (ANSSI)
    location / {
        return 301 https://$server_name$request_uri;
    }
    
    # Permettre validation ACME HTTP-01
    location /.well-known/acme-challenge/ {
        alias /var/www/certbot/.well-known/acme-challenge/;
        default_type text/plain;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name exemple.com www.exemple.com;
    
    # Certificats Let's Encrypt
    ssl_certificate /etc/letsencrypt/live/exemple.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/exemple.com/privkey.pem;
    
    # TLS ANSSI Compliant
    ssl_protocols TLSv1.3 TLSv1.2;
    ssl_ciphers 'TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    
    # HSTS (HTTP Strict Transport Security) - ANSSI
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    
    # Autres sécurité
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    root /var/www/exemple.com;
    index index.html index.htm;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
```

### Configuration Apache

```apache
# /etc/apache2/sites-available/exemple.com.conf

<VirtualHost *:80>
    ServerName exemple.com
    ServerAlias www.exemple.com
    
    # Redirection HTTP → HTTPS (ANSSI)
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
    
    # Permettre validation ACME
    <Location /.well-known/acme-challenge/>
        Require all granted
    </Location>
</VirtualHost>

<VirtualHost *:443>
    ServerName exemple.com
    ServerAlias www.exemple.com
    
    # Certificats Let's Encrypt
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/exemple.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/exemple.com/privkey.pem
    SSLCertificateChainFile /etc/letsencrypt/live/exemple.com/chain.pem
    
    # TLS ANSSI Compliant
    SSLProtocol TLSv1.3 TLSv1.2
    SSLCipherSuite 'TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384'
    SSLHonorCipherOrder on
    
    # HSTS (ANSSI)
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    
    # Autres sécurité
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
    
    DocumentRoot /var/www/exemple.com
    
    <Directory /var/www/exemple.com>
        Require all granted
    </Directory>
</VirtualHost>
```

---

## 🔐 Validation ACME {#validation}

### Validation HTTP-01

**Processus** :
1. Certbot crée un fichier unique dans `/.well-known/acme-challenge/TOKEN`
2. Let's Encrypt vérifie la présence du fichier via HTTP GET
3. Certificat émis après validation réussie

**Avantages** :
- Simple et rapide
- Fonctionne pour domaines publics
- Aucune interaction avec DNS

**Inconvénients** :
- Nécessite port 80 accessible
- Impossible pour wildcard
- Nécessite serveur web fonctionnel

**Configuration Certbot** :

```bash
# Validation HTTP-01 simple
sudo certbot certonly \
  --authenticator standalone \
  --agree-tos \
  -m admin@exemple.com \
  -d exemple.com \
  -d www.exemple.com

# Avec plugin Nginx
sudo certbot certonly \
  --authenticator nginx \
  --installer nginx \
  --agree-tos \
  -m admin@exemple.com \
  -d exemple.com \
  -d www.exemple.com
```

### Validation DNS-01

**Processus** :
1. Certbot crée une clé ACME unique
2. Crée TXT record DNS : `_acme-challenge.exemple.com = TOKEN`
3. Let's Encrypt query le DNS pour vérifier le TXT record
4. Certificat émis après validation

**Avantages** :
- Permet wildcard (*.exemple.com)
- Fonctionne pour domaines privés
- Accessible via internet n'est pas requis

**Inconvénients** :
- Plus complexe (accès DNS requis)
- Plus lent (propagation DNS)
- Nécessite plugin DNS

**Configuration Certbot** :

```bash
# Installation plugin CloudFlare
sudo apt install -y python3-certbot-dns-cloudflare

# Créer fichier credentials
sudo nano ~/.cloudflare.ini

# Contenu :
# dns_cloudflare_email = user@exemple.com
# dns_cloudflare_api_key = YOUR_API_KEY

# Permissions restrictives
sudo chmod 600 ~/.cloudflare.ini

# Validation DNS-01
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/.cloudflare.ini \
  --agree-tos \
  -m admin@exemple.com \
  -d exemple.com \
  -d www.exemple.com \
  -d "*.exemple.com"

# Providers disponibles :
# AWS Route53, CloudFlare, DigitalOcean, Linode, OVH, etc.
```

### Validation ALPN-01

**Processus** : Protocole le plus sécurisé (utilise TLS-ALPN)

```bash
# Nécessite support serveur TLS
sudo certbot certonly \
  --authenticator standalone \
  --preferred-challenges tls-alpn-01 \
  --agree-tos \
  -m admin@exemple.com \
  -d exemple.com
```

---

## 🔄 Renouvellement Automatisé {#renouvellement}

### Systemd Service et Timer (Recommandé)

**Fichier** : `/etc/systemd/system/certbot.service`

```ini
[Unit]
Description=Certbot Certificate Renewal
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
Group=root
ExecStart=/usr/bin/certbot renew --quiet --no-eff-email
ExecStartPost=/bin/systemctl reload nginx
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**Fichier** : `/etc/systemd/system/certbot.timer`

```ini
[Unit]
Description=Certbot Certificate Renewal Timer
Requires=certbot.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=1d
Persistent=true
Unit=certbot.service

[Install]
WantedBy=timers.target
```

**Activation** :

```bash
# Recharger systemd
sudo systemctl daemon-reload

# Activer et démarrer
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Vérifier le statut
sudo systemctl status certbot.timer
sudo systemctl list-timers --all | grep certbot

# Test manuel
sudo systemctl start certbot.service
sudo systemctl status certbot.service

# Logs
sudo journalctl -u certbot.service -n 20
```

### Cron Fallback (Alternative)

```bash
# Ajouter à /etc/cron.d/certbot-renew

# Renouvellement quotidien à 2h30
30 2 * * * root /usr/bin/certbot renew --quiet --no-eff-email && systemctl reload nginx >> /var/log/certbot-renew.log 2>&1

# Tâche de monitoring (alertes avant expiration)
0 8 * * * root /usr/local/bin/check-cert-expiry.sh >> /var/log/certbot-check.log 2>&1
```

### Script de Renouvellement Avancé

```bash
#!/bin/bash
# /usr/local/bin/certbot-renew-advanced.sh

set -euo pipefail

LOG_FILE="/var/log/certbot/renew-advanced.log"
ALERT_EMAIL="admin@exemple.com"
CERT_PATH="/etc/letsencrypt/live"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log "=== Renouvellement Certbot ==="

# 1. Renouveller les certificats
if sudo certbot renew --quiet --no-eff-email; then
    log "✓ Renouvellement réussi"
else
    log "✗ Erreur lors du renouvellement"
    echo "Erreur renouvellement certificats Let's Encrypt" | mail -s "Alerte Certbot" "$ALERT_EMAIL"
    exit 1
fi

# 2. Vérifier les certificats expirés
log "Vérification des certificats..."
for cert in $CERT_PATH/*/cert.pem; do
    domain=$(echo $cert | cut -d'/' -f6)
    expiry=$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)
    log "Certificat $domain expire le : $expiry"
done

# 3. Recharger serveur web
log "Rechargement Nginx..."
if sudo systemctl reload nginx; then
    log "✓ Nginx rechargé"
else
    log "✗ Erreur lors du rechargement Nginx"
    exit 1
fi

# 4. Vérifier les certificats sont valides
log "Vérification post-renouvellement..."
for domain in exemple.com www.exemple.com; do
    if openssl s_client -connect $domain:443 -servername $domain </dev/null | openssl x509 -noout -dates > /dev/null 2>&1; then
        log "✓ Certificat $domain valide"
    else
        log "✗ Certificat $domain invalide"
    fi
done

log "=== Renouvellement complété ==="
```

---

## 🔒 Sécurisation Avancée {#securite}

### Clé Privée Sécurisée

```bash
# 1. Vérifier permissions clé privée
ls -la /etc/letsencrypt/live/exemple.com/privkey.pem
# Résultat attendu : -rw------- root root (600)

# 2. Vérifier que seulement root peut lire
sudo stat -c "%A %U:%G" /etc/letsencrypt/live/exemple.com/privkey.pem

# 3. Vérifier le type de clé (RSA vs ECDSA)
openssl pkey -in /etc/letsencrypt/live/exemple.com/privkey.pem -text -noout | head -2

# 4. Sauvegarder la clé en lieu sûr
sudo cp -p /etc/letsencrypt/live/exemple.com/privkey.pem /backup/privkey_$(date +%Y%m%d).pem
sudo chmod 600 /backup/privkey_*.pem

# 5. Chiffrer les sauvegardes
sudo gpg --symmetric --cipher-algo AES256 /backup/privkey_20250116.pem
sudo shred -u /backup/privkey_20250116.pem
```

### Perfect Forward Secrecy (PFS)

```nginx
# Nginx configuration pour PFS
ssl_protocols TLSv1.3 TLSv1.2;
ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';
ssl_prefer_server_ciphers on;

# Vérifier : ECDHE (Elliptic Curve Diffie-Hellman Ephemeral)
# = Chaque session a sa propre clé de session
# = Même si clé privée compromise, sessions anciennes restent secrètes
```

### Revocation et Emergency

```bash
# Revoquer un certificat (en cas de compromission)
sudo certbot revoke \
  --cert-path /etc/letsencrypt/live/exemple.com/cert.pem \
  --reason=keyCompromise

# Supprimer certificat entièrement
sudo certbot delete --cert-name exemple.com

# Générer nouveau certificat d'urgence
sudo certbot certonly --force-renewal -d exemple.com -d www.exemple.com
```

---

## ⚡ Performance et Optimisation {#performance}

### OCSP Stapling

**Pourquoi** : Vérifier révocation certificat sans query OCSP (plus rapide)

```nginx
# Nginx configuration
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/letsencrypt/live/exemple.com/chain.pem;
resolver 8.8.8.8 1.1.1.1;
resolver_timeout 5s;
```

### Session Resumption

```nginx
# Réutiliser sessions TLS (réduction overhead)
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
ssl_session_tickets off;  # Plus sécurisé
```

### HTTP/2 et HTTP/3

```nginx
# HTTP/2 (obligatoire pour TLS 1.3 performant)
listen 443 ssl http2;
listen [::]:443 ssl http2;

# HTTP/3 (si support OpenSSL 3.0+)
# listen 443 quic reuseport;
# add_header Alt-Svc 'h3=":443"; ma=86400' always;
```

### Certificate Pinning (Avancé)

```bash
# Générer Public Key Pin (HPKP)
# ⚠️ À utiliser avec prudence (risque de lockout)

openssl x509 -in /etc/letsencrypt/live/exemple.com/fullchain.pem -pubkey -noout | \
  openssl pkey -pubin -outform DER | \
  openssl dgst -sha256 -binary | \
  openssl enc -base64

# Header HTTP-Pinning
# Public-Key-Pins: pin-sha256="BASE64_HERE"; max-age=5184000
```

---

## 📊 Monitoring et Audit {#monitoring}

### Script de Vérification d'Expiration

```bash
#!/bin/bash
# Check certificate expiry

CERT_PATH="/etc/letsencrypt/live"
ALERT_THRESHOLD=30  # Jours
ALERT_EMAIL="admin@exemple.com"

for domain_dir in $CERT_PATH/*/; do
    domain=$(basename "$domain_dir")
    cert_file="$domain_dir/cert.pem"
    
    if [ ! -f "$cert_file" ]; then
        continue
    fi
    
    # Calculer jours restants
    expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    expiry_epoch=$(date -d "$expiry_date" +%s)
    now_epoch=$(date +%s)
    days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))
    
    if [ $days_left -lt 0 ]; then
        echo "ERREUR: Certificat $domain EXPIRÉ"
        echo "Certificat $domain expiré !" | mail -s "ALERTE EXPIRATION" "$ALERT_EMAIL"
    elif [ $days_left -lt $ALERT_THRESHOLD ]; then
        echo "ATTENTION: Certificat $domain expire dans $days_left jours"
        echo "Certificat $domain expire dans $days_left jours" | mail -s "ALERTE EXPIRATION" "$ALERT_EMAIL"
    else
        echo "OK: Certificat $domain valide pour $days_left jours"
    fi
done
```

### Monitoring TLS avec SSL Labs

```bash
# Tester configuration TLS
# https://www.ssllabs.com/ssltest/

# Ou localement :
openssl s_client -connect exemple.com:443 -servername exemple.com < /dev/null | \
  openssl x509 -noout -dates -subject -issuer

# Vérifier TLS version
openssl s_client -connect exemple.com:443 -tls1_3 </dev/null 2>&1 | grep "Protocol"

# Vérifier cipher suites
openssl s_client -connect exemple.com:443 -cipher HIGH </dev/null 2>&1 | grep "Cipher"
```

### Logs et Audit

```bash
# Logs Certbot
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# Logs renouvellement
sudo journalctl -u certbot.service -n 50

# Audit des certificats
for cert in /etc/letsencrypt/live/*/cert.pem; do
    echo "=== $(dirname $cert) ==="
    openssl x509 -in "$cert" -noout -subject -dates -issuer
done
```

---

## 🔍 Dépannage et Troubleshooting {#debogage}

### Problème 1 : Validation ACME Échoue

```bash
# Diagnostic HTTP-01
curl -v http://exemple.com/.well-known/acme-challenge/test-token

# Si erreur 404, vérifier :
# 1. Redirection HTTP → HTTPS active
# 2. Chemins corrects configurés
# 3. Permissions fichiers

# Diagnostic DNS-01
nslookup _acme-challenge.exemple.com
dig _acme-challenge.exemple.com

# Si TXT record absent, vérifier :
# 1. Plugin DNS configuré
# 2. Credentials valides
# 3. API provider accessible
```

### Problème 2 : Certificat Pas Renouvelé

```bash
# Vérifier l'expiration
openssl x509 -in /etc/letsencrypt/live/exemple.com/cert.pem -noout -dates

# Test renouvellement dry-run
sudo certbot renew --dry-run --verbose

# Vérifier logs
sudo journalctl -u certbot.timer
sudo tail -100 /var/log/letsencrypt/letsencrypt.log

# Forcer renouvellement
sudo certbot renew --force-renewal
```

### Problème 3 : TLS Mismatch

```bash
# Vérifier certificat chargé
openssl s_client -connect exemple.com:443 -servername exemple.com < /dev/null | \
  openssl x509 -noout -text | grep -E "CN=|DNS:"

# Comparer avec fichier serveur
openssl x509 -in /etc/letsencrypt/live/exemple.com/cert.pem -noout -text | grep -E "CN=|DNS:"

# Vérifier symlinks
ls -la /etc/letsencrypt/live/exemple.com/

# Recharger serveur web
sudo systemctl reload nginx
```

---

## 📚 Références Officielles

### Documentation Officielle

**Let's Encrypt**
- https://letsencrypt.org/docs/

**Certbot**
- https://certbot.eff.org/docs/

**ACME Protocol (RFC 8555)**
- https://tools.ietf.org/html/rfc8555

**ANSSI - Recommandations**
- https://cyber.gouv.fr/

---

**Document généré le** : 17 novembre 2025
**Conformité** : ANSSI 2023 | Let's Encrypt | OpenSSL 1.1.1+
**Révision** : 1.0
