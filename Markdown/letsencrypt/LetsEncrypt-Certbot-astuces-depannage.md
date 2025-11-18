# Let's Encrypt + Certbot - Astuces, Dépannage et Solutions Avancées

---

## 🛠️ Astuces Pratiques

### Alias Bash pour Certbot

```bash
# Ajouter à ~/.bashrc

alias certbot-list="sudo certbot certificates"
alias certbot-renew-test="sudo certbot renew --dry-run"
alias certbot-renew-now="sudo certbot renew --force-renewal"
alias ssl-check="openssl s_client -connect"
alias ssl-expiry="sudo certbot certificates"

# Utilisation
certbot-list
certbot-renew-test
ssl-check exemple.com:443
```

### Fonction Bash : Vérifier Expiration

```bash
# Ajouter à ~/.bashrc

cert-expiry() {
    local domain="${1:?Usage: cert-expiry <domain>}"
    local cert_file="/etc/letsencrypt/live/$domain/cert.pem"
    
    if [ ! -f "$cert_file" ]; then
        echo "[!] Certificat pour $domain non trouvé"
        return 1
    fi
    
    # Date d'expiration
    local expiry=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry" +%s)
    local now_epoch=$(date +%s)
    local days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))
    
    if [ $days_left -lt 0 ]; then
        echo "[✗] Certificat $domain EXPIRÉ"
        return 1
    elif [ $days_left -lt 7 ]; then
        echo "[✗] Certificat $domain expire dans $days_left jours (URGENT)"
        return 1
    elif [ $days_left -lt 30 ]; then
        echo "[!] Certificat $domain expire dans $days_left jours (ATTENTION)"
        return 0
    else
        echo "[✓] Certificat $domain valide pour $days_left jours"
        return 0
    fi
}

# Utilisation
cert-expiry exemple.com
```

### Multi-Domaines dans Une Commande

```bash
#!/bin/bash
# Créer certificat pour plusieurs domaines

domains=(
    "exemple.com"
    "www.exemple.com"
    "api.exemple.com"
    "admin.exemple.com"
)

# Construire les arguments -d
domain_args=""
for domain in "${domains[@]}"; do
    domain_args="$domain_args -d $domain"
done

# Générer certificat
sudo certbot certonly --nginx $domain_args --agree-tos -m admin@exemple.com

# Ou si déjà existant, ajouter domaines
sudo certbot --cert-name exemple.com $domain_args
```

### Certificats Multiples pour Différents Services

```bash
# Certificat pour API (ports spécifiques)
sudo certbot certonly --standalone \
  -d api.exemple.com \
  --standalone-supported-challenges http-01 \
  --cert-name api-exemple \
  --agree-tos -m admin@exemple.com

# Certificat pour Mail server
sudo certbot certonly --standalone \
  -d mail.exemple.com \
  --standalone-supported-challenges http-01 \
  --cert-name mail-exemple \
  --agree-tos -m admin@exemple.com

# Lister tous
sudo certbot certificates
```

### Renouvellement Forcé (Test ou Debug)

```bash
# Renouveller même si certificat valide
sudo certbot renew --force-renewal

# Renouveller certificat spécifique
sudo certbot renew --cert-name exemple.com --force-renewal

# Avec verbose pour debug
sudo certbot renew --verbose --force-renewal
```

---

## 🔍 Dépannage Détaillé

### Problème 1 : "Connection refused" ou Validation Échoue

#### Diagnostic Complet

```bash
# 1. Vérifier accès HTTP
curl -v http://exemple.com/.well-known/acme-challenge/test

# 2. Vérifier DNS résout
nslookup exemple.com
dig exemple.com +short

# 3. Vérifier ports ouverts (local)
sudo ss -tlnp | grep -E ":80|:443"

# 4. Vérifier pare-feu externe
# Depuis autre machine :
curl -v http://VOTRE_IP/.well-known/acme-challenge/test

# 5. Vérifier redirection HTTP → HTTPS (attention)
curl -I http://exemple.com
# Si 301 directement vers HTTPS, Certbot ne peut pas valider

# 6. Logs détaillés Certbot
sudo certbot certonly --standalone -d exemple.com -vvv
# Chercher : "Waiting for verification" et "Cleaning up challenges"

# 7. Vérifier Let's Encrypt peut accéder
dig +short exemple.com | head -1 > /tmp/ip.txt
# Depuis un serveur externe, tester ping vers cette IP
```

#### Solutions

