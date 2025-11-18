# 🛠️ Trucs, Astuces & Dépannage WireGuard Docker

## 🐛 Problèmes courants et solutions

### ❌ Le conteneur ne démarre pas

**Symptôme :**
```
ERROR: for wireguard Cannot start service wireguard: error while creating mount source path
```

**Cause :** Répertoires n'existent pas ou permissions incorrectes

**Solution :**
```bash
# Vérifier l'existence des répertoires
ls -la /opt/wireguard-docker/

# Créer s'ils manquent
sudo mkdir -p /opt/wireguard-docker/config
sudo mkdir -p /opt/wireguard-docker/custom-init

# Fixer les permissions
sudo chown -R 1000:1000 /opt/wireguard-docker
sudo chmod -R 755 /opt/wireguard-docker

# Redémarrer
docker-compose down
docker-compose up -d
```

---

### ❌ Port 51820 déjà en utilisation

**Symptôme :**
```
ERROR: Ports are not available: exposing port UDP 0.0.0.0:51820 -> 0.0.0.0:51820
```

**Cause :** Un autre processus utilise le port

**Diagnostic :**
```bash
# Trouver ce qui utilise le port
sudo lsof -i :51820
# Ou
sudo ss -tulpn | grep 51820

# Tuer le processus (si c'est un ancien conteneur)
docker kill wireguard
docker rm wireguard

# Ou utiliser un port différent
# Dans docker-compose.yml, changer 51820:51820/udp en 51821:51820/udp
```

---

### ❌ Les clients ne peuvent pas se connecter

**Symptôme :**
```
Cannot connect to server
WireGuard: Handshake did not complete
```

**Checklist :**
```bash
# 1. Vérifier le port écoute
sudo ss -tulpn | grep 51820
# Doit afficher : LISTEN 0 0 0.0.0.0:51820 0.0.0.0:* users:(("docker-proxy",pid=XXXX,fd=4))

# 2. Vérifier le pare-feu externe
# Si vous avez un firewall OVH, vérifier les règles de sécurité

# 3. Vérifier l'IP dans la config client
cat /opt/wireguard-docker/config/wg_confs/peer1/peer1.conf
# Endpoint doit être : 54.38.193.46:51820

# 4. Vérifier les droits du conteneur
docker inspect wireguard | grep -A 20 CapAdd

# 5. Tester depuis le serveur lui-même
docker exec wireguard wg show
```

**Solution :**
```bash
# 1. Vérifier la config serveur
docker exec wireguard cat /config/wg0.conf

# 2. Redémarrer le conteneur
docker-compose restart wireguard

# 3. Forcer la regénération des configs
docker-compose down
rm -rf /opt/wireguard-docker/config/wg0.conf
docker-compose up -d
```

---

### ❌ Pas de connectivité internet via VPN

**Symptôme :**
```
Connecté au VPN mais impossible d'accéder à internet
curl: Failed to connect to google.com
```

**Cause :** Règles iptables NAT manquantes ou incorrectes

**Diagnostic :**
```bash
# Vérifier les règles NAT
sudo iptables -t nat -L -n -v

# Vérifier le forwarding IP
sysctl net.ipv4.ip_forward
# Doit afficher : net.ipv4.ip_forward = 1

# Vérifier les routes
ip route show

# Tester la connectivité interne
docker exec wireguard ping -c 2 10.13.13.1
```

**Solution :**
```bash
# Activer le forwarding IP
sudo sysctl -w net.ipv4.ip_forward=1

# Persister au redémarrage
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Ajouter les règles NAT
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE

# Sauvegarder
sudo netfilter-persistent save

# Redémarrer les conteneurs
docker-compose down
docker-compose up -d
```

---

### ❌ fail2ban bannit l'IP du client VPN

**Symptôme :**
```
VPN connecté mais pas d'accès aux services
fail2ban a banni l'IP
```

**Cause :** Les règles fail2ban sont trop agressives ou mal configurées

