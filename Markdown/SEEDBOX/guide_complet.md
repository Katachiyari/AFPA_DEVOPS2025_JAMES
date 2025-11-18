# 🚀 Guide Complet : Seedbox Web avec qBittorrent + Fail2Ban + iptables

## Table des matières
- [Introduction](#introduction)
- [Architecture du système](#architecture-du-système)
- [Prérequis](#prérequis)
- [Partie 1 : Installation du système](#partie-1--installation-du-système)
- [Partie 2 : Configuration de qBittorrent](#partie-2--configuration-de-qbittorrent)
- [Partie 3 : Sécurité avec Fail2Ban](#partie-3--sécurité-avec-fail2ban)
- [Partie 4 : Règles Firewall avec iptables](#partie-4--règles-firewall-avec-iptables)
- [Partie 5 : Reverse Proxy Nginx + HTTPS](#partie-5--reverse-proxy-nginx--https)
- [Tests et vérification](#tests-et-vérification)

---

## Introduction

### 🎯 Pourquoi cette configuration ?

Une seedbox est un serveur optimisé pour partager des fichiers via BitTorrent avec une interface web. Cette guide combine trois technologies essentielles :

1. **qBittorrent** : Client torrent puissant avec interface web
2. **Fail2Ban** : Protection contre les tentatives de brute-force
3. **iptables** : Firewall Linux pour contrôler le trafic réseau

### 💡 Avantages de cette approche

- ✅ **Sécurité maximale** : Fail2Ban bloque les attaques automatiques
- ✅ **Contrôle granulaire** : iptables maîtrise chaque port et protocole
- ✅ **Accès distant** : Interface web sécurisée via HTTPS
- ✅ **Automatisation** : Systemd gère le démarrage automatique

---

## Architecture du système

```
Internet (HTTPS)
    ↓
Nginx (Reverse Proxy + SSL)
    ↓
Fail2Ban (Protection)
    ↓
qBittorrent WebUI (Port 8080 interne)
    ↓
BitTorrent (Ports 6881-6889 + Port personnalisé)
```

### 🔄 Flux de sécurité

```
Requête externe
    ↓
Nginx (Valide HTTPS)
    ↓
Fail2Ban (Vérifie logs)
    ↓
iptables (Vérifie règles)
    ↓
qBittorrent (Traite la requête)
```

---

## Prérequis

### 📋 Configurations minimales

| Élément | Recommandation |
|---------|----------------|
| **OS** | Debian 11/12 ou Ubuntu 20.04+ |
| **RAM** | 2 GB minimum (4 GB recommandé) |
| **Disque** | 50 GB minimum pour les téléchargements |
| **CPU** | 2 cores minimum |
| **Réseau** | Connexion stable, bande passante suffisante |

### 🔐 Prérequis de sécurité

- Accès root ou sudo
- Domaine personnalisé (optionnel mais recommandé)
- Certificat Let's Encrypt (gratuit)
- IP statique du serveur

### 📦 Packages nécessaires

```bash
# Mise à jour initiale
sudo apt update && sudo apt upgrade -y

# Dépendances principales
sudo apt install -y curl wget git
```

---

## Partie 1 : Installation du système

### Étape 1.1 : Créer un utilisateur dédié pour qBittorrent

**Pourquoi ?** Isoler qBittorrent pour des raisons de sécurité. Si le service est compromis, l'attaquant n'aura pas accès root.

```bash
# Créer l'utilisateur système
sudo adduser --system --group --no-create-home --disabled-login qbittorrent-nox

# Ajouter l'utilisateur au groupe sudo (optionnel pour certaines opérations)
sudo usermod -aG sudo qbittorrent-nox
```

**Explications des flags :**
- `--system` : Crée un utilisateur système (pas de home directory complet)
- `--group` : Crée un groupe du même nom
- `--no-create-home` : Pas de répertoire personnel
- `--disabled-login` : Impossible de se connecter avec cet utilisateur

### Étape 1.2 : Créer les répertoires nécessaires

```bash
# Répertoire de configuration
sudo mkdir -p /etc/qbittorrent
sudo chown qbittorrent-nox:qbittorrent-nox /etc/qbittorrent
sudo chmod 750 /etc/qbittorrent

# Répertoire pour les téléchargements
sudo mkdir -p /mnt/torrents/downloads
sudo mkdir -p /mnt/torrents/incomplete
sudo chown -R qbittorrent-nox:qbittorrent-nox /mnt/torrents
sudo chmod -R 750 /mnt/torrents

# Répertoire de logs
sudo mkdir -p /var/log/qbittorrent
sudo chown qbittorrent-nox:qbittorrent-nox /var/log/qbittorrent
sudo chmod 750 /var/log/qbittorrent
```

**Pourquoi ces répertoires ?**
- `/etc/qbittorrent` : Configuration persistante
- `/mnt/torrents` : Stockage des fichiers (point de montage optimal)
- `/var/log/qbittorrent` : Logs pour Fail2Ban

### Étape 1.3 : Installer qBittorrent-nox

```bash
# Méthode 1 : Via les dépôts Debian (plus simple)
sudo apt install -y qbittorrent-nox

# Méthode 2 : Build statique (version plus récente)
cd /tmp
wget https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.6.5/qbittorrent-nox-x86_64-linux-musl.tar.gz
tar xzf qbittorrent-nox-*.tar.gz
sudo mv qbittorrent-nox /usr/local/bin/
```

**Comparaison des méthodes :**

| Critère | Dépôts APT | Build statique |
|---------|-----------|-----------------|
| Installation | 2 minutes | 5 minutes |
| Version | Standard stable | Plus récente |
| Dépendances | Multiples | Aucune |
| Mise à jour | Automatique | Manuel |

---

## Partie 2 : Configuration de qBittorrent

### Étape 2.1 : Fichier de configuration initiale

Créer `/etc/qbittorrent/qBittorrent.conf` :

```ini
# Configuration WebUI
[WebUI]
# Port d'écoute INTERNE (Nginx le proxifiera)
WebUI\Port=8080
# Écouter UNIQUEMENT sur localhost
WebUI\Address=127.0.0.1
# Authentification requise
WebUI\BypassLocalAuth=false
WebUI\BypassAuthSubnetWhitelist=false
# Logs détaillés pour Fail2Ban
WebUI\LogURL=true

# Authentication
[Authentication]
Username=admin
# Le mot de passe sera changé au premier démarrage
```

**Explications détaillées :**

- `WebUI\Port=8080` : Port d'écoute interne (jamais exposé directement)
- `WebUI\Address=127.0.0.1` : Écoute UNIQUEMENT sur localhost (sécurité critique)
- `WebUI\BypassLocalAuth=false` : Force l'authentification même localement
- `WebUI\LogURL=true` : Enregistre les URLs demandées

### Étape 2.2 : Service systemd pour qBittorrent

Créer `/etc/systemd/system/qbittorrent-nox.service` :

```ini
[Unit]
Description=qBittorrent-nox Daemon Service
After=network-online.target nss-lookup.target
Wants=network-online.target

[Service]
Type=exec
User=qbittorrent-nox
Group=qbittorrent-nox

# Chemins de configuration et logs
ExecStart=/usr/bin/qbittorrent-nox --profile=/etc/qbittorrent --webui-port=8080
ExecStop=/bin/kill -SIGTERM $MAINPID

# Gestion des redémarrages
Restart=always
RestartSec=5

# Limite des fichiers ouverts
LimitNOFILE=65535

# Journal
StandardOutput=append:/var/log/qbittorrent/qbittorrent.log
StandardError=append:/var/log/qbittorrent/qbittorrent-error.log

# Isolation de sécurité
PrivateTmp=yes
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=yes

[Install]
WantedBy=multi-user.target
```

**Paramètres de sécurité :**
- `PrivateTmp=yes` : Isoler `/tmp` du processus
- `NoNewPrivileges=true` : Empêcher l'escalade de privilèges
- `ProtectSystem=strict` : Système de fichiers en lecture seule
- `ProtectHome=yes` : Impossible d'accéder aux répertoires home

### Étape 2.3 : Démarrer et tester qBittorrent

```bash
# Recharger les configurations systemd
sudo systemctl daemon-reload

# Démarrer le service
sudo systemctl start qbittorrent-nox

# Vérifier le statut
sudo systemctl status qbittorrent-nox

# Activer au démarrage automatique
sudo systemctl enable qbittorrent-nox

# Voir les logs
sudo journalctl -u qbittorrent-nox -f
```

### Étape 2.4 : Configuration de base qBittorrent

Accéder temporairement via SSH tunnel :

```bash
# Sur votre machine locale
ssh -L 8080:127.0.0.1:8080 user@votre-serveur

# Accéder à http://127.0.0.1:8080 dans le navigateur
```

**Actions dans l'interface WebUI :**

1. **Changer le mot de passe :**
   - Aller à `Outils` → `Options` → `Web UI`
   - Modifier le mot de passe admin

2. **Activer les logs détaillés :**
   - `Outils` → `Options` → `Web UI`
   - Cocher "Enregistrer les URL des requêtes"

3. **Configuration de la connexion :**
   - `Outils` → `Options` → `Connexion`
   - Définir un **port d'écoute spécifique** (ex: 54321)
   - Vérifier "UPnP/NAT-PMP" selon votre réseau

4. **Configuration BitTorrent :**
   - `Outils` → `Options` → `BitTorrent`
   - Activer le **chiffrement** : "Chiffrement autorisé"
   - Désactiver DHT/PEX si souhaité

---

## Partie 3 : Sécurité avec Fail2Ban

### Étape 3.1 : Installer Fail2Ban

```bash
# Installation
sudo apt install -y fail2ban

# Vérifier l'installation
fail2ban-client -v
```

### Étape 3.2 : Créer un filtre pour qBittorrent

Créer `/etc/fail2ban/filter.d/qbittorrent.conf` :

```ini
# Filtre pour détecter les tentatives d'authentification échouées
[Definition]
# Utiliser la syntaxe des noms de groupes Python
failregex = ^.* WebAPI login failure.*IP: <HOST>
            ^.* Authentication failed.*<HOST>
            
# Ignorer les tentatives depuis localhost
ignoreregex = 127\.0\.0\.1
              ::1
```

**Explications du regex :**

- `failregex` : Pattern pour détecter les échecs
- `<HOST>` : Placeholder Fail2Ban pour l'adresse IP
- `ignoreregex` : Patterns à ignorer (localhost par exemple)

### Étape 3.3 : Configurer la jail Fail2Ban

Créer `/etc/fail2ban/jail.d/qbittorrent.local` :

```ini
[qbittorrent]
# Activer la jail
enabled = true

# Filtre à utiliser
filter = qbittorrent

# Ports concernés (web UI)
port = http,https,8080

# Chemin du fichier de log
logpath = /var/log/qbittorrent/qbittorrent.log

# Nombre d'essais avant bannissement
maxretry = 5

# Fenêtre d'observation (10 minutes)
findtime = 600

# Durée du bannissement (30 minutes)
bantime = 1800

# Action à exécuter
action = iptables-multiport[name=qbittorrent, port="http,https,8080"]
         sendmail-whois[name=qbittorrent, dest=your-email@example.com]
```

**Signification des paramètres :**

| Paramètre | Valeur | Explication |
|-----------|--------|-------------|
| `maxretry` | 5 | Ban après 5 tentatives échouées |
| `findtime` | 600 | Fenêtre de 10 minutes |
| `bantime` | 1800 | Bannissement de 30 minutes |
| `action` | iptables | Utiliser iptables pour bannir |

### Étape 3.4 : Tester le filtre

```bash
# Vérifier la syntaxe du filtre
sudo fail2ban-regex /var/log/qbittorrent/qbittorrent.log /etc/fail2ban/filter.d/qbittorrent.conf

# Vérifier la configuration
sudo fail2ban-client status

# Voir les jails
sudo fail2ban-client status qbittorrent
```

### Étape 3.5 : Démarrer Fail2Ban

```bash
# Démarrer le service
sudo systemctl start fail2ban

# Activer au démarrage
sudo systemctl enable fail2ban

# Vérifier le statut
sudo systemctl status fail2ban

# Voir les logs en temps réel
sudo tail -f /var/log/fail2ban.log
```

---

## Partie 4 : Règles Firewall avec iptables

### Étape 4.1 : Comprendre iptables

**iptables fonctionne par chaînes :**

```
INPUT  → Trafic entrant → Décision (ACCEPT/DROP/REJECT)
OUTPUT → Trafic sortant → Décision
FORWARD → Transit → Décision
```

### Étape 4.2 : Politiques par défaut

```bash
# Vérifier les politiques actuelles
sudo iptables -L -n

# Fixer les politiques par défaut (DROP sur INPUT, ACCEPT sur OUTPUT)
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT
```

**Explications :**
- `INPUT DROP` : Rejette tout par défaut (liste blanche)
- `OUTPUT ACCEPT` : Accepte tout sortant
- `FORWARD DROP` : Aucun transit

### Étape 4.3 : Règles essentielles

```bash
#!/bin/bash
# Fichier : /usr/local/bin/configure-firewall.sh

# === CONNEXIONS ÉTABLIES ===
# Accepter le trafic établi et lié
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# === LOCALHOST ===
# Accepter loopback (CRITIQUE pour systemd et services)
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT

# === SSH (Administration distante) ===
# Accepter SSH de n'importe où (ou limiter à une IP)
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# === HTTP/HTTPS (Pour Nginx) ===
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# === ICMP (Ping) ===
# Autoriser le ping pour diagnostics
sudo iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# === PORTS QBITTORRENT ===
# WebUI interne (8080) - SEULEMENT de Nginx sur localhost
# Cette règle est gérée par Fail2Ban

# Port d'écoute BitTorrent (à ajuster à votre configuration)
PORT_BT=54321
sudo iptables -A INPUT -p tcp --dport $PORT_BT -j ACCEPT
sudo iptables -A INPUT -p udp --dport $PORT_BT -j ACCEPT

# Ports BitTorrent standards (6881-6889)
sudo iptables -A INPUT -p tcp --dport 6881:6889 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 6881:6889 -j ACCEPT

# === LOGGING (optionnel) ===
# Log les paquets rejetés
sudo iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables-drop: " --log-level 7
```

### Étape 4.4 : Intégration avec Fail2Ban

Fail2Ban génère automatiquement des règles iptables. Vérifier :

```bash
# Lister les chaînes Fail2Ban
sudo iptables -L | grep fail2ban

# Voir les IPs bannie pour qBittorrent
sudo iptables -L f2b-qbittorrent -n
```

### Étape 4.5 : Persister les règles iptables

```bash
# Installer iptables-persistent
sudo apt install -y iptables-persistent

# Sauvegarder les règles actuelles
sudo netfilter-persistent save

# Recharger au démarrage (automatique)
sudo netfilter-persistent reload
```

**Alternative : Script de démarrage**

Créer `/etc/network/if-pre-up.d/firewall` :

```bash
#!/bin/bash
# Restaurer les règles iptables au démarrage
iptables-restore < /etc/iptables/rules.v4
ip6tables-restore < /etc/iptables/rules.v6
```

---

## Partie 5 : Reverse Proxy Nginx + HTTPS

### Étape 5.1 : Installer Nginx et Certbot

```bash
# Installation Nginx
sudo apt install -y nginx

# Installation Certbot pour Let's Encrypt
sudo apt install -y certbot python3-certbot-nginx
```

### Étape 5.2 : Créer le fichier de configuration Nginx

Créer `/etc/nginx/sites-available/qbittorrent` :

```nginx
# Redirection HTTP vers HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name qbittorrent.exemple.com;

    # Renouvellement Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Rediriger tout le reste en HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# Configuration HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name qbittorrent.exemple.com;

    # === CERTIFICATS SSL ===
    # À remplir après création via certbot
    ssl_certificate /etc/letsencrypt/live/qbittorrent.exemple.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/qbittorrent.exemple.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # === SÉCURITÉ ===
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # === PROXY VERS QBITTORRENT ===
    location / {
        # Proxy vers qBittorrent WebUI
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Préservation de l'authentification
        proxy_set_header Referer '';
        proxy_set_header Origin '';
        
        # WebSocket support (pour les mises à jour en temps réel)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 600s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
    }

    # === LOGS ===
    access_log /var/log/nginx/qbittorrent-access.log;
    error_log /var/log/nginx/qbittorrent-error.log;
}
```

**Explications détaillées :**

- `proxy_pass http://127.0.0.1:8080` : Redirige vers qBittorrent interne
- `X-Forwarded-For` : Transmet l'IP réelle à l'application
- `Upgrade` et `Connection` : Essentiels pour WebSocket (interface web réactive)

### Étape 5.3 : Valider et tester Nginx

```bash
# Vérifier la syntaxe
sudo nginx -t

# Activer le site
sudo ln -s /etc/nginx/sites-available/qbittorrent /etc/nginx/sites-enabled/

# Recharger Nginx
sudo systemctl reload nginx
```

### Étape 5.4 : Générer le certificat SSL

```bash
# Générer le certificat Let's Encrypt
sudo certbot certonly --nginx -d qbittorrent.exemple.com

# Vérifier le statut du certificat
sudo certbot certificates

# Tester le renouvellement automatique
sudo certbot renew --dry-run
```

### Étape 5.5 : Renouvellement automatique du certificat

```bash
# Activer le service systemd timer
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Vérifier
sudo systemctl status certbot.timer
sudo systemctl list-timers
```

---

## Tests et vérification

### Test 1 : Accessibilité qBittorrent

```bash
# Via SSH local
ssh -L 8080:127.0.0.1:8080 user@serveur
# Ouvrir http://127.0.0.1:8080 dans le navigateur

# Via HTTPS public (après Nginx)
curl https://qbittorrent.exemple.com -u admin:password
```

### Test 2 : Règles iptables

```bash
# Lister toutes les règles
sudo iptables -L -n -v

# Vérifier les chaînes Fail2Ban
sudo iptables -L f2b-sshd -n
sudo iptables -L f2b-qbittorrent -n

# Tester une connexion bloquée
ssh -v un.mauvais.serveur.com
```

### Test 3 : Logs Fail2Ban

```bash
# Voir les bans en cours
sudo fail2ban-client status

# Voir les bans pour qBittorrent spécifiquement
sudo fail2ban-client status qbittorrent

# Logs détaillés
sudo tail -100 /var/log/fail2ban.log
```

### Test 4 : Certificat SSL

```bash
# Vérifier le certificat
echo | openssl s_client -servername qbittorrent.exemple.com -connect qbittorrent.exemple.com:443

# Scanner SSL (site externe)
https://www.ssllabs.com/ssltest/
```

### Test 5 : Règles Firewall + Logs

```bash
# Monitor les paquets rejetés
sudo iptables -I INPUT 1 -m limit --limit 5/min -j LOG --log-prefix "DEBUG: " --log-level 7

# Voir les logs du kernel
sudo dmesg | tail -50
sudo journalctl -p 4 | tail -50
```

---

## Astuces de maintenance

### Commandes Fail2Ban courantes

```bash
# Unban une IP manuellement
sudo fail2ban-client set qbittorrent unbanip 192.168.1.100

# Ban manuel
sudo fail2ban-client set qbittorrent banip 192.168.1.100

# Réinitialiser une jail
sudo fail2ban-client set qbittorrent reset

# Recharger la configuration
sudo fail2ban-client reload
```

### Commandes iptables courantes

```bash
# Voir les règles avec numérotation
sudo iptables -L -n --line-numbers

# Supprimer une règle
sudo iptables -D INPUT 5  # Supprime la ligne 5

# Insérer une règle
sudo iptables -I INPUT 1 -p tcp --dport 1234 -j ACCEPT

# Afficher les statistiques
sudo iptables -L -v -n
```

### Monitoring qBittorrent

```bash
# Voir les logs
sudo journalctl -u qbittorrent-nox -f

# Vérifier l'utilisation des ressources
ps aux | grep qbittorrent-nox

# Voir les connexions réseau
sudo ss -tlnp | grep qbittorrent
netstat -an | grep 8080
```

---

## Conclusion

Vous avez maintenant une **seedbox sécurisée, automatisée et accessible via une interface web HTTPS**. 

**Résumé de la sécurité :**
- ✅ qBittorrent sur utilisateur non-root
- ✅ Fail2Ban protège contre les attaques
- ✅ iptables contrôle le trafic réseau
- ✅ HTTPS via Let's Encrypt
- ✅ Nginx reverse proxy

**Prochaines étapes :**
- Configurer les alertes email Fail2Ban
- Mettre en place un VPN pour les torrents
- Automatiser les téléchargements (Sonarr/Radarr)
- Monitorer les logs régulièrement