```bash
# ✓ Corriger redirection HTTP → HTTPS (Certbot doit utiliser HTTP)
# Dans Nginx, ajouter exception :
location /.well-known/acme-challenge/ {
    proxy_pass http://localhost:80;
}

# ✓ Ou arrêter serveur web pendant validation
sudo systemctl stop nginx
sudo certbot certonly --standalone -d exemple.com
sudo systemctl start nginx

# ✓ Vérifier horloge système (doit être précise)
sudo timedatectl set-ntp true
timedatectl status

# ✓ Vérifier zone DNS valide
dig NS exemple.com
# Doit retourner des nameservers valides

# ✓ Utiliser DNS-01 au lieu de HTTP-01 (si port 80 bloqué)
sudo certbot certonly --dns-cloudflare -d exemple.com
```

### Problème 2 : Certificat Pas Renouvelé Automatiquement

#### Diagnostic

```bash
# 1. Vérifier systemd timer
sudo systemctl status certbot.timer
sudo systemctl list-timers --all | grep certbot

# 2. Vérifier logs timer
sudo journalctl -u certbot.timer -n 50

# 3. Vérifier logs renouvellement
sudo journalctl -u certbot.service -n 50
sudo tail -100 /var/log/letsencrypt/letsencrypt.log

# 4. Test manuel renouvellement
sudo certbot renew --dry-run

# 5. Vérifier l'expiration actuelle
sudo certbot certificates
```

#### Solutions

```bash
# ✓ Activer timer s'il est inactive
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# ✓ Recharger systemd si modifié
sudo systemctl daemon-reload
sudo systemctl restart certbot.timer

# ✓ Forcer renouvellement manuel
sudo certbot renew --force-renewal

# ✓ Tester le dry-run
sudo certbot renew --dry-run

# ✓ Ajouter cron fallback
(sudo crontab -l 2>/dev/null; echo "0 3 * * * /usr/bin/certbot renew --quiet && systemctl reload nginx") | sudo crontab -

# ✓ Vérifier cron
sudo crontab -l | grep certbot
```

### Problème 3 : Certificat Mismatch ou Erreur SSL

#### Diagnostic

```bash
# 1. Afficher certificat sur serveur
openssl x509 -in /etc/letsencrypt/live/exemple.com/cert.pem -noout -text | head -30

# 2. Afficher certificat reçu par client
openssl s_client -connect exemple.com:443 -servername exemple.com < /dev/null | openssl x509 -noout -text | head -30

# 3. Comparer CN/SAN
openssl x509 -in /etc/letsencrypt/live/exemple.com/cert.pem -noout -text | grep -E "CN=|DNS:"

# 4. Vérifier chaîne complète
openssl s_client -connect exemple.com:443 -showcerts </dev/null | grep "i:" | head -5

# 5. Vérifier version TLS supportée
openssl s_client -connect exemple.com:443 -tls1_3 </dev/null 2>&1 | grep "Protocol"
openssl s_client -connect exemple.com:443 -tls1_2 </dev/null 2>&1 | grep "Protocol"

# 6. Vérifier fullchain utilisé (pas cert seul)
grep -i "certificate" /etc/nginx/sites-available/exemple.com | grep fullchain
```

#### Solutions

```bash
# ✓ Vérifier que fullchain.pem est utilisé (pas cert.pem)
sudo nano /etc/nginx/sites-available/exemple.com
# Doit être :
# ssl_certificate /etc/letsencrypt/live/exemple.com/fullchain.pem;

# ✓ Recharger serveur web
sudo systemctl reload nginx
sudo systemctl reload apache2

# ✓ Régénérer certificat si domaines changés
sudo certbot --cert-name exemple.com -d exemple.com -d www.exemple.com -d new.exemple.com --reinstall

# ✓ Vérifier symlinks
ls -la /etc/letsencrypt/live/exemple.com/
# fullchain.pem et privkey.pem doivent pointer vers archive

# ✓ Tester chaîne complète
openssl verify -CAfile /etc/letsencrypt/live/exemple.com/chain.pem \
  /etc/letsencrypt/live/exemple.com/cert.pem
```

### Problème 4 : Permissions ou Erreurs d'Accès

#### Diagnostic

```bash
# 1. Vérifier permissions certificat
ls -la /etc/letsencrypt/live/exemple.com/

# 2. Vérifier permissions clé privée
sudo ls -la /etc/letsencrypt/live/exemple.com/privkey.pem

# 3. Vérifier propriétaire
sudo stat -c "%U:%G %a" /etc/letsencrypt/live/exemple.com/privkey.pem

# 4. Vérifier accès Nginx
ps aux | grep nginx | grep -v grep | head -1

# 5. Vérifier logs erreurs
sudo tail -50 /var/log/nginx/error.log
sudo tail -50 /var/log/apache2/error.log
```

#### Solutions

