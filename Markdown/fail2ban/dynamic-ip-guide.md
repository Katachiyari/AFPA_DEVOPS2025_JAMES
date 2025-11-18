# 🌐 Gestion des Adresses IP Dynamiques avec Fail2Ban

## 🎯 Votre Situation

Vous vous connectez jamais avec la **même adresse IP** → Vous avez une **IP dynamique** (elle change régulièrement).

**Problème** : Si vous whitelist une IP fixe, vous serez bloqué quand votre IP changera.

**Solutions** : Il existe **4 approches** selon votre cas d'usage.

---

## 📊 Comparaison des Solutions

| Solution | Facilité | Sécurité | Idéale pour | Coût |
|----------|----------|----------|------------|------|
| **1. CIDR Range** | ⭐⭐ | ⭐⭐⭐ | ISP avec même range | Gratuit |
| **2. DNS Dynamique** | ⭐⭐⭐ | ⭐⭐ | Mobile/VPN changement fréquent | Gratuit/Payant |
| **3. Script Auto-update** | ⭐⭐⭐⭐ | ⭐⭐⭐ | Professionnel, multiples IPs | Gratuit |
| **4. ignorecommand** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Maximum flexibilité | Gratuit |

---

## 🔴 Solution 1 : CIDR Range (Plus Simple)

### Concept
Au lieu de whitelister **une seule IP**, whitelister **tout le range (subnet)** d'où viennent vos IPs.

### Exemple
```
Votre ISP attribue des IPs dans le range : 203.0.113.0/24
Cela signifie : 203.0.113.1 à 203.0.113.254 (256 IPs)

Plutôt que de whitelist une IP fixe
Whitelister : 203.0.113.0/24
```

### 📍 Comment Trouver Votre Range

```bash
# 1. Découvrir votre IP actuelle
curl -s https://api.ipify.org

# Affichage : 203.0.113.50

# 2. Découvrir le range CIDR avec whois
whois 203.0.113.50 | grep -i "CIDR\|inetnum\|route"

# Affichage attendu :
# CIDR: 203.0.113.0/24

# 3. Sinon, demander à votre ISP
# Généralement : XXX.XXX.XXX.0/24 ou /23 ou /22

# 4. Estimation simple : prendre /24 (256 IPs)
# Exemple : si votre IP est 203.0.113.50
# Utiliser : 203.0.113.0/24
```

### ✅ Implémentation

```bash
# 1. Éditer jail.local
sudo nano /etc/fail2ban/jail.local

# 2. Trouver la section [DEFAULT]
# 3. Remplacer :
# ignoreip = 127.0.0.1/8 ::1

# Par (exemple) :
# ignoreip = 127.0.0.1/8 ::1 203.0.113.0/24

# 4. Sauvegarder et redémarrer
sudo systemctl restart fail2ban

# 5. Vérifier
sudo fail2ban-client status sshd
```

### ⚠️ Avantages et Inconvénients

**Avantages** :
- ✅ Simple et rapide
- ✅ Aucune maintenance requise
- ✅ Pas d'API externe

**Inconvénients** :
- ❌ Whitelist TOUT le range (autres personnes sur le même ISP)
- ❌ Possible seulement si IP dans un même range
- ❌ Moins sécurisé (whiteliste trop large)

**Idéal pour** : IP qui changent mais dans le même range ISP

---

## 🟢 Solution 2 : DNS Dynamique (Recommandé pour Mobiles/VPN)

### Concept
Au lieu d'une IP fixe, utiliser un **nom de domaine** qui pointe vers votre IP actuelle.

Quand votre IP change → domaine se met à jour automatiquement → fail2ban ignore la nouvelle IP.

### 🔧 Configuration

#### Étape 1 : Créer un DNS Dynamique

