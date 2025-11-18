# ⚡ Guide Rapide : WireGuard Docker en 15 minutes

## 🚀 TL;DR (Installation ultra-rapide)

### Étape 1 : Préparation (2 min)
```bash
# Se connecter au serveur
ssh user@54.38.193.46

# Créer la structure
sudo mkdir -p /opt/wireguard-docker/config
sudo mkdir -p /opt/wireguard-docker/custom-init
sudo chown -R 1000:1000 /opt/wireguard-docker
```

### Étape 2 : Docker Compose (3 min)
```bash
# Créer docker-compose.yml
cat > /opt/wireguard-docker/docker-compose.yml << 'EOF'
version: '3.8'
services:
  wireguard:
    image: lscr.io/linuxserver/wireguard:latest
    container_name: wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      PUID: 1000
      PGID: 1000
      TZ: Europe/Paris
      SERVERURL: 54.38.193.46
      SERVERPORT: 51820
      PEERS: 3
      PEERDNS: auto
      INTERNAL_SUBNET: 10.13.13.0
      LOG_CONFS: true
    volumes:
      - /opt/wireguard-docker/config:/config
      - /lib/modules:/lib/modules:ro
      - /opt/wireguard-docker/custom-init:/custom-cont-init.d:ro
    ports:
      - "51820:51820/udp"
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv4.ip_forward=1
    restart: unless-stopped
networks:
  default:
    name: wireguard-network
EOF

# Lancer le conteneur
cd /opt/wireguard-docker
docker-compose up -d
```

### Étape 3 : Récupérer les configs (2 min)
```bash
# Attendre 30 secondes que les configs se génèrent
sleep 30

# Afficher la config du client 1
cat /opt/wireguard-docker/config/wg_confs/peer1/peer1.conf

# QR code pour mobile
docker exec -it wireguard /app/show-peer 1
```

### Étape 4 : Configurer iptables (5 min)
```bash
# Créer le script iptables
cat > /opt/wireguard-docker/custom-init/wireguard-iptables.sh << 'EOF'
#!/usr/bin/with-contenv bash
echo "[*] Configuration des règles iptables..."
iptables -A INPUT -i wg0 -j ACCEPT
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -o wg0 -j ACCEPT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
echo "[+] Règles iptables OK"
exit 0
EOF

chmod +x /opt/wireguard-docker/custom-init/wireguard-iptables.sh

# Sauvegarder les règles
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
```

### Étape 5 : fail2ban (3 min)
```bash
# Créer la jail fail2ban
sudo bash -c 'cat > /etc/fail2ban/jail.d/wireguard.local << EOF
[sshd]
enabled = true
port = ssh
maxretry = 5

[wireguard]
enabled = true
port = 51820
protocol = udp
maxretry = 10
findtime = 600
bantime = 86400
filter = wireguard
logpath = /var/log/wireguard.log
action = iptables-multiport[name=wireguard, port=51820, protocol=udp]
EOF'

# Redémarrer fail2ban
sudo systemctl restart fail2ban
sudo fail2ban-client status
```

---

## ✅ Vérification rapide

```bash
# Interface WireGuard active ?
ip addr show wg0

# Port en écoute ?
sudo ss -tulpn | grep 51820

# Configs client générées ?
ls /opt/wireguard-docker/config/wg_confs/

# Docker OK ?
docker ps | grep wireguard

# fail2ban OK ?
sudo fail2ban-client status wireguard
```

---

## 🔗 Connecter un client

**Linux :**
```bash
scp user@54.38.193.46:/opt/wireguard-docker/config/wg_confs/peer1/peer1.conf ./
sudo wg-quick up ./peer1.conf
ping 10.13.13.1
```

**Windows/Mac :**
1. Télécharger WireGuard : https://www.wireguard.com/install/
2. Copier `peer1.conf` depuis le serveur
3. Importer dans l'appli
4. Activer la connexion

**Mobile (Android/iOS) :**
```bash
# Afficher le QR code
docker exec -it wireguard /app/show-peer 1
# Scannez avec WireGuard mobile app
```

---

## 🆘 Diagnostique rapide

| Problème | Solution |
|----------|----------|
| Port 51820 ne répond pas | `sudo ss -tulpn \| grep 51820` puis `docker-compose restart` |
| Pas de connectivité DNS | Modifier PEERDNS dans docker-compose.yml |
| Clients ne voient pas les autres | Vérifier la config AllowedIPs dans les .conf |
| fail2ban ban trop d'IPs | Réduire maxretry ou augmenter findtime |
| iptables reset au reboot | `sudo netfilter-persistent save` |

---

## 📝 Commandes essentielles

```bash
# Restart complet
cd /opt/wireguard-docker
docker-compose down && docker-compose up -d

# Voir les logs
docker-compose logs -f wireguard

# Voir les clients actifs
docker exec wireguard wg show

# Supprimer un client et en ajouter un nouveau
docker-compose down
nano docker-compose.yml  # Changer PEERS: 4
docker-compose up -d

# Vérifier la syntaxe de la config
docker exec wireguard wg-quick up wg0 --help
```

---

## 🎁 Bonus : Script de maintenance

```bash
#!/bin/bash
echo "=== WireGuard Health Check ==="
echo "✓ Interface wg0:"
ip addr show wg0 | grep inet

echo "✓ Port écoute:"
ss -tulpn | grep 51820

echo "✓ Clients connectés:"
docker exec wireguard wg show | grep -c "peer"

echo "✓ IPs bannies (fail2ban):"
sudo iptables -L fail2ban-wireguard -n 2>/dev/null | grep DROP | wc -l

echo "=== OK ==="
```

Sauvegarder dans `/opt/wireguard-docker/health-check.sh` et rendre exécutable.

