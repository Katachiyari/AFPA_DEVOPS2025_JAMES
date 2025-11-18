# NFTABLES - Pare-feu Moderne Debian/Linux
## Guide Complet et Rigoureux

---

## 📋 Table des Matières

1. [Fondamentaux du Pare-feu](#fondamentaux)
2. [Recommandations ANSSI](#anssi)
3. [Architecture NFTABLES](#architecture)
4. [Installation et Configuration](#installation)
5. [Syntaxe NFTABLES](#syntaxe)
6. [Tables et Chaînes](#tables-chaines)
7. [Règles de Filtrage](#regles)
8. [Stateful Filtering](#stateful)
9. [NAT et Port Forwarding](#nat)
10. [Performance et Optimisation](#performance)
11. [Persistance et Gestion](#persistance)
12. [Dépannage et Audit](#debogage)

---

## 🔐 Fondamentaux du Pare-feu {#fondamentaux}

### Pourquoi un Pare-feu ?

Un pare-feu est une barrière de sécurité réseau qui contrôle le flux de données entre un réseau sécurisé (interne) et un réseau non sécurisé (externe). Les fonctions essentielles sont :

- **Contrôle d'Accès** : Autoriser/refuser le trafic selon des règles définies
- **Prévention d'Intrusion** : Bloquer les tentatives de connexion non autorisées
- **Segmentation Réseau** : Isoler les zones en fonction des besoins de sécurité
- **Masquage NAT** : Masquer les adresses IP internes (optionnel)
- **Logging et Audit** : Enregistrer toutes les connexions pour investigation
- **Performance** : Filtrer sans surcharge système

### Évolution : iptables → nftables

#### Limites d'iptables

- **Quatre outils distincts** : iptables (IPv4), ip6tables (IPv6), arptables (ARP), ebtables (Ethernet)
- **Codes redondants** : Chaque outil avait sa propre implémentation
- **Pas de composition atomique** : Risque d'incohérence lors de mises à jour multiples
- **Langage procédural** : Difficile à maintenir et comprendre

#### Avantages de NFTABLES

- **Outil unique** : IPv4, IPv6, ARP, Ethernet dans un seul framework
- **Langage déclaratif** : Syntaxe claire et structurée
- **Transactions atomiques** : Toutes les règles mises à jour ensemble ou pas du tout
- **Performance améliorée** : Compilation JIT optimisée du noyau Linux
- **Extensibilité** : Support natif des expressions complexes et des maps
- **Portabilité** : Code reproductible et versionnable
- **Maintenance réduite** : Un seul ensemble de règles à gérer

### Architecture Générale

```
┌─────────────────────────────────────────────────────┐
│                    NFTABLES                          │
├─────────────────────────────────────────────────────┤
│  Tables (IPv4, IPv6, ARP, Bridge, Netdev)           │
│  ├─ Chaînes (INPUT, OUTPUT, FORWARD)                │
│  │  ├─ Règles (Match → Action)                      │
│  │  │  ├─ Accept, Drop, Reject, Queue, Counter    │
│  │  │  └─ Log, Limit, Jump                          │
│  │  └─ Policy (Default : ACCEPT/DROP)               │
└─────────────────────────────────────────────────────┘
       ↓         ↓          ↓         ↓
     IPv4      IPv6        ARP      Bridge
   ┌──────────────────────────────────────┐
   │      Noyau Linux (Netfilter)         │
   └──────────────────────────────────────┘
```

---

## 🛡️ Recommandations ANSSI {#anssi}

### Source Officielle ANSSI

**Document** : *Guide de l'Hygiène Informatique* (édition 2023) et *Recommandations pour la Sécurité du Pare-feu*

**Lien** : https://cyber.gouv.fr/ (rubrique publications - documents techniques)

### Recommandations Clés d'ANSSI pour Pare-feu

#### 1️⃣ Politique de Défaut (Default Policy)

```
✓ OBLIGATOIRE : Default POLICY = DROP (pour INPUT et FORWARD)
✓ OBLIGATOIRE : Default POLICY = ACCEPT (pour OUTPUT)
✓ Raisonnement : Whitelist plutôt que Blacklist

Pourquoi :
- Toute connexion non explicitement autorisée est refusée
- Réduit la surface d'attaque
- Force à documenter les besoins réseau réels
- Empêche les failles de configuration
```

**Implémentation** :
```
chain INPUT {
    type filter hook input priority 0; policy drop;
    # Règles explicites d'autorisation
}

chain FORWARD {
    type filter hook forward priority 0; policy drop;
    # Règles explicites d'autorisation
}

chain OUTPUT {
    type filter hook output priority 0; policy accept;
    # Seulement refuser si nécessaire
}
```

#### 2️⃣ Principes d'Autorisation (Allow Listing)

```
✓ OBLIGATOIRE : Autoriser explicitement chaque besoin
✓ Refuser par défaut tout ce qui n'est pas autorisé
✓ Documenter CHAQUE exception

Hiérarchie de sécurité :
1. Autoriser (accept)           ← Le plus restrictif
2. Rejeter proprement (reject)  ← Avec ICMP
3. Refuser silencieusement (drop) ← Le plus permissif
```

#### 3️⃣ Filtrage par Protocole et Port

```
✓ OBLIGATOIRE : Filtrer par protocole spécifique (TCP/UDP)
✓ OBLIGATOIRE : Limiter aux ports strictement nécessaires
✓ Éviter les plages de ports si possible
✓ Utiliser les ports IANA standardisés (https://www.iana.org/assignments/service-names-port-numbers/)

Ports critiques (protéger absolument) :
- SSH (22/TCP)      → Authentification administrative
- DNS (53/TCP+UDP)  → Résolution noms
- HTTP (80/TCP)     → Web non-chiffré
- HTTPS (443/TCP)   → Web chiffré
- SMTP (25/TCP)     → Mail sortant
- IMAP (993/TCP)    → Mail entrant
```

#### 4️⃣ Logging et Audit

```
✓ OBLIGATOIRE : Logger toutes les connexions refusées
✓ OBLIGATOIRE : Logs structurés et indexés
✓ Fréquence de rotation : Quotidienne minimum
✓ Rétention : 90 jours minimum

Configuration ANSSI :
- Niveau de log : INFO pour acceptés, WARNING pour refusés
- Prefix standardisé : "[NFTABLES-ACTION]" pour grep facile
- Incluire : timestamp, source IP, destination IP, port, protocole, action
```

#### 5️⃣ NAT et Port Forwarding

```
✓ Si NAT activé : Valider CHAQUE port forward individuellement
✓ Ne jamais autoriser port 1-1024 sans raison absolue
✓ Documentar le mappage pour chaque forward
✓ Monitorer les connexions via NAT

Exemple ANSSI compliant :
- HTTP externe 8080 → Serveur interne 192.168.1.100:80 → AUTORISÉ
- SSH externe 2222 → Serveur interne 192.168.1.50:22 → AUTORISÉ
- Tout autre port → REFUSÉ
```

#### 6️⃣ Gestion des Connexions Établies

```
✓ OBLIGATOIRE : Autoriser les paquets ESTABLISHED et RELATED
✓ Raisonnement : Sinon impossible de recevoir les réponses

État de connexion (Stateful Filtering) :
- NEW         → Nouvelle connexion (SYN)
- ESTABLISHED → Connexion existante (ACK)
- RELATED     → Connexion liée (DNS response, ICMP error)
- INVALID     → Paquet corrompu ou invalide
```

#### 7️⃣ IPv4 et IPv6

```
✓ OBLIGATOIRE : Appliquer les MÊMES règles IPv4 et IPv6
✓ Sinon : Attaquant contourne le pare-feu via IPv6
✓ Documenter : Règles identiques pour les deux familles d'adresses

Attention aux défaults :
- IPv6 Router Advertisement (RA) → Désactiver si pas besoin
- Link-local addresses (fe80::/10) → Filtrer explicitement
- Multicast (ff00::/8) → Limiter à besoins réseau locaux
```

#### 8️⃣ Règles de Prévention d'Attaques

```
✓ OBLIGATOIRE : Refuser les adresses invalides
✓ Refuser les paquets fragmentés suspects
✓ Limiter les taux de connexion (rate limiting)
✓ Refuser les ports source basse (< 1024, privilégiés)

Protections ANSSI :
- Refuser 0.0.0.0/8 (This network)
- Refuser 127.0.0.0/8 (Loopback externe)
- Refuser 169.254.0.0/16 (Link-local)
- Refuser 224.0.0.0/4 (Multicast)
- Refuser ::/128, ::1/128 sur interfaces externes (IPv6)
```

---

## 🏗️ Architecture NFTABLES {#architecture}

### Modèle de Données

```
┌──────────────────────────────────────┐
│          NFTABLES HIERARCHY          │
├──────────────────────────────────────┤
│                                      │
│  TABLE (Address Family)              │
│  ├─ CHAIN (Hook point)               │
│  │  ├─ RULE (Match + Action)         │
│  │  ├─ RULE                          │
│  │  └─ RULE (Policy: ACCEPT/DROP)    │
│  │                                   │
│  └─ SET (Collection d'éléments)      │
│     ├─ Map (Key-Value)               │
│     └─ Interval (CIDR ranges)        │
│                                      │
│  OBJECT (Limit, Quota, etc.)         │
│                                      │
└──────────────────────────────────────┘
```

### Familles d'Adresses (Address Families)

```
inet     → IPv4 et IPv6 combinés (RECOMMANDÉ)
ip       → IPv4 uniquement
ip6      → IPv6 uniquement
arp      → Protocol ARP
bridge   → Filtrage Layer 2 (Ethernet)
netdev   → Avant routing (très précoce)
```

### Points d'Accroche (Hook Points)

```
Chain Hook     Timing              Usage
─────────────────────────────────────────────────
INPUT          Paquets entrants    Connexions reçues
OUTPUT         Paquets sortants    Connexions initiées
FORWARD        Transit             Routage/NAT
PREROUTING     Avant routing       NAT destination
POSTROUTING    Après routing       NAT source

INGRESS        netdev seulement    Avant tout traitement
```

### Priorités des Hooks (ordre d'exécution)

```
-300  : mangle
-200  : dstnat (Destination NAT)
0     : filter (Défaut)
100   : srcnat (Source NAT)
200   : mangle
```

---

## 📦 Installation et Configuration {#installation}

### Vérification Prérequis

```bash
# 1. Vérifier que le noyau supporte NFTABLES
cat /boot/config-$(uname -r) | grep CONFIG_NF_TABLES
# Résultat attendu : CONFIG_NF_TABLES=m ou =y

# 2. Vérifier les modules chargés
lsmod | grep nf_tables
# Résultat : nf_tables, nft_compat, nf_conntrack, etc.

# 3. Vérifier la version d'iptables (doit avoir nft backend)
iptables --version
# Résultat : iptables v1.8.x (nf_tables)
```

### Installation sur Debian

```bash
# 1. Mettre à jour les paquets
sudo apt update

# 2. Installer NFTABLES et outils
sudo apt install -y nftables

# 3. Installer outils supplémentaires
sudo apt install -y \
    nftables \
    nft \
    ufw \
    iptables-persistent \
    conntrack

# 4. Vérifier l'installation
nft --version
# Résultat : nftables v0.9.x by Pablo Neira Ayuso

# 5. Vérifier les services
sudo systemctl status nftables
sudo systemctl status netfilter-persistent
```

### Basculer d'iptables à NFTABLES

```bash
# ⚠️ IMPORTANT : Sauvegarde des règles actuelles

# 1. Sauvegarder iptables actuelles
sudo iptables-save > ~/iptables_backup.txt
sudo ip6tables-save > ~/ip6tables_backup.txt

# 2. Charger le backend nf_tables pour iptables
update-alternatives --display iptables
# Sélectionner la version nf_tables

# Changer le lien symbolique
sudo update-alternatives --set iptables /usr/sbin/iptables-nft
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-nft
sudo update-alternatives --set arptables /usr/sbin/arptables-nft
sudo update-alternatives --set ebtables /usr/sbin/ebtables-nft

# 3. Redémarrer le service
sudo systemctl restart nftables

# 4. Vérifier la transition
sudo nft list ruleset
```

### Conversion de Règles iptables vers NFTABLES

```bash
# Convertir les règles existantes automatiquement
iptables-save | iptables-restore-translate -f - | nft -f -

# Ou pour IPv6
ip6tables-save | ip6tables-restore-translate -f - | nft -f -

# Afficher le résultat
sudo nft list ruleset

# ⚠️ ATTENTION : Vérifier avant de valider !
```

---

## 🔤 Syntaxe NFTABLES {#syntaxe}

### Fichier de Configuration

**Chemin standard** : `/etc/nftables.conf`

### Structure de Base

```nftables
#!/usr/sbin/nft -f
# NFTABLES Configuration - Format déclaratif

flush ruleset

# Définir les variables réutilisables
define IN_IFACE = "eth0"
define LAN_IFACE = "eth1"
define DNS_PORT = 53
define HTTP_PORT = 80
define HTTPS_PORT = 443
define SSH_PORT = 22

# Système de fichiers pour les sets
table ip filter {
    # Ensembles (sets) d'adresses
    set blacklist {
        type ipv4_addr
        elements = { 10.0.0.0/8, 172.16.0.0/12 }
    }
    
    set whitelist {
        type ipv4_addr
        flags interval
        elements = { 192.168.1.0/24, 192.168.2.0/24 }
    }
    
    # Définir des maps (correspondance clé-valeur)
    map port_to_protocol {
        type inet_service : string
        elements = {
            22 : "ssh",
            80 : "http",
            443 : "https",
            3306 : "mysql"
        }
    }
    
    # Chaînes (Chains)
    chain INPUT {
        type filter hook input priority 0; policy drop;
        # Règles INPUT
    }
    
    chain OUTPUT {
        type filter hook output priority 0; policy accept;
        # Règles OUTPUT
    }
    
    chain FORWARD {
        type filter hook forward priority 0; policy drop;
        # Règles FORWARD
    }
}
```

### Syntaxe des Expressions

#### Correspondance (Match) de Base

```nftables
# Protocole
meta protocol ip             # IPv4
meta protocol ipv6           # IPv6
meta protocol icmp           # ICMP
meta protocol tcp            # TCP
meta protocol udp            # UDP

# Interface réseau
iface "eth0"                 # Interface entrante
oifname "eth0"               # Interface sortante
iftype ether                 # Ethernet

# Adresses IP
ip saddr 192.168.1.0/24     # Source IPv4
ip daddr 10.0.0.0/8         # Destination IPv4
ip6 saddr fe80::/10         # Source IPv6
ip6 daddr 2001:db8::/32     # Destination IPv6

# Ports
tcp dport 22                # Port destination TCP
tcp sport 1024              # Port source TCP
udp dport 53                # Port destination UDP
{ 80, 443, 8080 }           # Énumération de ports

# État de connexion
ct state new                # Nouvelle connexion
ct state established        # Connexion établie
ct state related            # Connexion associée
ct state invalid            # Paquet invalide

# Logging
log prefix "[NFTABLES-ACCEPT]"  # Préfixe pour identification
```

#### Actions (Verdict)

```nftables
accept                      # Accepter le paquet
drop                        # Refuser silencieusement
reject                      # Rejeter avec notification ICMP
reject with icmp type host-unreachable  # Type ICMP spécifique
queue                       # Envoyer à user-space
counter                     # Incrémenter compteur
limit rate 10/minute accept # Limiter le taux
jump CHAIN_NAME             # Sauter vers autre chaîne
return                      # Revenir de chaîne
```

#### Opérateurs de Comparaison

```nftables
==                          # Égal
!=                          # Pas égal
<                           # Inférieur
>                           # Supérieur
<=                          # Inférieur ou égal
>=                          # Supérieur ou égal
in { ... }                  # Appartient à ensemble
```

### Exemple Complet : Filtrage Basique

```nftables
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain INPUT {
        type filter hook input priority 0; policy drop;
        
        # Loopback toujours autorisé
        iifname "lo" accept
        
        # Connexions établies et associées
        ct state established,related accept
        
        # Refuser les connexions invalides
        ct state invalid drop
        
        # ICMP Echo Request (ping) limité
        icmp type echo-request limit rate 1/second accept
        
        # SSH depuis n'importe où (⚠️ À restreindre en production)
        tcp dport 22 accept
        
        # DNS (résolution interne)
        udp dport 53 accept
        tcp dport 53 accept
        
        # HTTP/HTTPS public
        tcp dport { 80, 443 } accept
        
        # Refuser avec notification
        reject with icmp type host-unreachable
    }
    
    chain OUTPUT {
        type filter hook output priority 0; policy accept;
    }
    
    chain FORWARD {
        type filter hook forward priority 0; policy drop;
    }
}
```

---

## 📊 Tables et Chaînes {#tables-chaines}

### Création de Tables

```nftables
# Syntaxe générale
table ADDRESS_FAMILY TABLE_NAME {
    # Contenu (sets, maps, chains)
}

# Exemple
table inet my_firewall {
    # Toutes les règles ici
}

table ip filter {
    # IPv4 uniquement
}

table ip6 filter6 {
    # IPv6 uniquement
}
```

### Création de Chaînes

```nftables
chain CHAIN_NAME {
    type HOOK_TYPE hook HOOK_POINT priority PRIORITY; 
    policy DEFAULT_POLICY;
    # Règles
}

# Paramètres
type filter/nat/route/security   # Type de traitement
hook input/output/forward/...    # Point d'accroche
priority -300 à 300              # Ordre d'exécution
policy accept/drop               # Politique par défaut
```

### Exemple : Table Complète

```nftables
#!/usr/sbin/nft -f

flush ruleset

# Table de filtrage principal
table inet my_firewall {
    
    # Chaînes de filtrage
    chain INPUT {
        type filter hook input priority 0; policy drop;
        
        # Accepter loopback
        iifname "lo" accept
        
        # Accepter connexions établies
        ct state established,related accept
        
        # SSH limité à certains hôtes
        tcp dport 22 ip saddr 192.168.1.0/24 accept
        
        # HTTP/HTTPS publics
        tcp dport { 80, 443 } accept
        
        # Tout le reste = drop (policy)
    }
    
    chain OUTPUT {
        type filter hook output priority 0; policy accept;
    }
    
    chain FORWARD {
        type filter hook forward priority 0; policy drop;
        
        # Permettre le trafic établi
        ct state established,related accept
    }
}

# Table de NAT
table inet nat {
    chain PREROUTING {
        type nat hook prerouting priority -100; policy accept;
    }
    
    chain POSTROUTING {
        type nat hook postrouting priority 100; policy accept;
    }
}
```

---

## 🎯 Règles de Filtrage {#regles}

### Syntaxe Générale des Règles

```nftables
[add] rule [table] [chain] [condition] [action]

# Exemples
add rule inet filter INPUT tcp dport 22 accept
add rule inet filter INPUT drop

# Variantes
rule                    # Ajouter à la fin
rule position INT       # Position spécifique
rule index INT          # Index exact
```

### Catégories de Règles ANSSI

#### 1️⃣ Règles de Loopback (Toujours Première)

```nftables
# Autoriser le trafic loopback
chain INPUT {
    iifname "lo" accept
    iifname != "lo" ip daddr 127.0.0.1/8 drop
    iifname != "lo" ip6 daddr ::1/128 drop
    # ...
}
```

**Raison** : Le loopback est essentiel pour services locaux (DNS, Systemd, etc.)

#### 2️⃣ Règles de Gestion des États (Stateful)

```nftables
chain INPUT {
    # ... (loopback d'abord)
    
    # Accepter paquets établis et associés
    ct state established,related accept
    
    # Refuser explicitement les paquets invalides
    ct state invalid drop
    
    # Nouvelle connexion = traitement normal
    ct state new jump RULES_SPECIFIQUES
}
```

**Raison** : Évite les connexions ouvertes sans trace

#### 3️⃣ Règles ICMP Protection

```nftables
# Limiter ICMP (ping) pour éviter DoS
chain INPUT {
    # ...
    
    # Permettre ICMP mais limité
    icmp type echo-request limit rate 1/second accept
    
    # Autres types ICMP (time-exceeded, unreachable)
    icmp type { time-exceeded, destination-unreachable } accept
    
    # Refuser autres ICMP
    icmp type echo-reply drop
}
```

**Raison** : ICMP peut être exploité pour reconnaissance et DoS

#### 4️⃣ Règles de Ports Spécifiques

```nftables
chain INPUT {
    # ...
    
    # SSH - Limiter à réseau interne
    tcp dport 22 ip saddr 192.168.1.0/24 accept
    tcp dport 22 ip6 saddr 2001:db8::/32 accept
    
    # DNS - Limiter à serveurs de confiance
    udp dport 53 ip saddr { 8.8.8.8, 1.1.1.1 } accept
    
    # HTTP/HTTPS - Public
    tcp dport { 80, 443 } accept
    
    # MySQL - Interne uniquement
    tcp dport 3306 ip saddr 192.168.1.0/24 accept
    
    # Samba/SMB - Réseau local
    tcp dport { 137, 138, 139, 445 } ip saddr 192.168.1.0/24 accept
}
```

#### 5️⃣ Règles d'Adresses Invalides

```nftables
chain INPUT {
    # Refuser adresses RFC 5735 invalides (IPv4)
    ip saddr 0.0.0.0/8 drop              # This network
    ip saddr 10.0.0.0/8 drop             # Private (si pas LAN)
    ip saddr 127.0.0.0/8 drop            # Loopback (externe)
    ip saddr 169.254.0.0/16 drop         # Link-local
    ip saddr 172.16.0.0/12 drop          # Private (si pas LAN)
    ip saddr 192.168.0.0/16 drop         # Private (si pas LAN)
    ip saddr 224.0.0.0/4 drop            # Multicast
    ip saddr 240.0.0.0/4 drop            # Réservé
    ip saddr 255.255.255.255/32 drop     # Broadcast
    
    # Refuser adresses IPv6 invalides
    ip6 saddr ::/128 drop                # Unspecified
    ip6 saddr ::1/128 drop               # Loopback (externe)
    ip6 saddr ::ffff:0:0/96 drop         # IPv4-mapped IPv6
    ip6 saddr 100::/64 drop              # Discard prefix
    ip6 saddr fc00::/7 drop              # ULA (si pas LAN)
    ip6 saddr fe80::/10 drop             # Link-local (externe)
    ip6 saddr ff00::/8 drop              # Multicast
}
```

#### 6️⃣ Règles de Rate Limiting (Anti-DoS)

```nftables
chain INPUT {
    # Limiter les connexions SSH (prévenir brute-force)
    tcp dport 22 limit rate 5/minute accept
    
    # Limiter HTTP (éviter flood)
    tcp dport 80 limit rate 100/second accept
    
    # Limiter ICMP (éviter ping flood)
    icmp type echo-request limit rate 10/second accept
    
    # Limiter les nouvelles connexions UDP
    udp dport 53 limit rate 10/second accept
    
    # Refuser les restes
    drop
}
```

**Raison** : Prévention contre attaques par déni de service

---

## 🔄 Stateful Filtering {#stateful}

### Concepts d'État (Connection Tracking)

```
État        Explication                 Action ANSSI
─────────────────────────────────────────────────────
NEW         Nouveau SYN (initiation)    Valider ou refuser
ESTABLISHED SYN-ACK établi              TOUJOURS ACCEPTER
RELATED     Connexion liée (DNS resp)   ACCEPTER
INVALID     Corrompu, invalide          TOUJOURS REFUSER
```

### Configuration du Connection Tracking

```nftables
table inet filter {
    chain INPUT {
        type filter hook input priority 0; policy drop;
        
        # Étape 1 : Loopback
        iifname "lo" accept
        
        # Étape 2 : Connexions établies (critère ESSENTIEL)
        ct state established,related {
            counter
            accept
        }
        
        # Étape 3 : Refuser les invalides
        ct state invalid {
            counter
            drop
        }
        
        # Étape 4 : Nouvelles connexions (vérifier explicitement)
        ct state new {
            # Seulement les ports autorisés
            tcp dport { 22, 80, 443 } accept
            drop  # Tout autre port
        }
    }
}
```

### Tuning Connection Tracking

```bash
# Vérifier les paramètres du conntrack
cat /proc/sys/net/netfilter/nf_conntrack_max

# Augmenter la limite (si besoin)
sudo sysctl -w net.netfilter.nf_conntrack_max=131072

# Faire persister les changements
echo "net.netfilter.nf_conntrack_max=131072" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Vérifier les connexions actuelles
sudo conntrack -L

# Compter les connexions par protocole
sudo conntrack -L -o extended | awk '{print $1}' | sort | uniq -c
```

---

## 🔀 NAT et Port Forwarding {#nat}

### Destination NAT (DNAT) - Port Forwarding

**Cas d'Usage** : Rediriger trafic externe vers serveur interne

```nftables
table inet nat {
    chain PREROUTING {
        type nat hook prerouting priority -100; policy accept;
        
        # Rediriger port 8080 externe vers port 80 interne
        iifname "eth0" \
            tcp dport 8080 \
            dnat to 192.168.1.100:80
        
        # Rediriger SSH sur port 2222 vers serveur interne
        iifname "eth0" \
            tcp dport 2222 \
            dnat to 192.168.1.50:22
        
        # HTTPS depuis WAN vers serveur interne HTTPS
        iifname "eth0" \
            tcp dport 443 \
            dnat to 192.168.1.100:443
    }
}
```

### Source NAT (SNAT) - Masquage d'Adresses

**Cas d'Usage** : Masquer les adresses IP internes pour internet

```nftables
table inet nat {
    chain POSTROUTING {
        type nat hook postrouting priority 100; policy accept;
        
        # Masquer le trafic LAN sortant avec l'IP du routeur
        oifname "eth0" \
            ip saddr 192.168.1.0/24 \
            snat to 203.0.113.1  # IP publique routeur
        
        # Masquerade simplifié (si IP publique dynamique)
        oifname "eth0" \
            ip saddr 192.168.1.0/24 \
            masquerade
    }
}
```

### Configuration Complète NAT + Filter

```nftables
#!/usr/sbin/nft -f

flush ruleset

define WAN_IFACE = "eth0"
define LAN_IFACE = "eth1"
define WAN_IP = "203.0.113.1"
define DMZ_SUBNET = "192.168.100.0/24"
define LAN_SUBNET = "192.168.1.0/24"

table inet mangle {
    chain PREROUTING {
        type filter hook prerouting priority -150; policy accept;
    }
}

table inet nat {
    chain PREROUTING {
        type nat hook prerouting priority -100; policy accept;
        
        # Port forwarding HTTP
        iifname $WAN_IFACE \
            tcp dport 80 \
            dnat to 192.168.100.10:80
        
        # Port forwarding HTTPS
        iifname $WAN_IFACE \
            tcp dport 443 \
            dnat to 192.168.100.10:443
        
        # Port forwarding SSH alternatif
        iifname $WAN_IFACE \
            tcp dport 2222 \
            dnat to 192.168.100.20:22
    }
    
    chain POSTROUTING {
        type nat hook postrouting priority 100; policy accept;
        
        # Masquerader trafic interne sortant
        oifname $WAN_IFACE \
            ip saddr $LAN_SUBNET \
            masquerade
        
        # SNAT explicite pour DMZ
        oifname $WAN_IFACE \
            ip saddr $DMZ_SUBNET \
            snat to $WAN_IP
    }
}

table inet filter {
    chain INPUT {
        type filter hook input priority 0; policy drop;
        
        # Loopback
        iifname "lo" accept
        
        # États établis
        ct state established,related accept
        
        # SSH admin sur interface LAN uniquement
        iifname $LAN_IFACE tcp dport 22 accept
        
        # Tout le reste : drop
    }
    
    chain OUTPUT {
        type filter hook output priority 0; policy accept;
    }
    
    chain FORWARD {
        type filter hook forward priority 0; policy drop;
        
        # Connexions établies
        ct state established,related accept
        
        # LAN vers WAN (sortant)
        iifname $LAN_IFACE oifname $WAN_IFACE accept
        
        # WAN vers DMZ (DNAT)
        iifname $WAN_IFACE oifname "eth2" accept
        
        # DMZ vers LAN (interdit)
        iifname "eth2" oifname $LAN_IFACE drop
        
        # Tout le reste : drop (policy)
    }
}
```

---

## ⚡ Performance et Optimisation {#performance}

### Mesure de Performance

```bash
# Vérifier la charge du système
top -p $(pidof nft)

# Statistiques des tables
sudo nft list tables
sudo nft list chains

# Compteurs des règles
sudo nft list ruleset -a

# Monitor traffic in real-time
watch -n 1 'sudo nft list ruleset | grep counter'
```

### Optimisations ANSSI Recommandées

#### 1️⃣ Ordre des Règles (Criticité)

```nftables
chain INPUT {
    type filter hook input priority 0; policy drop;
    
    # Ordre optimal :
    # 1. Loopback (très fréquent, doit être rapide)
    iifname "lo" accept
    
    # 2. Connexions établies (majorité du trafic)
    ct state established,related accept
    
    # 3. Invalides (refuser rapidement)
    ct state invalid drop
    
    # 4. Stateless rules (ICMP, UDP, etc.)
    icmp type echo-request limit rate 1/second accept
    
    # 5. TCP services (moins fréquent)
    tcp dport 22 accept
    tcp dport { 80, 443 } accept
    
    # 6. Refuser le reste
    drop
}
```

**Raison** : Les règles les plus fréquentes en premier = moins d'évaluation

#### 2️⃣ Utiliser les Sets pour Énumérations

```nftables
# ✗ MAUVAIS (plusieurs règles)
chain INPUT {
    tcp dport 22 accept
    tcp dport 80 accept
    tcp dport 443 accept
    tcp dport 3306 accept
}

# ✓ BON (une seule règle avec set)
table inet filter {
    set allowed_ports {
        type inet_service
        elements = { 22, 80, 443, 3306 }
    }
    
    chain INPUT {
        tcp dport @allowed_ports accept
    }
}
```

#### 3️⃣ Maps pour Mappages Complexes

```nftables
table inet filter {
    # Map port → description
    map port_description {
        type inet_service : string
        elements = {
            22 : "ssh",
            80 : "http",
            443 : "https",
            3306 : "mysql",
            5432 : "postgresql"
        }
    }
    
    map port_ratelimit {
        type inet_service : rate
        elements = {
            22 : "5/minute",
            80 : "1000/second",
            443 : "1000/second"
        }
    }
}
```

---

## 💾 Persistance et Gestion {#persistance}

### Sauvegarde et Restauration

```bash
# Sauvegarde du ruleset actuel
sudo nft list ruleset > ~/nftables_backup.conf

# Sauvegarder avec plus de détails
sudo nft list ruleset -a > ~/nftables_rules_counters.txt

# Restauration
sudo nft -f ~/nftables_backup.conf

# Ajouter les règles sans flush (pré-caution)
sudo nft -f -i ~/nftables_rules.conf
```

### Fichier de Configuration Systématique

```bash
# Créer le fichier de configuration
sudo nano /etc/nftables.conf
```

**Contenu** (voir sections précédentes pour détails)

```bash
# Activer et redémarrer le service
sudo systemctl enable nftables
sudo systemctl restart nftables

# Vérifier l'état
sudo systemctl status nftables

# Logs du démarrage
sudo journalctl -u nftables -n 20
```

### Script de Chargement Sécurisé

```bash
#!/bin/bash
# Script de déploiement sécurisé des règles NFTABLES

set -e

NFTABLES_FILE="${1:?Usage: $0 <nftables.conf>}"
BACKUP_DIR="/var/backups/nftables"
TIMEOUT=30

echo "[*] Vérification du fichier..."
sudo nft -c -f "$NFTABLES_FILE" || {
    echo "[!] Erreur de syntaxe!"
    exit 1
}

echo "[*] Sauvegarde de la configuration actuelle..."
mkdir -p "$BACKUP_DIR"
sudo nft list ruleset > "$BACKUP_DIR/nftables_$(date +%Y%m%d_%H%M%S).conf"

echo "[*] Chargement des nouvelles règles..."
sudo nft -f "$NFTABLES_FILE"

echo "[*] Vérification pendant $TIMEOUT secondes..."
sleep $TIMEOUT

if sudo nft list ruleset > /dev/null 2>&1; then
    echo "[✓] Configuration acceptée"
else
    echo "[!] Rollback à la configuration précédente"
    sudo nft -f "$BACKUP_DIR/nftables_$(ls -t $BACKUP_DIR | head -1)"
fi
```

---

## 🔍 Dépannage et Audit {#debogage}

### Commandes d'Audit

```bash
# Afficher la configuration complète
sudo nft list ruleset

# Afficher avec détails (incluant compteurs)
sudo nft list ruleset -a

# Afficher une table spécifique
sudo nft list table inet filter

# Afficher une chaîne spécifique
sudo nft list chain inet filter INPUT

# Monitorer en temps réel
watch -n 1 'sudo nft list ruleset'

# Exporter en JSON
sudo nft -j list ruleset | jq .
```

### Vérification des Règles

```bash
# Test de ping
ping -c 2 <adresse_test>

# Test de port (TCP)
telnet <adresse> <port>
# Ou
nc -zv <adresse> <port>

# Test SSH
ssh -v <utilisateur>@<serveur>

# Monitor les paquets acceptés/refusés
sudo tcpdump -i <interface> -n 'tcp port 22'

# Afficher les statistiques par port
ss -tlnp | grep LISTEN

# Vérifier les connexions actuelles
netstat -plnt
```

### Debugging Avancé

```bash
# Voir les paquets passant par netfilter
sudo modprobe nfnetlink_log
sudo iptables -I INPUT -j NFLOG --nflog-prefix "DEBUG-INPUT: "

# Monitor via journalctl
sudo journalctl -f | grep NFTABLES

# Logs au niveau kernel
sudo dmesg | tail -50

# Analyser les logs avec tcpdump
sudo tcpdump -i <interface> -w capture.pcap
wireshark capture.pcap  # Analyse visuelle
```

---

## 📚 Références Officielles et Documentation

### Documentation Officielle

**1. Man pages NFTABLES**
```bash
man nft                 # Manuel complet
man nft-lang           # Langage
man nftables           # Page d'accueil
```

**2. Wiki Netfilter (Référence Autoritaire)**
- https://wiki.nftables.org/
- https://github.com/netfilter/nftables/wiki

**3. RFC et Standards**
- RFC 3022 : Traditional IP Network Address Translator (NAT)
- RFC 5735 : Special Use IPv4 Addresses
- RFC 6890 : Special Use IP Addresses

**4. Documentation ANSSI**
- https://cyber.gouv.fr/ (publications techniques)
- Guide d'hygiène informatique 2023

### Exemples de Configuration Complète

```nftables
#!/usr/sbin/nft -f

# Configuration firewall serveur Debian - ANSSI Compliant

flush ruleset

define SSH_PORT = 22
define HTTP_PORT = 80
define HTTPS_PORT = 443
define LAN = 192.168.1.0/24
define DNS_SERVERS = { 8.8.8.8, 1.1.1.1 }

table inet filter {
    set blacklist {
        type ipv4_addr
        flags interval
        elements = { }
    }
    
    set trusted_ssh {
        type ipv4_addr
        elements = { 192.168.1.0/24 }
    }
    
    chain INPUT {
        type filter hook input priority 0; policy drop;
        
        # Loopback
        iifname "lo" accept comment "Allow loopback"
        
        # États
        ct state established,related accept comment "Allow established"
        ct state invalid drop comment "Drop invalid"
        
        # Blacklist
        ip saddr @blacklist drop comment "Drop blacklisted"
        
        # ICMP limité
        icmp type echo-request limit rate 1/second accept comment "Rate-limit ping"
        
        # SSH restreint
        tcp dport $SSH_PORT ip saddr @trusted_ssh accept comment "SSH from trusted"
        
        # Public services
        tcp dport { $HTTP_PORT, $HTTPS_PORT } accept comment "HTTP/HTTPS"
        
        # Logs avant refus
        ip saddr @blacklist log prefix "[NFTABLES-DROP] " drop
        
        # Defaut = drop (voir policy)
    }
    
    chain OUTPUT {
        type filter hook output priority 0; policy accept;
    }
    
    chain FORWARD {
        type filter hook forward priority 0; policy drop;
    }
}

table inet nat {
    chain PREROUTING {
        type nat hook prerouting priority -100; policy accept;
    }
    
    chain POSTROUTING {
        type nat hook postrouting priority 100; policy accept;
    }
}
```

---

**Document généré le** : 16 novembre 2025
**Conformité** : ANSSI 2023 | Debian 12+ | NFTABLES 0.9+
**Révision** : 1.0