```bash
# ✓ Corriger permissions (standard)
sudo chmod 755 /etc/letsencrypt/
sudo chmod 755 /etc/letsencrypt/live/
sudo chmod 755 /etc/letsencrypt/archive/
sudo chmod 600 /etc/letsencrypt/live/*/privkey.pem
sudo chmod 644 /etc/letsencrypt/live/*/fullchain.pem

# ✓ Permettre Nginx/Apache de lire
sudo usermod -aG ssl-cert www-data
# ou
sudo chgrp www-data /etc/letsencrypt/live/*/privkey.pem
sudo chmod 640 /etc/letsencrypt/live/*/privkey.pem

# ✓ Recharger services
sudo systemctl reload nginx
sudo systemctl reload apache2
```

### Problème 5 : Port Déjà Utilisé ou Erreur Installation

#### Diagnostic

```bash
# 1. Vérifier ports
sudo ss -tlnp | grep -E ":80|:443"

# 2. Voir tous les processus écoutant
sudo lsof -i -P -n | grep -E "LISTEN|:80|:443"

# 3. Vérifier Nginx/Apache
sudo systemctl status nginx
sudo systemctl status apache2

# 4. Vérifier autre Certbot en cours
ps aux | grep certbot
```

#### Solutions

```bash
# ✓ Arrêter serveur web avant validation
sudo systemctl stop nginx
sudo certbot certonly --standalone -d exemple.com
sudo systemctl start nginx

# ✓ Ou permettre à Nginx de continuer (mode webroot)
sudo certbot certonly --webroot \
  -w /var/www/html \
  -d exemple.com \
  -d www.exemple.com

# ✓ Terminer ancien Certbot
sudo pkill -9 certbot

# ✓ Utiliser port alternatif (avancé)
sudo certbot certonly --standalone --http-01-port 8080 \
  -d exemple.com
```

---

## 🔐 Sécurité Avancée

### Audit Certificat Complet

```bash
#!/bin/bash
# Audit tous les certificats

echo "=== AUDIT CERTIFICATS LET'S ENCRYPT ==="
echo ""

for cert_dir in /etc/letsencrypt/live/*/; do
    domain=$(basename "$cert_dir")
    cert_file="$cert_dir/cert.pem"
    
    echo "Domain: $domain"
    echo "---"
    
    # Dates
    expiry=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    days_left=$(( ( $(date -d "$expiry" +%s) - $(date +%s) ) / 86400 ))
    echo "  Expiration: $expiry ($days_left jours)"
    
    # Subject
    subject=$(openssl x509 -in "$cert_file" -noout -subject | cut -d= -f3)
    echo "  Subject: $subject"
    
    # Issuer
    issuer=$(openssl x509 -in "$cert_file" -noout -issuer | cut -d= -f3)
    echo "  Issuer: $issuer"
    
    # SANs
    echo "  Domaines :"
    openssl x509 -in "$cert_file" -noout -text | grep -oP 'DNS:\K[^,]*' | sed 's/^/    - /'
    
    # Type clé
    key_type=$(openssl pkey -in "$cert_dir/privkey.pem" -text -noout 2>/dev/null | head -1)
    echo "  Clé: $key_type"
    
    echo ""
done
```

### Monitoring Expiration Automatique

```bash
#!/bin/bash
# /usr/local/bin/cert-monitor.sh

THRESHOLD=30  # Jours avant alerte
ALERT_EMAIL="admin@exemple.com"
LOG_FILE="/var/log/cert-monitor.log"

for domain in $(sudo certbot certificates 2>/dev/null | grep "Certificate Name" | awk '{print $NF}'); do
    expiry=$(sudo openssl x509 -in /etc/letsencrypt/live/$domain/cert.pem -noout -enddate 2>/dev/null | cut -d= -f2)
    days_left=$(( ( $(date -d "$expiry" +%s) - $(date +%s) ) / 86400 ))
    
    if [ $days_left -lt 0 ]; then
        echo "[ERREUR] Certificat $domain EXPIRÉ" | tee -a "$LOG_FILE"
        echo "Certificat $domain a expiré !" | mail -s "ALERTE EXPIRÉ" "$ALERT_EMAIL"
    elif [ $days_left -lt $THRESHOLD ]; then
        echo "[ALERTE] Certificat $domain expire dans $days_left jours" | tee -a "$LOG_FILE"
        echo "Certificat $domain expire dans $days_left jours" | mail -s "ALERTE EXPIRATION" "$ALERT_EMAIL"
    fi
done

# Planifier avec cron
# 0 8 * * * /usr/local/bin/cert-monitor.sh
```

### Backup Sécurisé Certificats

