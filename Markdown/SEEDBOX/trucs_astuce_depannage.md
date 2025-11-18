# 🛠️ Astuces & Dépannage

## 🔧 Astuces de configuration avancée

### ⚙️ Tuning des performances qBittorrent

#### 1. Augmenter les limites du système

```bash
# Voir les limites actuelles
ulimit -a

# Modifier dans /etc/security/limits.conf
sudo nano /etc/security/limits.conf

# Ajouter à la fin :
qbittorrent-nox soft nofile 65535
qbittorrent-nox hard nofile 65535
qbittorrent-nox soft nproc 32768
qbittorrent-nox hard nproc 32768
```

**Pourquoi ?** Permet à qBittorrent d'ouvrir plus de connexions réseau simultanément.

#### 2. Optimiser les paramètres de connexion

Dans qBittorrent WebUI (`Outils` → `Options` → `Connexion`) :

- **Nombre de connexions simultanées** : 5000+ (selon RAM disponible)
- **Connexions par torrent** : 500+
- **Nombre de seeds simultanées** : 10+
- **Ports d'écoute** : 54321-54330 (plage de 10 ports)

#### 3. Configuration réseau avancée

```bash
# Vérifier le buffer TCP
cat /proc/sys/net/core/rmem_max
cat /proc/sys/net/core/wmem_max

# Augmenter les buffers (à ajouter dans /etc/sysctl.conf)
sudo nano /etc/sysctl.conf

# Ajouter :
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 65536 134217728

# Appliquer
sudo sysctl -p
```

---

### 🔒 Sécurité avancée Fail2Ban

#### 1. Intégration avec Cloudflare

Si vous utilisez Cloudflare, Fail2Ban peut bannir les IPs au niveau Cloudflare :

**Créer `/etc/fail2ban/action.d/cloudflare.local` :**

```ini
[Definition]
actionstart = 
actionstop = 
actioncheck = 
actionban = curl -X POST "https://api.cloudflare.com/client/v4/zones/<ZONE_ID>/firewall/access_rules/rules" \
  -H "X-Auth-Email: <EMAIL>" \
  -H "X-Auth-Key: <API_KEY>" \
  -H "Content-Type: application/json" \
  --data '{"mode":"block","configuration":{"target":"ip","value":"<HOST>"},"notes":"Fail2Ban"}'

actionunban = curl -X DELETE "https://api.cloudflare.com/client/v4/zones/<ZONE_ID>/firewall/access_rules/rules?configuration.target=ip&configuration.value=<HOST>" \
  -H "X-Auth-Email: <EMAIL>" \
  -H "X-Auth-Key: <API_KEY>"
```

**Utiliser dans la jail :**

```ini
[qbittorrent]
action = cloudflare[email=your@email.com, api_key=YOUR_API_KEY, zone_id=YOUR_ZONE_ID]
```

#### 2. Alertes email avancées

**Créer `/etc/fail2ban/action.d/sendmail-qbittorrent.conf` :**

```ini
[Definition]
actionstart = echo "qBittorrent Fail2Ban started" | mail -s "[Fail2Ban] qBittorrent started" <dest>
actionstop = echo "qBittorrent Fail2Ban stopped" | mail -s "[Fail2Ban] qBittorrent stopped" <dest>
actionban = echo "IP <HOST> banned after <failures> attempts" | mail -s "[Fail2Ban] Ban: <HOST>" <dest>
actionunban = echo "IP <HOST> unbanned" | mail -s "[Fail2Ban] Unban: <HOST>" <dest>
```

#### 3. Augmenter progressivement le ban (recidive)

```ini
[DEFAULT]
# Première infraction : 30 min
# Deuxième infraction : 1 heure (×2)
# Troisième infraction : 2 heures (×4)
bantime.increment = true
bantime.factor = 2
```

---

### 🌐 Nginx : Configurations avancées

#### 1. Compression et Cache

Ajouter au bloc `server` :

```nginx
# Compression Gzip
gzip on;
gzip_vary on;
gzip_min_length 1000;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

# Cache des ressources statiques
location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

#### 2. Limite de débit (Rate Limiting)

```nginx
# Définir les limites
limit_req_zone $binary_remote_addr zone=qbt_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m;

server {
    # Appliquer aux endpoints sensibles
    location /api/v2/auth/login {
        limit_req zone=login_limit burst=5 nodelay;
        proxy_pass http://127.0.0.1:8080;
    }
    
    location / {
        limit_req zone=qbt_limit burst=20 nodelay;
        proxy_pass http://127.0.0.1:8080;
    }
}
```

#### 3. Authentification Basic + Fail2Ban

```nginx
# Activer authentification HTTP Basic
location / {
    auth_basic "qBittorrent Access";
    auth_basic_user_file /etc/nginx/.htpasswd;
    proxy_pass http://127.0.0.1:8080;
}
```

Créer le fichier `.htpasswd` :

```bash
sudo apt install apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd admin
```

---

### 🚀 iptables : Règles avancées

#### 1. Gestion des états de connexion

```bash
# Voir les connexions établies
sudo conntrack -L | head -20