**Diagnostic :**
```bash
# Voir les IPs bannies
sudo fail2ban-client status

# Voir la jail spécifique
sudo fail2ban-client status wireguard

# Voir les règles iptables
sudo iptables -L fail2ban-wireguard -n

# Voir les logs
sudo tail -f /var/log/fail2ban.log | grep wireguard
```

**Solutions :**

**Option 1 : Débannir une IP manuellement**
```bash
# Débannir une IP spécifique
sudo fail2ban-client set wireguard unbanip 10.13.13.2

# Débannir toutes les IPs
sudo iptables -F fail2ban-wireguard
```

**Option 2 : Modifier la configuration fail2ban**
```bash
# Éditer la jail
sudo nano /etc/fail2ban/jail.d/wireguard.local

# Augmenter les paramètres :
# maxretry = 20 (au lieu de 10)
# findtime = 3600 (au lieu de 600)

# Redémarrer
sudo systemctl restart fail2ban
```

**Option 3 : Whitelister l'IP du client**
```bash
# Ajouter à fail2ban
sudo nano /etc/fail2ban/jail.d/wireguard.local

# Au-dessus de [wireguard], ajouter :
[DEFAULT]
ignoreip = 127.0.0.1/8 10.13.13.0/24
```

---

### ❌ Les configurations client ne se génèrent pas

**Symptôme :**
```
Le dossier wg_confs est vide ou absent
```

**Cause :** Le conteneur n'a pas terminé son initialisation

**Diagnostic :**
```bash
# Vérifier les logs
docker-compose logs wireguard | grep -i "peer\|config"

# Attendre un peu
sleep 60
ls -la /opt/wireguard-docker/config/wg_confs/

# Vérifier l'espace disque
df -h /opt/wireguard-docker/
```

**Solution :**
```bash
# Forcer la regénération
docker-compose down
rm -rf /opt/wireguard-docker/config/*
docker-compose up -d
sleep 120  # Attendre l'initialisation
ls /opt/wireguard-docker/config/wg_confs/
```

---

## ⚡ Astuces de performance et sécurité

### 1️⃣ Optimiser la taille du subnet

**Situation actuelle :**
```yaml
INTERNAL_SUBNET: 10.13.13.0/24  # Permet 254 clients
```

**Pour plus de clients :**
```yaml
# Subnet /22 = 1022 clients
INTERNAL_SUBNET: 10.13.12.0/22

# Subnet /21 = 2046 clients
INTERNAL_SUBNET: 10.13.8.0/21
```

**Modification :**
```bash
nano /opt/wireguard-docker/docker-compose.yml
# Changer la valeur INTERNAL_SUBNET
docker-compose down
rm -rf /opt/wireguard-docker/config/wg*.conf
docker-compose up -d
```

---

### 2️⃣ Augmenter le nombre de clients autorisés

**Configuration actuelle :**
```yaml
PEERS: 3  # 3 configurations générées
```

**Augmenter à 10 :**
```bash
# Éditer le docker-compose.yml
sed -i 's/PEERS: 3/PEERS: 10/' /opt/wireguard-docker/docker-compose.yml

# Appliquer le changement
docker-compose down
docker-compose up -d
sleep 30

# Vérifier les nouvelles configs
ls -la /opt/wireguard-docker/config/wg_confs/ | wc -l
```

---

### 3️⃣ DNS personnalisé pour les clients

**Par défaut :**
```yaml
PEERDNS: auto  # Utilise le DNS du serveur
```

**Utiliser Cloudflare :**
```yaml
PEERDNS: 1.1.1.1, 1.0.0.1
```

**Utiliser Quad9 (anti-malware) :**
```yaml
PEERDNS: 9.9.9.9, 149.112.112.112
```

**Utiliser un DNS interne :**
```yaml
PEERDNS: 10.13.13.1, 8.8.8.8
```

---

