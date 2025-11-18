# NFTABLES - Astuces, Dépannage et Solutions Avancées

---

## 🛠️ Astuces Pratiques

### Automatiser Ajout de Règles

```bash
#!/bin/bash
# Script pour ajouter rapidement des règles

add_rule() {
    local port=$1
    local protocol=${2:-tcp}
    local source=${3:-"any"}
    
    echo "Ajout : $protocol $port depuis $source"
    
    if [ "$source" = "any" ]; then
        sudo nft add rule inet filter INPUT $protocol dport $port accept
    else
        sudo nft add rule inet filter INPUT $protocol dport $port ip saddr $source accept
    fi
}

# Utilisation
add_rule 22 tcp 192.168.1.0/24      # SSH de LAN
add_rule 80 tcp                      # HTTP public
add_rule 443 tcp                     # HTTPS public
add_rule 3306 tcp 192.168.1.0/24     # MySQL de LAN
```

### Gestion des Sets Dynamiques

```bash
# Créer un set vide
sudo nft add set inet filter blocked_ips { type ipv4_addr \; }

# Ajouter une adresse au set
sudo nft add element inet filter blocked_ips { 192.168.1.100 }

# Ajouter multiple adresses
sudo nft add element inet filter blocked_ips { 10.0.0.1, 10.0.0.2, 10.0.0.3 }

# Supprimer une adresse
sudo nft delete element inet filter blocked_ips { 192.168.1.100 }

# Afficher les éléments
sudo nft list set inet filter blocked_ips

# Utiliser le set dans une règle
sudo nft add rule inet filter INPUT ip saddr @blocked_ips drop
```

### Utiliser des Variables Réutilisables

```bash
# Créer des variables dans le fichier de config
# /etc/nftables.conf

#!/usr/sbin/nft -f

define SSH_PORT = 22
define HTTP_PORTS = { 80, 443, 8080 }
define ADMIN_NET = 192.168.1.0/24
define DMZ_NET = 192.168.100.0/24
define WAN_IP = 203.0.113.1

table inet filter {
    chain INPUT {
        type filter hook input priority 0; policy drop;
        
        tcp dport $SSH_PORT ip saddr $ADMIN_NET accept
        tcp dport $HTTP_PORTS accept
    }
}
```

### Backup Automatique des Règles

```bash
#!/bin/bash
# Script de backup quotidien

BACKUP_DIR="/var/backups/nftables"
mkdir -p "$BACKUP_DIR"

# Backup horodaté
sudo nft list ruleset > "$BACKUP_DIR/nftables_$(date +%Y%m%d_%H%M%S).conf"

# Garder seulement les 30 derniers backups
find "$BACKUP_DIR" -name "nftables_*.conf" -type f | sort -r | tail -n +31 | xargs rm -f

echo "Backup réalisé : $BACKUP_DIR/nftables_$(date +%Y%m%d_%H%M%S).conf"
```

### Monitoring en Temps Réel

```bash
#!/bin/bash
# Monitor les connexions refusées en temps réel

echo "Connexions refusées :"
sudo journalctl -f -u nftables | grep -E "DROP|REJECT"

# Ou avec tcpdump (alternative)
sudo tcpdump -i any 'tcp flags[tcpflags] & (syn) != 0' -nn
```

---

## 🔍 Dépannage Détaillé

### Problème 1 : "Erreur de Syntaxe" dans la Configuration

#### Diagnostic

```bash
# 1. Vérifier la syntaxe
sudo nft -c -f /etc/nftables.conf

# 2. Résultat détaillé
sudo nft -f /etc/nftables.conf 2>&1 | head -20

# 3. Vérifier les logs systemd
sudo journalctl -u nftables -n 30

# 4. Afficher la ligne problématique
cat -n /etc/nftables.conf | grep -A 2 -B 2 "ligne problématique"
```

#### Solutions Courantes