```bash
#!/bin/bash
# Sauvegarder certificats chiffrés

BACKUP_DIR="/backup/letsencrypt"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
GPG_RECIPIENT="admin@exemple.com"

mkdir -p "$BACKUP_DIR"

# 1. Archiver
sudo tar czf /tmp/letsencrypt_$BACKUP_DATE.tar.gz /etc/letsencrypt/

# 2. Chiffrer
sudo gpg --encrypt --recipient "$GPG_RECIPIENT" /tmp/letsencrypt_$BACKUP_DATE.tar.gz

# 3. Transférer
sudo mv /tmp/letsencrypt_$BACKUP_DATE.tar.gz.gpg "$BACKUP_DIR/"

# 4. Nettoyer
sudo rm -f /tmp/letsencrypt_$BACKUP_DATE.tar.gz

# 5. Vérifier
sudo gpg --list-only "$BACKUP_DIR/letsencrypt_$BACKUP_DATE.tar.gz.gpg"

echo "Backup chiffré : $BACKUP_DIR/letsencrypt_$BACKUP_DATE.tar.gz.gpg"

# Restauration :
# gpg -d letsencrypt_YYYYMMDD.tar.gz.gpg | tar xzf -
```

---

## 📊 Checklists Spécialisées

### Checklist Déploiement Production

- [ ] Domaine public et DNS configuré
- [ ] Ports 80/443 accessibles (pas de pare-feu bloquant)
- [ ] Horloge système synchronisée (NTP)
- [ ] Serveur web (Nginx/Apache) fonctionnel
- [ ] Certificat généré avec succès
- [ ] HTTPS fonctionne sans erreur navigateur
- [ ] HTTP → HTTPS redirection active
- [ ] Certificat fullchain utilisé (pas cert seul)
- [ ] Renouvellement automatisé activé
- [ ] Test renouvellement dry-run réussi
- [ ] TLS 1.3 supporté et activé
- [ ] Cipher suites modernes configurés
- [ ] HSTS header activé
- [ ] Monitoring expiration configuré
- [ ] Alertes avant expiration actives
- [ ] Backups sécurisés certificats
- [ ] Logs audit centralisés
- [ ] Documentation runbook complète

### Checklist Sécurité ANSSI

- [ ] TLS 1.3 minimum supporté
- [ ] TLS 1.2 activé (fallback)
- [ ] SSL 3.0, TLS 1.0, 1.1 désactivés
- [ ] Suites de chiffrement modernes uniquement
- [ ] Perfect Forward Secrecy (ECDHE) activé
- [ ] Clé privée permissions 600 (root:root)
- [ ] Certificat public permissions 644
- [ ] Renouvellement automatisé < 90 jours
- [ ] HSTS activé (max-age ≥ 31536000)
- [ ] OCSP Stapling activé
- [ ] Chaîne certificat complète vérifiée
- [ ] Audit logs complets
- [ ] Révocation processus documenté
- [ ] Backup clés privées chiffrées

---

## 💡 Tips & Tricks Avancés

### Certificat Wildcard Multi-Niveaux

```bash
# Créer wildcard pour tous niveaux
sudo certbot certonly --dns-cloudflare \
  -d exemple.com \
  -d "*.exemple.com" \
  -d "*.*.exemple.com" \
  --agree-tos -m admin@exemple.com

# Attention : chaque niveau nécessite validation
```

### Migrer vers Autre CA

```bash
# Exporter certificat Let's Encrypt actuel
sudo openssl x509 -in /etc/letsencrypt/live/exemple.com/cert.pem -outform PEM

# Générer nouveau chez autre CA
# ...

# Importer et configurer serveur web
# Puis supprimer ancien Certbot
sudo certbot delete --cert-name exemple.com
```

### Certificat pour Mail Server

```bash
# SMTP/IMAP/POP3
sudo certbot certonly --standalone \
  -d mail.exemple.com \
  -d smtp.exemple.com \
  -d imap.exemple.com \
  --cert-name mail-exemple \
  --agree-tos -m admin@exemple.com

# Configurer Postfix/Dovecot
# /etc/postfix/main.cf :
# smtpd_tls_cert_file = /etc/letsencrypt/live/mail-exemple/fullchain.pem
# smtpd_tls_key_file = /etc/letsencrypt/live/mail-exemple/privkey.pem

# Script post-renouvellement
# /etc/letsencrypt/renewal-hooks/post/dovecot-postfix.sh :
#!/bin/bash
systemctl reload dovecot
systemctl reload postfix
```

---

**Document pratique - Mise à jour 17 novembre 2025**
**Pour questions avancées : Consulter Guide Complet ou documentation Let's Encrypt**
