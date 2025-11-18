# NFTABLES - Pare-feu Moderne
## Guide Rapide - Démarrage Immédiat

---

## ⚡ Installation (5 minutes)

```bash
# 1. Installer NFTABLES
sudo apt update
sudo apt install -y nftables

# 2. Vérifier l'installation
nft --version

# 3. Vérifier que le noyau supporte NFTABLES
cat /boot/config-$(uname -r) | grep CONFIG_NF_TABLES

# 4. Basculer iptables vers backend nftables
sudo update-alternatives --set iptables /usr/sbin/iptables-nft
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-nft

# 5. Redémarrer
sudo systemctl restart nftables
```

---

## 🔒 Configuration Basique ANSSI-Compliant

### Créer le Fichier de Configuration

```bash
sudo nano /etc/nftables.conf
```

### Configuration Minimale

```nftables
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain INPUT {
        type filter hook input priority 0; policy drop;
        
        # ✓ Loopback TOUJOURS
        iifname "lo" accept
        
        # ✓ Connexions établies
        ct state established,related accept
        
        # ✗ Connexions invalides
        ct state invalid drop
        
        # ✓ SSH depuis réseau interne uniquement
        tcp dport 22 ip saddr 192.168.1.0/24 accept
        
        # ✓ HTTP/HTTPS public
        tcp dport { 80, 443 } accept
        
        # ✓ ICMP limité (ping protection)
        icmp type echo-request limit rate 1/second accept
        
        # ✗ Tout le reste = DROP (voir policy)
    }
    
    chain OUTPUT {
        type filter hook output priority 0; policy accept;
    }
    
    chain FORWARD {
        type filter hook forward priority 0; policy drop;
    }
}
```

### Appliquer la Configuration

```bash
# 1. Vérifier la syntaxe
sudo nft -c -f /etc/nftables.conf

# 2. Charger les règles
sudo nft -f /etc/nftables.conf

# 3. Activer au démarrage
sudo systemctl enable nftables
sudo systemctl restart nftables

# 4. Vérifier le résultat
sudo nft list ruleset
```

---

## 📋 Commandes Essentielles

```bash
# Afficher toutes les règles
sudo nft list ruleset

# Afficher avec compteurs
sudo nft list ruleset -a

# Afficher une chaîne
sudo nft list chain inet filter INPUT

# Ajouter une règle
sudo nft add rule inet filter INPUT tcp dport 3306 accept

# Supprimer une règle (par handle)
sudo nft delete rule inet filter INPUT handle 5

# Supprimer TOUTES les règles
sudo nft flush ruleset

# Tester la syntaxe
sudo nft -c -f /etc/nftables.conf

# Monitor en temps réel
watch -n 1 'sudo nft list ruleset'
```

---

## 🔧 Configuration Avancée - Réseau Complet

### Serveur avec NAT + DMZ

```nftables
#!/usr/sbin/nft -f

flush ruleset

define WAN_IFACE = "eth0"
define LAN_IFACE = "eth1"
define DMZ_IFACE = "eth2"
define WAN_IP = "203.0.113.1"
define LAN_NET = "192.168.1.0/24"
define DMZ_NET = "192.168.100.0/24"

# Filtrage
table inet filter {
    chain INPUT {
        type filter hook input priority 0; policy drop;
        
        iifname "lo" accept
        ct state established,related accept
        ct state invalid drop
        
        # SSH admin (LAN uniquement)
        iifname $LAN_IFACE tcp dport 22 accept
        
        # ICMP limité
        icmp type echo-request limit rate 1/second accept
    }
    
    chain OUTPUT {
        type filter hook output priority 0; policy accept;
    }
    
    chain FORWARD {
        type filter hook forward priority 0; policy drop;
        
        # Connexions établies
        ct state established,related accept
        
        # LAN → WAN (sortant autorisé)
        iifname $LAN_IFACE oifname $WAN_IFACE accept
        
        # WAN → DMZ (services publics)
        iifname $WAN_IFACE oifname $DMZ_IFACE accept
        
        # DMZ → LAN (INTERDIT - sécurité)
        iifname $DMZ_IFACE oifname $LAN_IFACE drop
    }
}

# NAT
table inet nat {
    chain PREROUTING {
        type nat hook prerouting priority -100; policy accept;
        
        # Port forwarding HTTP
        iifname $WAN_IFACE tcp dport 80 dnat to 192.168.100.10:80
        
        # Port forwarding HTTPS
        iifname $WAN_IFACE tcp dport 443 dnat to 192.168.100.10:443
        
        # Port forwarding SSH alternatif
        iifname $WAN_IFACE tcp dport 2222 dnat to 192.168.100.20:22
    }
    
    chain POSTROUTING {
        type nat hook postrouting priority 100; policy accept;
        
        # Masquerade LAN sortant
        oifname $WAN_IFACE ip saddr $LAN_NET masquerade
        
        # SNAT DMZ
        oifname $WAN_IFACE ip saddr $DMZ_NET snat to $WAN_IP
    }
}
```

---

## ✅ Checklist de Déploiement

- [ ] NFTABLES installé (`nft --version`)
- [ ] Noyau supporte NFTABLES (CONFIG_NF_TABLES)
- [ ] Syntaxe vérifiée (`sudo nft -c -f`)
- [ ] Règles chargées (`sudo nft -f`)
- [ ] Service enable (`sudo systemctl enable nftables`)
- [ ] Connectivité testée (ping, SSH, HTTP)
- [ ] Logs vérifiés (`sudo journalctl -u nftables`)
- [ ] Configuration sauvegardée (`sudo nft list ruleset > backup.conf`)

---

## 🆘 Dépannage Rapide

| Problème | Solution |
|----------|----------|
| "Erreur de syntaxe" | `sudo nft -c -f /etc/nftables.conf` pour diagnostic |
| Perdre accès SSH | Redémarrer : règles chargées depuis fichier au démarrage |
| Port bloqué | `sudo nft list ruleset \| grep <port>` et `sudo nft add rule...` |
| Voir les règles appliquées | `sudo nft list ruleset -a` (avec compteurs) |
| Réinitialiser | `sudo nft flush ruleset` puis recharger |

---

**Guide rapide - Pour déploiement immédiat**
**Voir Guide Complet pour détails ANSSI et concepts avancés**