```bash
# ✗ Erreur : Point-virgule manquant
table inet filter {
    chain INPUT {
        accept  # ← Manque ; à la fin
    }
}

# ✓ Correct
table inet filter {
    chain INPUT {
        accept;
    }
}

# ✗ Erreur : Guillemets manquants
iifname eth0 accept       # ← Guillemets manquants

# ✓ Correct
iifname "eth0" accept

# ✗ Erreur : Commentaire mal placé
chain INPUT {  # Mauvais commentaire
    type filter hook...
}

# ✓ Correct
chain INPUT {
    type filter hook input priority 0; policy drop;
    # Commentaire ici
}
```

### Problème 2 : Perte de Connectivité SSH

#### Récupération d'Urgence

```bash
# ⚠️ SI vous êtes déconnecté :

# 1. Accès physique/KVM/IPMI requis

# 2. Rebooter en mode single-user
# (Lors du démarrage GRUB)
# Éditer la ligne kernel et ajouter : init=/bin/bash

# 3. Remonter le système de fichiers en RW
mount -o remount,rw /

# 4. Vérifier quelle est la configuration actuelle
cat /etc/nftables.conf

# 5. Réinitialiser les règles
/usr/sbin/nft flush ruleset

# 6. Rebooter
reboot

# 7. Ensuite, corriger la configuration et tester
```

#### Prévention

```bash
# Toujours faire un backup avant changement
sudo cp /etc/nftables.conf /etc/nftables.conf.backup

# Tester la syntaxe AVANT de recharger
sudo nft -c -f /etc/nftables.conf

# Utiliser un timeout pour les tests
(sleep 60 && sudo systemctl restart nftables) &
# Faire vos tests, si OK : kill $$

# Appliquer seulement les modifications valides
sudo nft -f /etc/nftables.conf
```

### Problème 3 : Port Bloqué mais Devrait Être Ouvert

#### Diagnostic Complet

```bash
# 1. Vérifier que le service écoute
sudo ss -tlnp | grep <port>
# ou
sudo netstat -tlnp | grep <port>

# 2. Afficher TOUTES les règles pour le port
sudo nft list ruleset | grep <port>

# 3. Lister les règles avec leurs handles
sudo nft list ruleset -a | grep -E "<port>|handle"

# 4. Tester la connexion locale
telnet localhost <port>

# 5. Tester la connectivité source
ping <source>
ping -c 1 <destination>

# 6. Vérifier le routing
ip route show
ip route get <destination>

# 7. Monitor les paquets
sudo tcpdump -i any -n "tcp port <port>"

# 8. Afficher les compteurs pour le port
sudo nft list ruleset -a | grep -B 2 "<port>" | grep "counter"
```

#### Solutions

```bash
# ✓ Ajouter la règle manquante
sudo nft add rule inet filter INPUT tcp dport 8080 accept

# ✓ Vérifier que la chaîne n'a pas de drop avant accept
sudo nft list chain inet filter INPUT

# ✓ Si plusieurs rules, vérifier l'ordre
# Les règles sont évaluées séquentiellement
# Une règle "drop" avant "accept" bloque l'accès

# ✓ Ajouter une règle à position spécifique
sudo nft list ruleset -a | grep "drop" | head -1
# Récupérer le handle du drop
sudo nft insert rule inet filter INPUT position <handle> tcp dport 8080 accept

# ✓ Tester avec une règle temporaire
sudo nft add rule inet filter INPUT tcp dport 8080 accept comment "TEST"
telnet localhost 8080
# Si OK, garder. Sinon, supprimer par handle
```

### Problème 4 : Connexions Lentes ou Timeout

#### Diagnostic Performance

```bash
# 1. Charge système
top -p $(pidof nft)

# 2. Nombre de règles (complexité)
sudo nft list ruleset | wc -l

# 3. Compteurs des règles
sudo nft list ruleset -a | grep -E "counter|packets"

# 4. Vérifier le trafic
ifstat
# ou
nethogs

# 5. Conntrack stats
sudo cat /proc/net/nf_conntrack | wc -l
sudo cat /proc/sys/net/netfilter/nf_conntrack_max

# 6. Vérifier les fragmentations
ip -s link show
```

#### Optimisations