# Limiter les connexions NEW par IP
sudo iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 10 -j REJECT

# Limiter les connexions simultanées SSH
sudo iptables -A INPUT -p tcp --dport 22 -m connlimit --connlimit-above 5 -j REJECT
```

#### 2. Rate Limiting au niveau firewall

```bash
# Maximum 10 paquets par seconde sur SSH
sudo iptables -A INPUT -p tcp --dport 22 -m limit --limit 10/s --limit-burst 20 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j DROP
```

#### 3. Port Knocking (Sécurité avancée)

```bash
# Installer knockd
sudo apt install knockd

# Configuration dans /etc/knockd.conf :
sudo nano /etc/knockd.conf
```

```ini
[options]
        LogFile = /var/log/knockd.log

[SSH]
        sequence    = 7000,8000,9000
        seq_timeout = 5
        command     = /sbin/iptables -A INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
        tcpflags    = syn

[SSH_CLOSE]
        sequence    = 9000,8000,7000
        seq_timeout = 5
        command     = /sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
        tcpflags    = syn
```

Utilisation :

```bash
knock -v serveur.com 7000 8000 9000
ssh user@serveur.com  # Maintenant possible
```

---

## 🔍 Dépannage en détail

### ❌ Problème : qBittorrent ne démarre pas

**Symptôme :** Service échoue au démarrage

**Diagnostic :**

```bash
# Voir l'erreur complète
sudo journalctl -u qbittorrent-nox -n 100 -p err

# Ou directement
sudo -u qbittorrent-nox /usr/bin/qbittorrent-nox --webui-port=8080 --profile=/etc/qbittorrent

