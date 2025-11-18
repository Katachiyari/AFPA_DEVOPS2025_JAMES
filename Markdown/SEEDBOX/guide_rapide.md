guideRapide# ⚡ Guide Rapide : Seedbox qBittorrent en 30 minutes

## 🎯 Résumé des commandes

### 1️⃣ Installation (5 min)

```bash
# Mise à jour et dépendances
sudo apt update && sudo apt upgrade -y
sudo apt install -y qbittorrent-nox nginx fail2ban certbot python3-certbot-nginx iptables-persistent

# Créer l'utilisateur
sudo adduser --system --group --no-create-home --disabled-login qbittorrent-nox

# Créer les répertoires
sudo mkdir -p /mnt/torrents/{downloads,incomplete}
sudo chown -R qbittorrent-nox:qbittorrent-nox /mnt/torrents
sudo chmod -R 750 /mnt/torrents
```

### 2️⃣ Configuration qBittorrent (5 min)

**Créer `/etc/systemd/system/qbittorrent-nox.service` :**

```ini
[Unit]
Description=qBittorrent-nox Daemon
After=network.target
[Service]
User=qbittorrent-nox
ExecStart=/usr/bin/qbittorrent-nox --webui-port=8080
Restart=always
[Install]
WantedBy=multi-user.target
```

**Démarrer :**

```bash
sudo systemctl daemon-reload
sudo systemctl start qbittorrent-nox
sudo systemctl enable qbittorrent-nox
```

### 3️⃣ Fail2Ban (5 min)

**Créer `/etc/fail2ban/filter.d/qbittorrent.conf` :**

```ini
[Definition]
failregex = ^.* WebAPI login failure.*IP: <HOST>
```

**Créer `/etc/fail2ban/jail.d/qbittorrent.local` :**

```ini
[qbittorrent]
enabled = true
filter = qbittorrent
port = 80,443,8080
logpath = /var/log/qbittorrent/qbittorrent.log
maxretry = 5
findtime = 600
bantime = 1800
action = iptables-multiport[name=qbittorrent, port="80,443,8080"]
```

**Démarrer :**

```bash
sudo systemctl start fail2ban
sudo systemctl enable fail2ban
```

### 4️⃣ iptables (5 min)

```bash
# Politiques par défaut
sudo iptables -P INPUT DROP
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD DROP

# Connexions établies
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Localhost
sudo iptables -A INPUT -i lo -j ACCEPT

# SSH, HTTP, HTTPS
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# BitTorrent (adapter le port)
PORT=54321
sudo iptables -A INPUT -p tcp --dport $PORT -j ACCEPT
sudo iptables -A INPUT -p udp --dport $PORT -j ACCEPT

# Sauvegarder
sudo netfilter-persistent save
```

### 5️⃣ Nginx + HTTPS (5 min)

**Créer `/etc/nginx/sites-available/qbittorrent` :**

```nginx
server {
    listen 80;
    server_name qbittorrent.exemple.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name qbittorrent.exemple.com;
    ssl_certificate /etc/letsencrypt/live/qbittorrent.exemple.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/qbittorrent.exemple.com/privkey.pem;
    
    add_header Strict-Transport-Security "max-age=31536000" always;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Activer :**

```bash
sudo ln -s /etc/nginx/sites-available/qbittorrent /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Certificat Let's Encrypt
sudo certbot certonly --nginx -d qbittorrent.exemple.com
```

---

## 🔍 Tests rapides

```bash
# qBittorrent actif ?
sudo systemctl status qbittorrent-nox

# Fail2Ban actif ?
sudo fail2ban-client status

# Nginx OK ?
sudo nginx -t

# iptables chargées ?
sudo iptables -L -n | head -20

# Accès web
curl https://qbittorrent.exemple.com
```

---

## 📊 Tableau de synthèse

| Composant | Port | Utilisateur | Auto-démarrage |
|-----------|------|-------------|-----------------|
| qBittorrent | 8080 (interne) | qbittorrent-nox | ✅ |
| Nginx | 80, 443 | www-data | ✅ |
| Fail2Ban | N/A | root | ✅ |
| BitTorrent | 54321 | qbittorrent-nox | ✅ |

---

## ⚠️ Actions obligatoires

1. ✅ Changer le mot de passe admin dans qBittorrent
2. ✅ Remplacer `qbittorrent.exemple.com` par votre domaine
3. ✅ Vérifier que les ports ne sont pas en conflit
4. ✅ Tester l'accès HTTPS avant de déployer en production

---

## 🆘 Dépannage rapide

```bash
# qBittorrent ne démarre pas
sudo journalctl -u qbittorrent-nox -n 50

# Fail2Ban ne ban rien
sudo fail2ban-regex /var/log/qbittorrent/qbittorrent.log /etc/fail2ban/filter.d/qbittorrent.conf

# Nginx erreur 502
sudo tail -f /var/log/nginx/error.log

# Port déjà utilisé
sudo ss -tlnp | grep 8080