```bash
# ✓ Augmenter la limite conntrack
sudo sysctl -w net.netfilter.nf_conntrack_max=262144

# ✓ Persister les changements
echo "net.netfilter.nf_conntrack_max=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# ✓ Vérifier le timeout inactivité
sudo cat /proc/sys/net/netfilter/nf_conntrack_generic_timeout
# Ajuster si besoin
sudo sysctl -w net.netfilter.nf_conntrack_tcp_timeout_established=600000

# ✓ Réduire le nombre de règles (consolidation)
# Au lieu de :
add rule inet filter INPUT tcp dport 22 accept
add rule inet filter INPUT tcp dport 80 accept
add rule inet filter INPUT tcp dport 443 accept

# Faire :
add set inet filter allowed_ports { type inet_service; elements = { 22, 80, 443 } }
add rule inet filter INPUT tcp dport @allowed_ports accept
```

### Problème 5 : Règles Qui ne S'appliquent Pas après Reboot

#### Diagnostic

```bash
# 1. Vérifier que le service est activé
sudo systemctl is-enabled nftables

# 2. Vérifier les logs du démarrage
sudo journalctl -u nftables --boot

# 3. Vérifier le fichier de configuration
sudo ls -la /etc/nftables.conf
sudo head -1 /etc/nftables.conf  # Doit être #!/usr/sbin/nft -f

# 4. Vérifier les permissions
sudo file /etc/nftables.conf
sudo stat /etc/nftables.conf
```

#### Solutions

```bash
# ✓ Activer le service au démarrage
sudo systemctl enable nftables

# ✓ Rendre le fichier exécutable
sudo chmod +x /etc/nftables.conf

# ✓ Vérifier le shebang (première ligne)
sudo head -1 /etc/nftables.conf
# Doit être : #!/usr/sbin/nft -f

# ✓ Charger manuellement et vérifier
sudo systemctl restart nftables
sudo systemctl status nftables

# ✓ Tester le démarrage
sudo reboot
# Vérifier après reboot :
sudo nft list ruleset
```

---

## 🔐 Sécurité Avancée

### Détection d'Intrusion (Logging)

```nftables
#!/usr/sbin/nft -f

table inet filter {
    chain INPUT {
        type filter hook input priority 0; policy drop;
        
        iifname "lo" accept
        ct state established,related accept
        
        # Log les tentatives de connexion refusées
        log prefix "[NFTABLES-INPUT-DROP] " level warning
        drop
    }
    
    chain OUTPUT {
        type filter hook output priority 0; policy accept;
    }
    
    chain FORWARD {
        type filter hook forward priority 0; policy drop;
        
        # Log les forward refusés
        log prefix "[NFTABLES-FORWARD-DROP] " level warning
        drop
    }
}
```

### Analyser les Logs

```bash
# Voir les logs NFTABLES
sudo journalctl -u nftables -f

# Filtrer par type
sudo journalctl -u nftables | grep "INPUT-DROP"

# Compter les tentatives par source IP
sudo journalctl -u nftables | grep "INPUT-DROP" | \
    grep -oE 'SRC=[^ ]+' | cut -d= -f2 | sort | uniq -c

# Voir les ports attaqués
sudo journalctl -u nftables | grep "INPUT-DROP" | \
    grep -oE 'DPT=[^ ]+' | cut -d= -f2 | sort | uniq -c
```

### Rate Limiting Avancé

```nftables
table inet filter {
    chain INPUT {
        type filter hook input priority 0; policy drop;
        
        iifname "lo" accept
        ct state established,related accept
        
        # Limite SSH à 5 tentatives par minute par adresse IP
        tcp dport 22 limit rate over 5/minute {
            log prefix "[NFTABLES-SSH-LIMIT] " level warning
            drop
        }
        tcp dport 22 accept
        
        # Limite HTTP à 100 req/sec
        tcp dport 80 limit rate over 100/second {
            log prefix "[NFTABLES-HTTP-LIMIT] " level warning
            drop
        }
        tcp dport 80 accept
        
        # Limite ICMP
        icmp type echo-request limit rate 10/second accept
    }
}
```

### Blocklist Automatique

