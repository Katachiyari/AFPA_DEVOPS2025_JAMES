# 🚀 Tutoriel académique complet : Installation de Wiki.js avec Docker, PostgreSQL, Nginx et HTTPS Let's Encrypt

---

## 🗺️ Architectures et concepts

```
📦 Utilisateur   ⇆ 🔐 https://wakijs.fr (certificat SSL) ⇆ 🌐 Nginx Reverse Proxy ⇆ 🧰 Wiki.js (Docker) ⇆ 🛢️ PostgreSQL (Docker)
```

- 🌐 **Nginx** : Reverse proxy, centre de terminaison SSL, sécurité, compression et redirection.
- 🧰 **Wiki.js** : Service wiki principal, uniquement accessible depuis localhost
- 🛢️ **PostgreSQL** : Stockage des pages et configurations

---

## 1️⃣ Pré-requis

- ✅ Un serveur Debian/Ubuntu avec accès root/sudo
- ✅ Un nom de domaine pointant vers l’IP du serveur
- ✅ Ports 80/443 ouverts

---

## 2️⃣ Préparation du serveur

### 🌟 Mise à jour & outils essentiels

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git sudo gnupg ca-certificates nano ufw lsb-release tree
```

### 🐳 Installer Docker & Docker Compose

```bash
# Installation officielle recommandée
curl -fsSL https://get.docker.com | sudo sh
sudo apt install -y docker-compose
sudo systemctl enable --now docker
```

---

## 3️⃣ Installation et configuration de Nginx 🔒

### 🏗️ Installer Nginx

```bash
sudo apt install nginx -y
sudo systemctl enable --now nginx
```

### 🔥 UFW (pare-feu) ouverture des ports

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80,443/tcp
sudo ufw --force enable
```

---

## 4️⃣ Structure du projet 🗂️

```bash
sudo mkdir -p /opt/wikijs/data /opt/wikijs/db-data
sudo chown 1000:1000 /opt/wikijs/data /opt/wikijs/db-data
sudo chmod 755 /opt/wikijs/data /opt/wikijs/db-data
cd /opt/wikijs
```

---

## 5️⃣ docker-compose.yml 🧩

```yaml
version: '3.7'
services:
  db:
    image: postgres:16-alpine
    container_name: wikijs_db
    environment:
      POSTGRES_DB: wiki
      POSTGRES_USER: wikijs
      POSTGRES_PASSWORD: wikijsrocks
    restart: unless-stopped
    volumes:
      - ./db-data:/var/lib/postgresql/data
    networks:
      - wikijs_net

  wikijs:
    image: requarks/wiki:latest
    container_name: wikijs
    depends_on:
      - db
    restart: unless-stopped
    ports:
      - '127.0.0.1:3000:3000'
    environment:
      DB_TYPE: postgres
      DB_HOST: db
      DB_PORT: 5432
      DB_USER: wikijs
      DB_PASS: wikijsrocks
      DB_NAME: wiki
    volumes:
      - ./data:/wiki/data
    networks:
      - wikijs_net

networks:
  wikijs_net:
    driver: bridge
```

---

## 6️⃣ Déploiement des conteneurs 🏁

```bash
cd /opt/wikijs
sudo docker-compose up -d
sudo docker ps
```

---

## 7️⃣ Configuration Nginx Reverse Proxy & SSL 🌐🔑

### ⚙️ Fichier site Nginx

```nginx
upstream wikijs_backend {
    server 127.0.0.1:3000;
}

server {
    listen 80;
    server_name wakijs.fr www.wakijs.fr;
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name wakijs.fr www.wakijs.fr;
    ssl_certificate /etc/letsencrypt/live/wakijs.fr/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/wakijs.fr/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    add_header Strict-Transport-Security 'max-age=31536000; includeSubDomains' always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options SAMEORIGIN always;
    location / {
        proxy_pass http://wikijs_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 90;
        proxy_read_timeout 180;
    }
}
```

### 📛 Activation et vérification

```bash
sudo mkdir -p /var/www/certbot
sudo tee /etc/nginx/sites-available/wakijs.fr < wakijs.fr.conf
sudo ln -s /etc/nginx/sites-available/wakijs.fr /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default || true
sudo nginx -t
sudo systemctl reload nginx
```

---

## 8️⃣ Let's Encrypt - Certificats SSL 🔒

### 💡 Installer Certbot

```bash
sudo apt install certbot python3-certbot-nginx -y
```

### 🧪 Générer le certificat

```bash
sudo certbot certonly --webroot -w /var/www/certbot -d wakijs.fr -d www.wakijs.fr --email VOTRE-EMAIL --agree-tos --non-interactive
```

### 🔄 Recharger Nginx

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 9️⃣ Setup initial Wiki.js 🧙‍♂️

- Rendez-vous sur https://wakijs.fr
- Complétez l’assistant de configuration (admin, titre, BDD…)

---

## 1️⃣0️⃣ Dépannage classique 🧑‍🔧

- 🟥 **Erreur "connection refused"**
  - `docker ps` et `docker logs wikijs`
  - Pare-feu : `sudo ufw status`
- 🟡 **Nginx ne démarre pas**
  - `sudo nginx -t`, `sudo tail -50 /var/log/nginx/error.log`
- 🟦 **Certificat échoue**
  - DNS ok (check dig ou nslookup)
  - Aucun service sur 80 déjà (ss -tlnp)
- 🟪 **Permissions Docker**
  - `sudo chown 1000:1000 /opt/wikijs/data /opt/wikijs/db-data`
- 🟧 **Wiki.js « Exited »**
  - Inspecter les logs : `docker logs wikijs`
- 🟩 **Bad Gateway**
  - Wiki.js tourne, port bien mappé dans Nginx ?
  - Nginx reload, check proxy_pass

---

## 1️⃣1️⃣ Maintenance & Sécurité 🛡️

- 🔄 Renouvellement auto SSL :
  ```bash
  sudo systemctl enable certbot.timer
  sudo systemctl start certbot.timer
  ```
- 💾 Backup données et BDD :
  ```bash
  # Dump SQL
  sudo docker exec -t wikijs_db pg_dump -U wikijs wiki > backup.sql
  # Données pages/uploads
  sudo tar czvf backup-wikijs-$(date +%F).tar.gz /opt/wikijs/data
  ```
- ⬆️ Mise à jour :
  ```bash
  cd /opt/wikijs
  sudo docker-compose pull
  sudo docker-compose up -d
  ```
- 📖 Logs utiles :
  ```bash
  sudo docker logs wikijs
  sudo tail -f /var/log/nginx/error.log
  ```

---

## 1️⃣2️⃣ Glossaire

- 🌐 **Reverse Proxy** : intermédiaire HTTP/HTTPS, protège et distribue le trafic.
- 🔒 **SSL/TLS** : chiffrement HTTPS
- 🐳 **Docker** : conteneurisation légère
- 🥚 **Certbot** : gestionnaire automatique de certificats Let's Encrypt
- 🛢️ **PostgreSQL** : base de données relationnelle
- 🧰 **Wiki.js** : moteur de documentation wiki moderne

---

Prêt pour du self-hosting pro 🎯 !