**Options gratuites** :
- [DuckDNS](https://www.duckdns.org/) - Très facile
- [No-IP](https://www.noip.com/) - Classique
- [Zonomi](https://zonomi.com/) - Simple
- [FreeDNS](https://freedns.afraid.org/) - Gratuit

**Option payante** :
- Votre registrar (Namecheap, GoDaddy, etc.)

#### Étape 2 : Configuration sur DuckDNS (Exemple)

```bash
# 1. Créer un compte sur https://www.duckdns.org/

# 2. Créer un domaine (ex: monserveur.duckdns.org)

# 3. Installer le client de mise à jour
sudo apt-get install duckdns -y

# 4. Configurer
sudo nano /etc/duckdns/duckdns.conf

# Ajouter :
# DOMAINS=monserveur.duckdns.org
# TOKEN=votre_token_duckdns

# 5. Activer le service
sudo systemctl enable duckdns
sudo systemctl start duckdns

# 6. Tester
nslookup monserveur.duckdns.org
# Doit afficher votre IP actuelle
```

#### Étape 3 : Configurer Fail2Ban avec DNS

```bash
# 1. Éditer jail.local
sudo nano /etc/fail2ban/jail.local

# 2. Changer ignoreip :
# Avant :
# ignoreip = 127.0.0.1/8 ::1 203.0.113.50

# Après (utiliser le domaine) :
# ignoreip = 127.0.0.1/8 ::1 monserveur.duckdns.org

# 3. Sauvegarder et redémarrer
sudo systemctl restart fail2ban

# 4. Vérifier que fail2ban résout le domaine
sudo fail2ban-client status
```

### 🎯 Automatisation avec Script

Créer un script qui met à jour fail2ban quand l'IP change :

```bash
#!/bin/bash
# /opt/scripts/update-fail2ban-dns.sh

# Récupérer l'IP actuelle depuis le DNS
CURRENT_IP=$(dig +short monserveur.duckdns.org @8.8.8.8 | tail -n1)

# Récupérer l'IP whitelist actuelle dans fail2ban
WHITELISTED_IP=$(sudo fail2ban-client status sshd 2>/dev/null | \
  grep -i "ignoreip" || echo "")

# Si l'IP a changé
if [ "$CURRENT_IP" != "$WHITELISTED_IP" ]; then
    echo "[$(date)] IP changée de $WHITELISTED_IP à $CURRENT_IP"
    
    # Recharger fail2ban pour que le DNS se résolve
    sudo systemctl reload fail2ban
    
    # Optionnel : envoyer une alerte
    echo "Fail2Ban whitelist mise à jour. Nouvelle IP : $CURRENT_IP" | \
      mail -s "IP Whitelist Fail2Ban" admin@example.com
fi
```

**Installer le script** :
```bash
# Copier le script
sudo nano /opt/scripts/update-fail2ban-dns.sh
sudo chmod +x /opt/scripts/update-fail2ban-dns.sh

# Ajouter à cron (exécuter toutes les 5 minutes)
sudo crontab -e

# Ajouter la ligne :
# */5 * * * * /opt/scripts/update-fail2ban-dns.sh >> /var/log/fail2ban-dns-update.log 2>&1
```

### ✅ Avantages et Inconvénients

**Avantages** :
- ✅ Fonctionne avec ANY IP (même de providers différents)
- ✅ Automatique une fois configuré
- ✅ Peu d'infrastructure requise

**Inconvénients** :
- ❌ Dépend d'un service DNS tiers
- ❌ TTL peut causer des délais
- ❌ Pas immédiat lors d'un changement d'IP

**Idéal pour** : Mobile, VPN, connexions fréquemment changeantes

---

## 🔵 Solution 3 : Script Auto-Update (Professionnel)

### Concept
Un script automatique qui :
1. Détecte votre IP externe actuelle
2. Compare avec celle en whitelist
3. Met à jour fail2ban si ça a changé
4. Log les changements

### 📝 Script Complet

```bash
#!/bin/bash
# /opt/scripts/fail2ban-dynamic-whitelist.sh
# Gère automatiquement la whitelist fail2ban pour IP dynamique

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

# Jail à mettre à jour
JAIL_NAME="sshd"

# Service fail2ban
FAIL2BAN_SERVICE="fail2ban"

# Fichier de configuration
CONFIG_FILE="/etc/fail2ban/jail.local"

# Fichier de log
LOG_FILE="/var/log/fail2ban-dynamic-whitelist.log"

# Fichier de cache (IP précédente)
CACHE_FILE="/tmp/fail2ban_whitelist_ip_cache.txt"

# Méthode pour obtenir l'IP
# Options : curl, wget, dig
GET_IP_METHOD="curl"

# ============================================================================
# FONCTIONS
# ============================================================================

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Obtenir l'IP externe
get_external_ip() {
    case "$GET_IP_METHOD" in
        curl)
            curl -s https://api.ipify.org || echo ""
            ;;
        wget)
            wget -qO- https://api.ipify.org || echo ""
            ;;
        dig)
            dig +short myip.opendns.com @resolver1.opendns.com || echo ""
            ;;
        *)
            log_message "ERREUR : Méthode GET_IP_METHOD inconnue"
            return 1
            ;;
    esac
}

# Obtenir l'IP actuellement whitelistée
get_whitelisted_ip() {
    grep "^ignoreip" "$CONFIG_FILE" | \
      sed 's/.*ignoreip = //' | \
      awk '{print $NF}' || echo ""
}

# Mettre à jour la whitelist dans le fichier de config
update_whitelist() {
    local NEW_IP="$1"
    local OLD_IP="$2"
    
    log_message "Mise à jour de la whitelist : $OLD_IP → $NEW_IP"
    
    # Créer une sauvegarde
    sudo cp "$CONFIG_FILE" "$CONFIG_FILE.backup-$(date +%Y%m%d-%H%M%S)"
    
    # Remplacer l'IP dans le fichier
    if [ -z "$OLD_IP" ] || [ "$OLD_IP" = "127.0.0.1/8" ]; then
        # Première configuration
        sudo sed -i "s/^ignoreip = .*/ignoreip = 127.0.0.1\/8 ::1 $NEW_IP/" "$CONFIG_FILE"
    else
        # Remplacer l'ancienne IP
        sudo sed -i "s/$OLD_IP/$NEW_IP/g" "$CONFIG_FILE"
    fi
    
    return 0
}

# Recharger fail2ban sans perdre les bans actuels
reload_fail2ban() {
    log_message "Rechargement de fail2ban..."
    sudo systemctl reload "$FAIL2BAN_SERVICE"
    
    if [ $? -eq 0 ]; then
        log_message "✓ Fail2ban rechargé avec succès"
        return 0
    else
        log_message "✗ ERREUR lors du rechargement de fail2ban"
        return 1
    fi
}

# Vérifier la syntaxe du fichier de config
verify_config() {
    sudo fail2ban-client -t > /dev/null 2>&1
    return $?
}

# Envoyer une notification
send_notification() {
    local OLD_IP="$1"
    local NEW_IP="$2"
    
    # Email (optionnel)
    # echo "Fail2Ban whitelist mise à jour : $OLD_IP → $NEW_IP" | \
    #   mail -s "Alerte : IP Dynamique Changée" admin@example.com
    
    # Syslog
    logger -t fail2ban-dynamic "[WHITELIST] IP changée de $OLD_IP à $NEW_IP"
}

# ============================================================================
# MAIN
# ============================================================================

log_message "====== Début de la vérification IP dynamique ======"

# Vérifier que nous sommes root
if [ "$EUID" -ne 0 ]; then
    log_message "ERREUR : Ce script doit être exécuté en tant que root"
    exit 1
fi

# Obtenir l'IP actuelle
CURRENT_IP=$(get_external_ip)

if [ -z "$CURRENT_IP" ]; then
    log_message "ERREUR : Impossible d'obtenir l'IP externe"
    exit 1
fi

# Obtenir l'IP précédente du cache
if [ -f "$CACHE_FILE" ]; then
    PREVIOUS_IP=$(cat "$CACHE_FILE")
else
    PREVIOUS_IP=""
fi

# Obtenir l'IP actuellement whitelistée
WHITELISTED_IP=$(get_whitelisted_ip)

log_message "IP précédente : $PREVIOUS_IP"
log_message "IP actuelle : $CURRENT_IP"
log_message "IP whitelistée : $WHITELISTED_IP"

# Si l'IP a changé
if [ "$CURRENT_IP" != "$PREVIOUS_IP" ]; then
    log_message "📢 CHANGEMENT D'IP DÉTECTÉ !"
    
    # Mettre à jour le cache
    echo "$CURRENT_IP" > "$CACHE_FILE"
    
    # Mettre à jour la whitelist si différente
    if [ "$CURRENT_IP" != "$WHITELISTED_IP" ]; then
        if update_whitelist "$CURRENT_IP" "$WHITELISTED_IP"; then
            # Vérifier la syntaxe
            if verify_config; then
                # Recharger fail2ban
                if reload_fail2ban; then
                    send_notification "$WHITELISTED_IP" "$CURRENT_IP"
                    log_message "✓ Whitelist mise à jour avec succès"
                else
                    log_message "✗ ERREUR lors du rechargement"
                    exit 1
                fi
            else
                log_message "✗ ERREUR de syntaxe dans la configuration"
                # Restaurer la sauvegarde
                sudo cp "$CONFIG_FILE.backup-"* "$CONFIG_FILE"
                exit 1
            fi
        fi
    else
        log_message "IP déjà whitelistée, aucune action requise"
    fi
else
    log_message "✓ IP inchangée, rien à faire"
fi

log_message "====== Fin de la vérification IP dynamique ======"
exit 0
```

**Installation** :
```bash
# 1. Créer le script
sudo nano /opt/scripts/fail2ban-dynamic-whitelist.sh

# 2. Rendre exécutable
sudo chmod +x /opt/scripts/fail2ban-dynamic-whitelist.sh

# 3. Tester
sudo bash /opt/scripts/fail2ban-dynamic-whitelist.sh

# 4. Ajouter à cron (toutes les 5 minutes)
sudo crontab -e

# Ajouter :
# */5 * * * * /opt/scripts/fail2ban-dynamic-whitelist.sh

# 5. Vérifier les logs
sudo tail -f /var/log/fail2ban-dynamic-whitelist.log
```

### ✅ Avantages et Inconvénients

**Avantages** :
- ✅ Totalement automatique
- ✅ Contrôle total sur la logique
- ✅ Peut gérer plusieurs IPs
- ✅ Logs détaillés

**Inconvénients** :
- ❌ Demande maintenance du script
- ❌ Nécessite cron/systemd timer
- ❌ Plus complexe à setup

**Idéal pour** : Utilisateurs avancés, production, multiples serveurs

---

## 🟣 Solution 4 : ignorecommand (Maximum Flexibilité)

### Concept
Utiliser un **commande personnalisée** que fail2ban exécute pour vérifier si une IP doit être ignorée.

### 📝 Implémentation

#### Étape 1 : Créer le script de vérification

```bash
#!/bin/bash
# /opt/scripts/check-whitelist.sh
# Script appelé par fail2ban pour vérifier si une IP doit être ignorée

IP=$1

# Récupérer votre IP dynamique
MY_IP=$(curl -s https://api.ipify.org)

# Vérifier si c'est votre IP
if [ "$IP" = "$MY_IP" ]; then
    exit 0  # Ignorer (exit 0 = ignorer)
fi

# Ignorer aussi localhost
if [[ "$IP" =~ ^127\. ]] || [ "$IP" = "::1" ]; then
    exit 0
fi

# Sinon, ne pas ignorer (exit 1 = bannir normalement)
exit 1
```

#### Étape 2 : Configurer Fail2Ban

```bash
# 1. Rendre le script exécutable
sudo chmod +x /opt/scripts/check-whitelist.sh

# 2. Éditer jail.local
sudo nano /etc/fail2ban/jail.local

# 3. Dans la section [DEFAULT], ajouter :
# ignorecommand = /opt/scripts/check-whitelist.sh <IP>

# 4. Redémarrer fail2ban
sudo systemctl restart fail2ban
```

**Exemple complet dans jail.local** :
```ini
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
ignorecommand = /opt/scripts/check-whitelist.sh <IP>
bantime = 3600
findtime = 600
maxretry = 3
```

### ✅ Avantages et Inconvénients

**Avantages** :
- ✅ Extrêmement flexible
- ✅ Peut implémenter n'importe quelle logique
- ✅ Dynamique (mis à jour à chaque tentative)

**Inconvénients** :
- ❌ Appelle un script pour CHAQUE tentative (performance)
- ❌ Plus lent que les autres méthodes
- ❌ Complexe à déboguer

**Idéal pour** : Cas très spécialisés, logique complexe

---

## 📋 Comparaison Finale et Recommandations

### Pour Vous (IP Dynamique)

**Votre situation** : Connexion qui change d'IP régulièrement

**Meilleure solution** : **Solution 2 (DNS Dynamique)** ou **Solution 3 (Script Auto-Update)**

### Recommandation Personnalisée

| Cas | Solution | Raison |
|-----|----------|--------|
| **ISP avec range fixe** (ex: Proximus, Orange) | **Solution 1 : CIDR** | Plus simple, moins de maintenance |
| **Mobile/VPN changeant** | **Solution 2 : DNS** | Automatique, fiable |
| **Plusieurs appareils/locations** | **Solution 3 : Script** | Contrôle complet |
| **Logique complexe personnalisée** | **Solution 4 : ignorecommand** | Maximum flexibilité |

---

## 🚀 Quick Start : Solution DNS (Recommandée)

### En 5 Étapes

```bash
# 1. Créer compte DuckDNS sur https://www.duckdns.org/

# 2. Installer client DuckDNS
sudo apt-get install duckdns -y

# 3. Configurer
sudo nano /etc/duckdns/duckdns.conf
# DOMAINS=monserveur.duckdns.org
# TOKEN=votre_token

# 4. Éditer jail.local
sudo nano /etc/fail2ban/jail.local
# ignoreip = 127.0.0.1/8 ::1 monserveur.duckdns.org

# 5. Redémarrer
sudo systemctl restart fail2ban
```

---

## 🔍 Vérification

```bash
# Vérifier votre IP actuelle
curl -s https://api.ipify.org

# Vérifier la whitelist fail2ban
sudo fail2ban-client status sshd | grep -i "ignoreip"

# Tester avec dig (DNS)
dig monserveur.duckdns.org +short

# Voir les logs de mise à jour
sudo tail -f /var/log/fail2ban-dynamic-whitelist.log
```

---

## 📌 Checklist Implémentation

### Solution 1 (CIDR) :
- [ ] Découvrir votre range CIDR avec `whois`
- [ ] Éditer `/etc/fail2ban/jail.local`
- [ ] Ajouter le range dans `ignoreip`
- [ ] Tester : `ssh -p 2545 user@serveur`

### Solution 2 (DNS) :
- [ ] Créer compte DuckDNS
- [ ] Installer client DDNS
- [ ] Configurer `/etc/duckdns/duckdns.conf`
- [ ] Éditer `ignoreip` avec domaine
- [ ] Tester : `nslookup monserveur.duckdns.org`

### Solution 3 (Script) :
- [ ] Créer `/opt/scripts/fail2ban-dynamic-whitelist.sh`
- [ ] Rendre exécutable
- [ ] Ajouter à cron
- [ ] Vérifier logs