```bash
#!/bin/bash
# Bloquer automatiquement les IPs qui tentent de brute-force SSH

LOG_FILE="/var/log/auth.log"
NFTABLES_BLOCKLIST="blocked_ssh_ips"
MAX_FAILURES=5
TIME_WINDOW=600  # 10 minutes

# Extraire les IPs suspectes
sudo journalctl -u ssh | tail -1000 | grep "Failed password" | \
    awk '{print $NF}' | sort | uniq -c | \
    awk -v max=$MAX_FAILURES '$1 > max {print $NF}' > /tmp/blocklist.txt

# Ajouter au set NFTABLES
sudo nft flush set inet filter blocked_ssh_ips

while read ip; do
    sudo nft add element inet filter blocked_ssh_ips { $ip }
    echo "Bloqué : $ip"
done < /tmp/blocklist.txt

# Vérifier
sudo nft list set inet filter blocked_ssh_ips
```

Planner comme cron job :
```bash
# Ajouter à crontab
0 * * * * /usr/local/bin/nftables_blocklist.sh
```

---

## 📊 Checklists Spécialisées

### Checklist Sécurité ANSSI Complète

- [ ] Policy INPUT = drop
- [ ] Policy FORWARD = drop
- [ ] Policy OUTPUT = accept
- [ ] Loopback accepté
- [ ] Connexions établies acceptées
- [ ] Connexions invalides refusées
- [ ] SSH restreint (source IP ou réseau)
- [ ] Ports services limités et documentés
- [ ] ICMP rate-limited
- [ ] Adresses RFC invalides refusées
- [ ] Logging activé pour refusés
- [ ] IPv6 avec mêmes règles
- [ ] Backup des règles effectué
- [ ] Règles testées après chaque modif
- [ ] Documentation des exceptions

### Checklist Performance

- [ ] Nombre de règles optimisé
- [ ] Sets utilisés pour énumérations
- [ ] Règles fréquentes en premier
- [ ] Compteurs activés pour debug
- [ ] Conntrack max approprié
- [ ] Timeouts adaptés
- [ ] Fragments refusés si pas besoin
- [ ] SYN cookies activés

---

## 💡 Tips & Tricks Avancés

### Conversion iptables vers NFTABLES

```bash
# Exporter les règles iptables existantes
iptables-save > ~/iptables_backup.txt

# Convertir automatiquement
iptables-save | iptables-restore-translate -f - > ~/nftables_converted.conf

# Vérifier et adapter
cat ~/nftables_converted.conf

# Appliquer
sudo nft -f ~/nftables_converted.conf
```

### Exporter/Importer Configuration

```bash
# Exporter en JSON
sudo nft -j list ruleset > ~/nftables.json

# Exporter en format texte
sudo nft list ruleset > ~/nftables.conf

# Importer depuis JSON
cat ~/nftables.json | nft -f -

# Importer depuis texte
sudo nft -f ~/nftables.conf
```

### Test Sécurisé de Configuration

```bash
#!/bin/bash
# Script de test sécurisé avec rollback

NFTABLES_FILE="$1"
TIMEOUT=30

# Sauvegarder configuration actuelle
sudo nft list ruleset > /tmp/nftables_backup.conf

# Charger la nouvelle configuration
sudo nft -f "$NFTABLES_FILE"

echo "Configuration appliquée. Test pendant $TIMEOUT sec..."
echo "Pour annuler, Ctrl+C avant le countdown"

countdown=$TIMEOUT
while [ $countdown -gt 0 ]; do
    echo -ne "\rRollback dans $countdown secondes... (Ctrl+C = Valider)"
    sleep 1
    ((countdown--))
done

echo -e "\n\nConfirmation ? (y/n)"
read confirm

if [ "$confirm" != "y" ]; then
    echo "Rollback..."
    sudo nft -f /tmp/nftables_backup.conf
else
    echo "Configuration conservée"
fi
```

### Supervision des Ports

```bash
#!/bin/bash
# Vérifier que tous les ports souhaités sont bien ouverts

PORTS="22 80 443"

for port in $PORTS; do
    open=$(sudo nft list ruleset | grep -c "dport $port.*accept")
    if [ $open -gt 0 ]; then
        echo "✓ Port $port : OUVERT"
    else
        echo "✗ Port $port : FERMÉ"
    fi
done
```

---

**Document pratique - Mise à jour 16 novembre 2025**
**Pour questions avancées : Consulter Guide Complet + Wiki NFTABLES**
