# 📋 Fiche de référence rapide - Commandes essentielles

## 🚀 Installation (première fois)

```bash
# 1. Connexion au serveur
ssh -i ~/.ssh/id_rsa user@54.38.193.46

# 2. Création de la structure
sudo mkdir -p /opt/wireguard-docker/config
sudo mkdir -p /opt/wireguard-docker/custom-init
sudo chown -R 1000:1000 /opt/wireguard-docker

# 3. Copier docker-compose.yml (voir guide complet)
# Puis
cd /opt/wireguard-docker
docker-compose up -d

# 4. Créer le script iptables (voir guide complet)
chmod +x /opt/wireguard-docker/custom-init/wireguard-iptables.sh

# 5. Sauvegarder iptables
sudo apt install -y iptables-persistent
sudo netfilter-persistent save

# 6. Configurer fail2ban (voir guide complet)
sudo systemctl restart fail2ban
```

---

## 🔧 Gestion quotidienne

```bash
# Voir les clients connectés
docker exec wireguard wg show

# Voir les logs en live
docker-compose logs -f wireguard

# Redémarrer le conteneur
docker-compose restart wireguard

# Arrêter proprement
docker-compose down

# Démarrer
docker-compose up -d

# Vérifier l'état
docker ps | grep wireguard
```

---

## 📊 Diagnostique

```bash
# Interface active ?
ip addr show wg0

# Port en écoute ?
sudo ss -tulpn | grep 51820

# Configs générées ?
ls /opt/wireguard-docker/config/wg_confs/

# QR code pour mobile
docker exec -it wireguard /app/show-peer 1

# Règles iptables actives
sudo iptables -L -n -v
sudo iptables -t nat -L -n -v

# fail2ban OK ?
sudo fail2ban-client status wireguard

# Espace disque
df -h /opt/wireguard-docker/
```

---

## 🐛 Dépannage rapide

| Problème | Commande |
|----------|----------|
| Conteneur n'ote pas | `docker-compose logs wireguard` |
| Port occupé | `sudo lsof -i :51820` |
| Pas de connectivité | `docker exec wireguard ping 8.8.8.8` |
| Clients bannis | `sudo fail2ban-client status wireguard` |
| Débannir une IP | `sudo fail2ban-client set wireguard unbanip 10.13.13.2` |
| Redémarrer tout | `cd /opt/wireguard-docker && docker-compose down && docker-compose up -d` |

---

## 💾 Sauvegarde et restauration

```bash
# Backup
tar -czf ~/wireguard-backup-$(date +%s).tar.gz /opt/wireguard-docker/config/

# Restauration
tar -xzf wireguard-backup-XXXX.tar.gz -C /opt/wireguard-docker/

# Transférer config client
scp user@54.38.193.46:/opt/wireguard-docker/config/wg_confs/peer1/peer1.conf ~/
```

---

## 🔐 Sécurité

```bash
# Vérifier les clés
docker exec wireguard cat /config/wg_privatekey
docker exec wireguard cat /config/wg_publickey

# Régénérer les clés
docker exec wireguard bash -c 'wg genkey | tee /config/wg_privatekey | wg pubkey > /config/wg_publickey'

# SSH hardening
sudo nano /etc/ssh/sshd_config
# PermitRootLogin no
# PasswordAuthentication no

sudo systemctl restart ssh
```

---

## 📈 Monitoring

```bash
# Statistiques de bande passante
sudo iftop -i wg0

# Connexions actives
docker exec wireguard wg show interfaces
docker exec wireguard wg show peers

# Détails des peers
docker exec wireguard wg show wg0 dump

# Traffic
sudo tcpdump -i wg0 -nn
```

---

## 🌐 Connexion des clients

### Linux
```bash
sudo wg-quick up ~/peer1.conf
sudo wg-quick down wg0
```

### Windows
- Télécharger WireGuard : https://www.wireguard.com/install/
- Importer peer1.conf
- Activer

### Android/iOS
- App WireGuard
- Scannez le QR code depuis : `docker exec -it wireguard /app/show-peer 1`

---

## 📝 Variables d'environnement importantes

```bash
# IP publique du serveur
SERVERURL: 54.38.193.46

# Port de WireGuard
SERVERPORT: 51820

# Nombre de clients à générer
PEERS: 3

# Subnet interne
INTERNAL_SUBNET: 10.13.13.0/24

# DNS pour les clients
PEERDNS: auto

# Timezone
TZ: Europe/Paris

# Identifiant du conteneur
PUID: 1000
PGID: 1000
```

---

## 🔄 Processus d'ajout d'un nouveau client

```bash
# 1. Augmenter PEERS dans docker-compose.yml
nano /opt/wireguard-docker/docker-compose.yml
# Changer : PEERS: 3
# En     : PEERS: 4

# 2. Redémarrer
docker-compose down
docker-compose up -d

# 3. Attendre la génération
sleep 30

# 4. Récupérer la config
cat /opt/wireguard-docker/config/wg_confs/peer4/peer4.conf

# 5. QR code
docker exec -it wireguard /app/show-peer 4
```

---

## ⚙️ Configuration avancée

### Augmenter le subnet
```yaml
# Pour ~1000 clients
INTERNAL_SUBNET: 10.13.12.0/22
```

### DNS sécurisé
```yaml
# Cloudflare
PEERDNS: 1.1.1.1, 1.0.0.1

# Quad9
PEERDNS: 9.9.9.9, 149.112.112.112
```

### Kill switch (tunnel tout le traffic)
```ini
[Peer]
AllowedIPs = 0.0.0.0/0, ::/0
```

---

## 📞 Support et ressources

- **Logs WireGuard** : `docker-compose logs wireguard`
- **Logs fail2ban** : `sudo tail -f /var/log/fail2ban.log`
- **Doc officielle** : https://www.wireguard.com/
- **Linux Server** : https://docs.linuxserver.io/images/docker-wireguard

---

## ✅ Checklist pré-production

- [ ] Test de connexion depuis au moins 3 clients différents
- [ ] Vérifier que le trafic passe bien par le VPN (test IP publique)
- [ ] Tester la déconnexion/reconnexion
- [ ] Vérifier fail2ban
- [ ] Backup des configurations
- [ ] Monitorage activé
- [ ] Documentation mise à jour
- [ ] Compte de communication de l'adresse de secours

