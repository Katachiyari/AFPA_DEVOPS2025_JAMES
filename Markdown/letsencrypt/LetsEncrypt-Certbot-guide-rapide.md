# Let's Encrypt + Certbot - SSL/TLS Sécurisé
## Guide Rapide - Démarrage Immédiat

---

## ⚡ Installation (5 minutes)

### Installation Certbot

```bash
# 1. Installer Certbot et plugins
sudo apt update
sudo apt install -y certbot python3-certbot-nginx python3-certbot-apache

# 2. Installer plugin supplémentaire (DNS si wildcard)
sudo apt install -y python3-certbot-dns-cloudflare

# 3. Vérifier l'installation
certbot --version
certbot plugins
```

### Prérequis

```bash
# 1. Domaine accessible publiquement
ping exemple.com

# 2. Horloge système correcte (critique pour ACME)
timedatectl status

# 3. Port 80/443 accessibles
sudo ss -tlnp | grep -E ":80|:443"

# 4. Serveur web configuré
sudo systemctl status nginx
# ou
sudo systemctl status apache2
```

---

## 🚀 Premier Certificat (Une Commande)

### Avec Nginx

```bash
# Certbot va auto-configurer Nginx
sudo certbot --nginx \
  -d exemple.com \
  -d www.exemple.com \
  --agree-tos \
  -m admin@exemple.com \
  --no-eff-email
```

### Avec Apache

```bash
# Certbot va auto-configurer Apache
sudo certbot --apache \
  -d exemple.com \
  -d www.exemple.com \
  --agree-tos \
  -m admin@exemple.com \
  --no-eff-email
```

### Mode Standalone (Sans Serveur Web)

```bash
# Certbot utilise port 80 directement
sudo certbot certonly --standalone \
  -d exemple.com \
  -d www.exemple.com \
  --agree-tos \
  -m admin@exemple.com
```

---

## ✅ Vérifier le Certificat

```bash
# 1. Vérifier installation
sudo certbot certificates

# 2. Tester la connexion SSL
openssl s_client -connect exemple.com:443 -servername exemple.com

# 3. Vérifier la date d'expiration
openssl x509 -in /etc/letsencrypt/live/exemple.com/cert.pem -noout -dates

# 4. Navigateur : visiter https://exemple.com
```

---

## 🔒 Configuration Nginx ANSSI-Compliant

```bash
# Certbot modifie automatiquement Nginx
# Mais vérifier la configuration :

sudo nano /etc/nginx/sites-available/exemple.com
```

**À vérifier** :
```nginx
# TLS Versions
ssl_protocols TLSv1.3 TLSv1.2;

# Certificat fullchain (IMPORTANT)
ssl_certificate /etc/letsencrypt/live/exemple.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/exemple.com/privkey.pem;

# Redirection HTTP → HTTPS
location / {
    return 301 https://$server_name$request_uri;
}

# HSTS (Force HTTPS)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
```

Tester et recharger :
```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 🔄 Renouvellement Automatique

### Vérifier Status Systemd

```bash
# Certbot configure le timer automatiquement

sudo systemctl status certbot.timer
sudo systemctl list-timers | grep certbot

# Doit montrer : active (running)
```

### Tester le Renouvellement

```bash
# Dry-run : simule renouvellement sans faire réellement
sudo certbot renew --dry-run

# Si succès : renouvellement automatisé fonctionne
```

### Cron Fallback (Si systemd inactive)

```bash
# Ajouter à crontab
sudo crontab -e

# Ligne à ajouter :
30 2 * * * /usr/bin/certbot renew --quiet && systemctl reload nginx
```

---

## 📋 Checklist Déploiement

- [ ] Certbot installé (`certbot --version`)
- [ ] Domaine public et accessible
- [ ] Ports 80/443 ouverts
- [ ] Serveur web (Nginx/Apache) configuré
- [ ] Certificat généré (première commande)
- [ ] HTTPS fonctionne (https://exemple.com)
- [ ] HTTP → HTTPS redirection active
- [ ] Certificat valide dans navigateur (pas d'erreur)
- [ ] Renouvellement automatisé actif (`certbot.timer`)
- [ ] Alertes avant expiration configurées (optionnel)

---

## 🔐 Montage Wildcard (DNS-01)

```bash
# 1. Installer plugin CloudFlare
sudo apt install -y python3-certbot-dns-cloudflare

# 2. Créer fichier credentials
sudo nano ~/.cloudflare.ini

# Contenu :
# dns_cloudflare_email = user@exemple.com
# dns_cloudflare_api_key = YOUR_API_KEY

# 3. Permissions restrictives
sudo chmod 600 ~/.cloudflare.ini

# 4. Générer certificat wildcard
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/.cloudflare.ini \
  -d exemple.com \
  -d "*.exemple.com" \
  --agree-tos \
  -m admin@exemple.com
```

---

## 🆘 Dépannage Rapide

| Problème | Solution |
|----------|----------|
| "Connection refused" | Vérifier port 80 accessible : `sudo ss -tlnp \| grep :80` |
| "Validation failed" | Vérifier DNS résout : `nslookup exemple.com` |
| "File not found" | Certificat non encore créé, lancer d'abord `certbot` |
| "Permission denied" | Exécuter avec `sudo` |
| "Port 80 busy" | Arrêter Apache/Nginx d'abord : `sudo systemctl stop nginx` |
| Certificat ne renouvelle pas | Tester : `sudo certbot renew --dry-run` |

---

## 📊 Commandes Essentielles

```bash
# Lister certificats
sudo certbot certificates

# Renouveller tous les certificats
sudo certbot renew

# Renouveler certificat spécifique
sudo certbot renew --cert-name exemple.com

# Supprimer certificat
sudo certbot delete --cert-name exemple.com

# Révoquer certificat (urgence)
sudo certbot revoke --cert-path /etc/letsencrypt/live/exemple.com/cert.pem

# Modifier configuration
sudo certbot --cert-name exemple.com -d exemple.com -d www.exemple.com -d new.exemple.com

# Vérifier expiration
sudo certbot certificates
```

---

## 🔍 Vérifier Configuration TLS

```bash
# 1. Afficher détails certificat
openssl x509 -in /etc/letsencrypt/live/exemple.com/cert.pem -noout -text | head -20

# 2. Vérifier protocole TLS
openssl s_client -connect exemple.com:443 -tls1_3 </dev/null 2>&1 | grep "Protocol"

# 3. Vérifier cipher suites
openssl s_client -connect exemple.com:443 </dev/null 2>&1 | grep "Cipher"

# 4. Vérifier chaîne certificat
openssl s_client -connect exemple.com:443 -showcerts </dev/null 2>&1 | grep "i:"
```

---

**Guide rapide - Pour démarrage immédiat**
**Voir Guide Complet pour détails ANSSI et concepts avancés**
