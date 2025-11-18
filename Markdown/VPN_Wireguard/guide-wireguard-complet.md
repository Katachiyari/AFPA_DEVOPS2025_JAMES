# 🔒 Guide Complet : WireGuard avec Docker sur Serveur Debian

## 📋 Table des matières
1. [Prérequis](#prérequis)
2. [Architecture réseau](#architecture-réseau)
3. [Installation initiale](#installation-initiale)
4. [Configuration WireGuard](#configuration-wireguard)
5. [Configuration iptables](#configuration-iptables)
6. [Intégration fail2ban](#intégration-fail2ban)
7. [Gestion des clients](#gestion-des-clients)
8. [Tests et validation](#tests-et-validation)

---

## Prérequis

### ✅ Éléments à vérifier

**Serveur**
- IP publique : `54.38.193.46`
- OS : Debian (recommandé 11 ou 12)
- Docker et Docker Compose installés
- Container WikiJS existant

**Kernel WireGuard**
```bash
# Vérifier que le module WireGuard est chargé
lsmod | grep wireguard

# Si absent, installer les headers du kernel
sudo apt update
sudo apt install linux-headers-$(uname -r) wireguard-tools

# Charger le module
sudo modprobe wireguard
```

**Vérification des ports**
```bash
# Port 51820 doit être libre (UDP)
sudo netstat -tulpn | grep 51820
# Ou avec ss (plus moderne)
sudo ss -tulpn | grep 51820
```

---

## Architecture réseau

### 🏗️ Schéma de votre infrastructure

```
┌─────────────────────────────────────────┐
│   Internet (54.38.193.46:51820)        │
└──────────────────┬──────────────────────┘
                   │ (UDP 51820)
        ┌──────────▼──────────┐
        │  Host Debian        │
        │ - iptables          │
        │ - fail2ban          │
        └────┬────────────┬───┘
             │            │
      ┌──────▼──────┐  ┌──▼──────────┐
      │  WireGuard  │  │  WikiJS     │
      │  (Docker)   │  │  (Docker)   │
      │ 10.13.13.0  │  │  Port 3000  │
      └─────┬───────┘  └─────────────┘
            │
    ┌───────▼────────────┐
    │ Clients VPN        │
    │ 10.13.13.2 → 10.13.13.X
    └────────────────────┘
```

### 🔗 Adressage réseau

| Composant | Réseau | Rôle |
|-----------|--------|------|
| WireGuard Serveur | 10.13.13.1/24 | Passerelle VPN |
| Clients WireGuard | 10.13.13.2-10.13.13.254 | Utilisateurs VPN |
| Host (interface interne) | 172.17.0.0/16 | Docker bridge |

---

## Installation initiale

### 1️⃣ Préparation du serveur

```bash
# Se connecter en SSH
ssh -i votre_clé user@54.38.193.46

# Vérifier les droits sudo
sudo whoami

# Mettre à jour le système
sudo apt update && sudo apt upgrade -y

# Installer les dépendances essentielles
sudo apt install -y \
    docker.io \
    docker-compose \
    iptables \
    fail2ban \
    net-tools \
    curl \
    wget \
    nano
```

### 2️⃣ Créer la structure de répertoires

```bash
# Créer le dossier de configuration
sudo mkdir -p /opt/wireguard-docker
sudo mkdir -p /opt/wireguard-docker/config
sudo mkdir -p /opt/wireguard-docker/custom-init

# Définir les permissions
sudo chown -R 1000:1000 /opt/wireguard-docker
sudo chmod -R 755 /opt/wireguard-docker
```

### 3️⃣ Ajouter votre utilisateur à Docker

```bash
# Ajouter votre utilisateur au groupe docker
sudo usermod -aG docker $USER

# Appliquer les changements (sans se reconnecter)
newgrp docker

# Vérifier que Docker fonctionne
docker ps
```

---

## Configuration WireGuard

### 📝 Créer le fichier docker-compose.yml

**Créer et éditer le fichier :**
```bash
nano /opt/wireguard-docker/docker-compose.yml
```

**Contenu complet :**
```yaml
version: '3.8'

services:
  wireguard:
    image: lscr.io/linuxserver/wireguard:latest
    container_name: wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    
    environment:
      # Identité du conteneur
      PUID: 1000
      PGID: 1000
      TZ: Europe/Paris
      
      # Configuration serveur
      SERVERURL: 54.38.193.46  # ⚠️ À remplacer par votre IP publique
      SERVERPORT: 51820
      
      # Configuration des clients
      PEERS: 3  # Nombre de configurations client à générer
      PEERDNS: auto  # DNS pour les clients (auto = DNS du serveur)
      INTERNAL_SUBNET: 10.13.13.0  # Subnet VPN
      
      # Logging (utile pour déboguer)
      LOG_CONFS: true
    
    volumes:
      # Configuration WireGuard
      - /opt/wireguard-docker/config:/config
      
      # Kernel modules (important pour WireGuard)
      - /lib/modules:/lib/modules:ro
      
      # Scripts personnalisés d'initialisation
      - /opt/wireguard-docker/custom-init:/custom-cont-init.d:ro
    
    ports:
      # ⚠️ Important : doit être UDP, pas TCP
      - "51820:51820/udp"
    
    sysctls:
      # Autoriser le marquage des paquets pour WireGuard
      - net.ipv4.conf.all.src_valid_mark=1
      # Activer le forwarding IP (pour le routage)
      - net.ipv4.ip_forward=1
    
    restart: unless-stopped
    
    networks:
      - wireguard-network

networks:
  wireguard-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### 🚀 Démarrer le conteneur

```bash
# Naviguer au répertoire
cd /opt/wireguard-docker

# Démarrer le conteneur
docker-compose up -d

# Vérifier que le conteneur est en cours d'exécution
docker ps | grep wireguard

# Consulter les logs
docker-compose logs -f wireguard
```

### ✨ Vérifier la génération des configurations

```bash
# Lister les fichiers générés
ls -la /opt/wireguard-docker/config/

# Vérifier la configuration serveur
cat /opt/wireguard-docker/config/wg0.conf

# Vérifier les configurations client
ls -la /opt/wireguard-docker/config/wg_confs/

# Afficher le code QR pour client mobile
docker exec -it wireguard /app/show-peer 1
```

---

## Configuration iptables

### 🔥 Comprendre iptables avec Docker

**Pourquoi c'est important :**
- Docker modifie les règles iptables automatiquement
- WireGuard a besoin de règles NAT spécifiques
- fail2ban doit fonctionner avec ces règles
- Il faut une stratégie coordonnée pour éviter les conflits

### 📍 Structure des chaînes iptables

```
INPUT → DOCKER-USER → DOCKER → APPLICATION
                ↓ (règles fail2ban)
           FORWARD → DOCKER-ISOLATION-STAGE-1
```

### 🛡️ Règles iptables pour WireGuard

**Créer un script permanent :**
```bash
# Créer le script d'initialisation
sudo nano /opt/wireguard-docker/custom-init/wireguard-iptables.sh
```

**Contenu du script :**
```bash
#!/usr/bin/with-contenv bash
# Script d'initialisation des règles iptables pour WireGuard

echo "[*] Configuration des règles iptables pour WireGuard..."

# ===== RÈGLES POUR WIREGUARD =====

# 1. Autoriser l'interface WireGuard
iptables -A INPUT -i wg0 -j ACCEPT

# 2. Autoriser les connexions établies via WireGuard
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -o wg0 -j ACCEPT

# 3. Masquerade NAT (important pour le trafic sortant)
# Cela permet aux clients VPN d'accéder à internet
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE

# 4. Forward des connexions établies avec suivi de connexion
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# 5. Permettre le trafic multicast (important pour certaines apps)
iptables -A FORWARD -d 224.0.0.0/4 -j ACCEPT

echo "[+] Règles iptables WireGuard configurées avec succès"

# Sauvegarder les règles
if command -v iptables-save &> /dev/null; then
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
fi

exit 0
```

**Rendre le script exécutable :**
```bash
chmod +x /opt/wireguard-docker/custom-init/wireguard-iptables.sh
```

### 🔄 Vérifier les règles actives

```bash
# Afficher toutes les chaînes INPUT
sudo iptables -L INPUT -n -v

# Afficher les règles NAT
sudo iptables -t nat -L -n -v

# Afficher les chaînes FORWARD
sudo iptables -L FORWARD -n -v

# Sauvegarder pour persistence au redémarrage
sudo sh -c 'iptables-save > /etc/iptables/rules.v4'
```

### 💾 Persistance des règles iptables

**Installer iptables-persistent :**
```bash
sudo apt install iptables-persistent

# Durante l'installation, répondre "Oui" pour sauvegarder les règles actuelles

# Restaurer les règles au démarrage
sudo systemctl enable iptables-persistent
sudo systemctl start iptables-persistent

# Sauvegarder manuellement les règles
sudo netfilter-persistent save
```

---

## Intégration fail2ban

### 🚨 Architecture de fail2ban

**Composants :**
1. **Jail** : Règles de détection (fichier filtre)
2. **Filter** : Expression régulière pour détecter les menaces
3. **Action** : Réponse (ban via iptables)
4. **Bantime** : Durée du ban

### 📋 Configuration fail2ban pour WireGuard

**1. Créer le filtre personnalisé :**
```bash
sudo nano /etc/fail2ban/filter.d/wireguard.conf
```

**Contenu :**
```ini
# Filtre pour détecter les tentatives de connexion WireGuard échouées

[Definition]
failregex = ^.*Received packet from unknown peer.*$
            ^.*Invalid packet.*$
            ^.*Handshake did not complete.*$
ignoreregex = 
```

**2. Créer une action personnalisée pour Docker :**
```bash
sudo nano /etc/fail2ban/action.d/iptables-docker.conf
```

**Contenu :**
```ini
# Action personnalisée pour ban dans la chaîne DOCKER-USER
# Cela garantit que fail2ban fonctionne avant les règles Docker

[Definition]
actionstart = iptables -N fail2ban-<name>
              iptables -A fail2ban-<name> -j RETURN
              iptables -I DOCKER-USER -p <protocol> -m multiport --dports <port> -j fail2ban-<name>

actionstop = iptables -D DOCKER-USER -p <protocol> -m multiport --dports <port> -j fail2ban-<name>
             iptables -F fail2ban-<name>
             iptables -X fail2ban-<name>

actioncheck = iptables -n -L DOCKER-USER | grep -q 'fail2ban-<name>[ \t]'

actionban = iptables -I fail2ban-<name> 1 -s <ip> -j DROP

actionunban = iptables -D fail2ban-<name> -s <ip> -j DROP

[Init]
name = default
port = ssh
protocol = tcp
chain = DOCKER-USER
```

**3. Configurer la jail pour WireGuard :**
```bash
sudo nano /etc/fail2ban/jail.d/wireguard.local
```

**Contenu :**
```ini
[DEFAULT]
# Configuration globale
destemail = admin@example.com
sendername = Fail2Ban WireGuard
banaction = iptables-docker
banaction_allports = iptables-docker

[sshd]
enabled = true
port = ssh
maxretry = 5
findtime = 600
bantime = 3600

[wireguard]
enabled = true
port = 51820
protocol = udp
maxretry = 10          # Nombre de tentatives avant ban
findtime = 600         # Période de détection (10 min)
bantime = 86400        # Durée du ban (24 h)
filter = wireguard
logpath = /var/log/wireguard.log
action = iptables-docker[name=wireguard, port=51820, protocol=udp]
```

### 🚀 Activer et tester fail2ban

```bash
# Redémarrer fail2ban
sudo systemctl restart fail2ban

# Vérifier le statut
sudo systemctl status fail2ban

# Voir les jails actives
sudo fail2ban-client status

# Voir le statut de la jail WireGuard
sudo fail2ban-client status wireguard

# Voir les IPs bannies
sudo iptables -L fail2ban-wireguard -n -v

# Déboguer les filtres
sudo fail2ban-regex /var/log/wireguard.log /etc/fail2ban/filter.d/wireguard.conf
```

---

## Gestion des clients

### 👥 Créer des configurations client

**Vérifier les configurations générées :**
```bash
# Lister les clients
ls -la /opt/wireguard-docker/config/wg_confs/

# Afficher la config du client 1
cat /opt/wireguard-docker/config/wg_confs/peer1/peer1.conf

# Montrer le QR code pour mobile
docker exec -it wireguard /app/show-peer 1
```

**Structure d'une configuration client :**
```ini
[Interface]
PrivateKey = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Address = 10.13.13.2/32
DNS = 10.13.13.1

[Peer]
PublicKey = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
PresharedKey = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Endpoint = 54.38.193.46:51820
AllowedIPs = 10.13.13.0/24, 192.168.x.x/24
PersistentKeepalive = 25
```

### 📥 Transférer les configs clients

**Via SCP :**
```bash
# Depuis votre ordinateur local
scp -i votre_clé user@54.38.193.46:/opt/wireguard-docker/config/wg_confs/peer1/peer1.conf ~/

# Ou inversement (envoyer une config)
scp -i votre_clé ~/peer1.conf user@54.38.193.46:/opt/wireguard-docker/config/wg_confs/
```

**Via SSH direct :**
```bash
# Afficher directement le contenu
ssh -i votre_clé user@54.38.193.46 'cat /opt/wireguard-docker/config/wg_confs/peer1/peer1.conf'

# Copier dans un fichier local directement
ssh -i votre_clé user@54.38.193.46 'cat /opt/wireguard-docker/config/wg_confs/peer1/peer1.conf' > peer1.conf
```

### 🔧 Générer des clients supplémentaires

**Augmenter le nombre de peers :**
```bash
# Modifier le docker-compose.yml
nano /opt/wireguard-docker/docker-compose.yml

# Changer : PEERS: 3
# En     : PEERS: 10

# Redémarrer le conteneur
docker-compose down
docker-compose up -d

# Les nouvelles configs seront générées automatiquement
ls -la /opt/wireguard-docker/config/wg_confs/
```

---

## Tests et validation

### ✔️ Vérifier la connectivité

**1. Depuis le serveur :**
```bash
# Vérifier que l'interface wg0 existe
sudo ip addr show wg0

# Vérifier que le port écoute
sudo ss -tulpn | grep 51820

# Tester la résolution DNS interne
nslookup google.com 10.13.13.1
```

**2. Depuis un client Linux :**
```bash
# Installer WireGuard
sudo apt install wireguard wireguard-tools

# Copier la configuration
sudo cp peer1.conf /etc/wireguard/wg0.conf

# Activer l'interface
sudo wg-quick up wg0

# Vérifier la connexion
sudo wg show

# Tester la latence
ping 10.13.13.1

# Tester la sortie internet
curl https://ipinfo.io/ip
```

**3. Depuis votre ordinateur (Windows/Mac/Linux)** :
```bash
# Télécharger le client WireGuard officiel :
# https://www.wireguard.com/install/

# Importer la configuration et se connecter
# Vérifier l'IP publique : https://ipinfo.io
```

### 📊 Vérifier les performances

```bash
# Afficher les statistiques WireGuard
sudo wg show all

# Vérifier la bande passante consommée
sudo iftop -i wg0

# Vérifier les connexions établies
sudo ss -tunap | grep 51820

# Vérifier le trafic NAT
sudo iptables -t nat -L -n -v
```

### 🐛 Déboguer les problèmes

**Vérifier les logs du conteneur :**
```bash
# Logs en temps réel
docker-compose logs -f wireguard

# Dernières 50 lignes
docker-compose logs --tail=50 wireguard

# Avec filtre
docker-compose logs wireguard | grep -i "error\|warning"
```

**Vérifier la configuration WireGuard à l'intérieur du conteneur :**
```bash
# Se connecter au conteneur
docker exec -it wireguard bash

# Afficher les interfaces
ip addr show

# Afficher les routes
ip route show

# Afficher les règles iptables du conteneur
iptables -L -n -v

# Quitter le conteneur
exit
```

---

## 🎯 Recommandations finales

| Élément | Recommandation | Raison |
|---------|-----------------|--------|
| **Backup** | Sauvegarder `/opt/wireguard-docker/config` | Configurations et clés privées |
| **Mises à jour** | Mettre à jour l'image Docker régulièrement | Correctifs de sécurité |
| **Monitoring** | Surveiller les logs fail2ban | Détecter les attaques |
| **DNS** | Utiliser un DNS sécurisé (Quad9, Cloudflare) | Protection supplémentaire |
| **Certificats** | Utiliser HTTPS pour la gestion | Réduire les vecteurs d'attaque |

---

## 📚 Ressources supplémentaires

- **Documentation WireGuard** : https://www.wireguard.com/
- **Docker linuxserver** : https://docs.linuxserver.io/images/docker-wireguard
- **fail2ban** : https://www.fail2ban.org/
- **iptables** : https://www.netfilter.org/