# Vérifier les permissions
ls -la /etc/qbittorrent/
ls -la /mnt/torrents/
```

**Solutions :**

1. **Permissions manquantes :**
   ```bash
   sudo chown -R qbittorrent-nox:qbittorrent-nox /etc/qbittorrent
   sudo chmod 750 /etc/qbittorrent
   ```

2. **Port déjà utilisé :**
   ```bash
   sudo lsof -i :8080
   sudo netstat -tulpn | grep 8080
   ```

3. **Configuration corrompue :**
   ```bash
   # Sauvegarder l'ancienne config
   sudo cp -r /etc/qbittorrent /etc/qbittorrent.backup
   
   # Réinitialiser
   sudo rm -rf /etc/qbittorrent/*
   
   # Redémarrer qBittorrent
   sudo systemctl restart qbittorrent-nox
   ```

---

### ❌ Problème : Fail2Ban n'emprisonne rien

**Symptôme :** Même après plusieurs tentatives échouées, l'IP n'est pas bloquée

**Diagnostic :**

```bash
# Vérifier que le filtre correspond aux logs
sudo fail2ban-regex /var/log/qbittorrent/qbittorrent.log /etc/fail2ban/filter.d/qbittorrent.conf -v

# Tester le filtre avec un exemple
echo '2024-11-18 12:00:00 WARN WebAPI login failure. Reason: invalid credentials, attempt count: 1, IP ::ffff:192.168.1.100' | \
sudo fail2ban-regex --verbose - /etc/fail2ban/filter.d/qbittorrent.conf
```

**Solutions :**

1. **Regex incorrecte :**
   ```ini
   # Test différents patterns
   failregex = ^.* WebAPI login failure.*IP: <HOST>
               ^.* Authentication failed.*<HOST>
               ^.* \d+ failed login attempts.*<HOST>
   ```

2. **Fichier log inexistant :**
   ```bash
   # Vérifier le chemin
   ls -la /var/log/qbittorrent/

   # Créer si nécessaire
   sudo touch /var/log/qbittorrent/qbittorrent.log
   sudo chown qbittorrent-nox:qbittorrent-nox /var/log/qbittorrent/qbittorrent.log
   ```

3. **Jail non activée :**
   ```bash
   sudo fail2ban-client status qbittorrent
   sudo fail2ban-client set qbittorrent enabled
   ```

---

### ❌ Problème : Nginx retourne erreur 502 Bad Gateway

**Symptôme :** Connexion refusée lors de l'accès à `qbittorrent.exemple.com`

**Diagnostic :**

```bash
# Vérifier les logs Nginx
sudo tail -50 /var/log/nginx/error.log
sudo tail -50 /var/log/nginx/access.log

# Vérifier que qBittorrent écoute
sudo ss -tlnp | grep 8080
netstat -tulpn | grep 8080

# Tester la connexion locale
curl -v http://127.0.0.1:8080
```

**Solutions :**

1. **qBittorrent n'écoute pas sur 8080 :**
   ```bash
   sudo systemctl restart qbittorrent-nox
   sleep 2
   sudo ss -tlnp | grep qbittorrent
   ```

2. **Firewall bloque localhost :**
   ```bash
   # Vérifier les règles iptables
   sudo iptables -L -n | grep 8080
   
   # Ajouter si manquant
   sudo iptables -I INPUT -p tcp -d 127.0.0.1 --dport 8080 -j ACCEPT
   ```

3. **Nginx n'a pas la permission de se connecter :**
   ```bash
   # Redémarrer Nginx en debug
   sudo nginx -T  # Voir la configuration
   sudo systemctl restart nginx
   ```

---

### ❌ Problème : Connexion HTTPS échouée

**Symptôme :** `https://qbittorrent.exemple.com` non accessible

**Diagnostic :**

```bash
# Vérifier le certificat
sudo certbot certificates

# Tester la connexion SSL
openssl s_client -connect qbittorrent.exemple.com:443

# Voir les erreurs Nginx
sudo journalctl -u nginx -f
```

**Solutions :**

1. **Certificat expiré :**
   ```bash
   sudo certbot renew --force-renewal
   sudo systemctl reload nginx
   ```

2. **DNS ne résout pas :**
   ```bash
   nslookup qbittorrent.exemple.com
   dig qbittorrent.exemple.com
   ```

3. **Port 443 bloqué :**
   ```bash
   sudo iptables -I INPUT 1 -p tcp --dport 443 -j ACCEPT
   sudo netfilter-persistent save
   ```

---

### ❌ Problème : iptables règles disparaissent après reboot

**Symptôme :** Les règles iptables ne persistent pas après un redémarrage

**Diagnostic :**

```bash
# Vérifier si iptables-persistent est installé
sudo dpkg -l | grep persistent

# Voir les fichiers de règles
ls -la /etc/iptables/
```

**Solutions :**

1. **Installer et activer iptables-persistent :**
   ```bash
   sudo apt install -y iptables-persistent
   sudo netfilter-persistent save
   sudo netfilter-persistent enable
   ```

2. **Script de démarrage alternatif :**
   ```bash
   sudo nano /etc/network/if-pre-up.d/firewall
   ```
   
   Ajouter :
   ```bash
   #!/bin/bash
   /sbin/iptables-restore < /etc/iptables/rules.v4
   ```
   
   Puis :
   ```bash
   sudo chmod +x /etc/network/if-pre-up.d/firewall
   ```

---

### ❌ Problème : Trafic BitTorrent très lent

**Symptôme :** Vitesses de téléchargement très faibles

**Diagnostic :**

```bash
# Vérifier la connexion réseau
iperf -c serveur.com

# Voir les connexions BitTorrent actives
sudo ss -an | grep ESTABLISHED | wc -l

# Vérifier la bande passante utilisée
nethogs

# Voir les logs qBittorrent
sudo journalctl -u qbittorrent-nox | grep -i speed
```

**Solutions :**

1. **Augmenter les limites de connexion :**
   ```bash
   # Dans qBittorrent : Connexion → Nombre max de connexions : 5000
   # Dans iptables : Pas d'autre règle ne bloque les ports
   ```

2. **Vérifier les limites du système :**
   ```bash
   ulimit -n  # Devrait être ≥ 4096
   cat /proc/sys/net/core/somaxconn
   ```

3. **Optimiser TCP :**
   ```bash
   sudo sysctl -w net.ipv4.tcp_tw_reuse=1
   sudo sysctl -w net.ipv4.tcp_fin_timeout=30
   ```

---

### ⚡ Commandes de monitoring utiles

```bash
# Ressources en temps réel
watch -n 1 'ps aux | grep qbittorrent-nox'

# Connexions réseau
watch -n 1 'ss -an | grep ESTABLISHED | wc -l'

# Bande passante
iftop -i eth0

# Logs en temps réel (tous les services)
sudo journalctl -f

# État Fail2Ban
watch -n 2 'sudo fail2ban-client status'

# Règles iptables
sudo iptables -L -v -n | less
```

---

## 📝 Checklist de maintenance mensuelle

- [ ] Vérifier les mises à jour : `sudo apt update && apt list --upgradable`
- [ ] Vérifier l'espace disque : `df -h`
- [ ] Voir les IPs bannies : `sudo fail2ban-client status qbittorrent`
- [ ] Vérifier les logs d'erreur : `sudo journalctl -p err -n 50`
- [ ] Tester le certificat SSL : `sudo certbot renew --dry-run`
- [ ] Reboot de test : `sudo reboot` puis vérifier que tout redémarre
- [ ] Analyser l'utilisation des ressources : `top`, `htop`, `nethogs`

---

## 🎓 Ressources d'apprentissage

- **qBittorrent** : https://doc.qbittorrent.org/
- **Fail2Ban** : https://fail2ban.readthedocs.io/
- **iptables** : https://linux.die.net/man/8/iptables
- **Nginx** : https://nginx.org/en/docs/
- **Let's Encrypt** : https://letsencrypt.org/