### 4️⃣ Masquer l'adresse IP publique (kill switch)

**Modifier la config client pour utiliser tout le trafic via VPN :**

```ini
[Peer]
# Au lieu de :
AllowedIPs = 10.13.13.0/24

# Utiliser :
AllowedIPs = 0.0.0.0/0, ::/0
```

**Pourquoi :** Tout le trafic passe par le VPN, y compris DNS

---

### 5️⃣ Augmenter la sécurité des clés

**Vérifier la force des clés :**
```bash
# Les clés générées par WireGuard utilisent Curve25519 (256-bit)
# C'est le standard et c'est sécurisé

# Vérifier la clé privée
docker exec wireguard cat /config/wg_privatekey
# Doit être une chaîne base64 d'environ 44 caractères
```

**Rotation des clés :**
```bash
# Générer une nouvelle clé
docker exec wireguard bash -c 'wg genkey | tee /config/wg_privatekey | wg pubkey > /config/wg_publickey'

# Redémarrer
docker-compose restart wireguard
```

---

## 🚀 Astuces d'administration

### 1️⃣ Script de monitoring automatique

**Créer un script cron :**
```bash
cat > /opt/wireguard-docker/monitor.sh << 'EOF'
#!/bin/bash

# Variables
LOG_FILE="/var/log/wireguard-monitor.log"
EMAIL="admin@example.com"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] Monitoring WireGuard..." >> $LOG_FILE

# Vérifier le conteneur
if ! docker ps | grep -q wireguard; then
    echo "[$TIMESTAMP] ALERTE: Conteneur WireGuard arrêté!" >> $LOG_FILE
    # Redémarrer
    cd /opt/wireguard-docker && docker-compose up -d
    # Envoyer email
    echo "WireGuard s'est arrêté et a été redémarré." | mail -s "Alerte WireGuard" $EMAIL
fi

# Vérifier le port
if ! ss -tulpn | grep 51820; then
    echo "[$TIMESTAMP] ALERTE: Port 51820 ne répond pas!" >> $LOG_FILE
    cd /opt/wireguard-docker && docker-compose restart wireguard
fi

# Vérifier l'espace disque
USAGE=$(df /opt/wireguard-docker | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $USAGE -gt 80 ]; then
    echo "[$TIMESTAMP] ALERTE: Espace disque à ${USAGE}%!" >> $LOG_FILE
fi

echo "[$TIMESTAMP] Monitoring OK" >> $LOG_FILE
EOF

chmod +x /opt/wireguard-docker/monitor.sh

# Ajouter au crontab (toutes les 5 minutes)
echo "*/5 * * * * /opt/wireguard-docker/monitor.sh" | crontab -
```

---

### 2️⃣ Exporter les configurations en masse

**Script pour télécharger toutes les configs :**
```bash
#!/bin/bash

# Sur votre ordinateur local
mkdir -p ~/wireguard-configs
cd ~/wireguard-configs

# Télécharger tous les configs
for i in {1..10}; do
    scp -i ~/.ssh/id_rsa user@54.38.193.46:/opt/wireguard-docker/config/wg_confs/peer${i}/peer${i}.conf . 2>/dev/null
    echo "Downloaded peer${i}.conf"
done

echo "✓ Téléchargement terminé"
ls -la
```

---

### 3️⃣ Backup automatique des configurations

**Script de backup :**
```bash
#!/bin/bash

BACKUP_DIR="/backups/wireguard-$(date +%Y-%m-%d_%H-%M-%S)"
SOURCE_DIR="/opt/wireguard-docker/config"

# Créer le backup
mkdir -p $BACKUP_DIR
cp -r $SOURCE_DIR/* $BACKUP_DIR/

# Archiver
tar -czf ${BACKUP_DIR}.tar.gz $BACKUP_DIR/

# Garder seulement les 7 derniers backups
cd /backups && ls -t | tail -n +8 | xargs -r rm -rf

echo "✓ Backup créé : ${BACKUP_DIR}.tar.gz"
```

**Ajouter au cron (tous les jours à 2h du matin) :**
```bash
echo "0 2 * * * /opt/wireguard-docker/backup.sh" | sudo crontab -
```

---

### 4️⃣ Changer le port WireGuard

**Situation :** Vous voulez utiliser un port différent (ex: 51821)

**Modification :**
```bash
# 1. Éditer docker-compose.yml
nano /opt/wireguard-docker/docker-compose.yml

# Changer:
# ports:
#   - "51820:51820/udp"
# En:
# ports:
#   - "51821:51820/udp"

# 2. Redémarrer
docker-compose down
docker-compose up -d

# 3. Les configs clients se régénèrent automatiquement
sleep 30
cat /opt/wireguard-docker/config/wg_confs/peer1/peer1.conf
# Endpoint doit être : 54.38.193.46:51821
```

---

### 5️⃣ Migrer vers un nouveau serveur

**Procédure complète :**
```bash
# 1. Sur l'ancien serveur : créer un backup
tar -czf wireguard-backup.tar.gz /opt/wireguard-docker/config/

# 2. Télécharger le backup
scp user@54.38.193.46:/opt/wireguard-docker/wireguard-backup.tar.gz ./

# 3. Sur le nouveau serveur : créer la structure
ssh user@NEW_IP
sudo mkdir -p /opt/wireguard-docker/config
sudo mkdir -p /opt/wireguard-docker/custom-init

# 4. Uploader le backup
scp wireguard-backup.tar.gz user@NEW_IP:/opt/wireguard-docker/

# 5. Extraire
cd /opt/wireguard-docker
tar -xzf wireguard-backup.tar.gz

# 6. Adapter la config pour la nouvelle IP
nano config/wg0.conf
# Modifier si nécessaire les règles iptables

# 7. Copier le docker-compose.yml et custom-init
# (depuis l'ancien serveur)

# 8. Démarrer
docker-compose up -d
```

---

## 📊 Monitoring avancé

### Voir les statistiques de bande passante

```bash
# En temps réel
sudo iftop -i wg0

# Par peer
docker exec wireguard wg show

# Format table
docker exec wireguard wg show interface wg0 latest-handshakes
```

### Voir les connexions actives

```bash
# Toutes les connexions WireGuard
sudo ss -tunap | grep wireguard

# Par interface
sudo ip -s link show wg0

# Détails des transfers
sudo tcpdump -i wg0 -nn
```

---

## 🔐 Recommandations de sécurité finales

| Recommandation | Explication |
|----------------|-----------|
| **Firewall OVH** | Activer le pare-feu managé pour limiter l'accès au port 51820 à certaines IPs si possible |
| **SSH hardening** | Désactiver la connexion par password, utiliser uniquement les clés SSH |
| **Certificats** | Si vous exposez WireGuard-UI, utiliser HTTPS avec Let's Encrypt |
| **Logs** | Monitorer `/var/log/fail2ban.log` régulièrement |
| **Mises à jour** | `docker pull lscr.io/linuxserver/wireguard:latest` tous les mois |
| **Sauvegarde** | Backup les configs toutes les semaines |
| **VPN isolation** | Pas de clients VPN avec accès au réseau interne sans authentification supplémentaire |

---

## 📚 Commandes utiles à mémoriser

```bash
# Redémarrer tout
cd /opt/wireguard-docker && docker-compose down && docker-compose up -d

# Logs en live
docker-compose logs -f wireguard

# Voir les clients actifs
docker exec wireguard wg show

# Entrer dans le conteneur
docker exec -it wireguard bash

# Backup rapide
tar -czf ~/wireguard-$(date +%s).tar.gz /opt/wireguard-docker/config/

# Vérifier la santé
docker-compose ps
sudo ss -tulpn | grep 51820
docker exec wireguard ping -c 1 10.13.13.1
```

