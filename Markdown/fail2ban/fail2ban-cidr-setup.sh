#!/bin/bash

################################################################################
# SCRIPT D'IMPLÉMENTATION SOLUTION 1 : CIDR RANGE
#
# Ce script automatise complètement la découverte et la configuration
# d'un range CIDR pour whitelist les IPs dynamiques dans fail2ban
#
# Utilisation : sudo bash fail2ban-cidr-setup.sh
#
# Prérequis : whois, curl, fail2ban déjà installé
################################################################################

set -e

# ============================================================================
# SECTION 1 : INITIALISATION ET COULEURS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Fichiers de configuration
CONFIG_FILE="/etc/fail2ban/jail.local"
BACKUP_FILE="/etc/fail2ban/jail.local.backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/var/log/fail2ban-cidr-setup.log"

# ============================================================================
# SECTION 2 : FONCTIONS D'AFFICHAGE
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓ SUCCÈS]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[✗ ERREUR]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[⚠ ATTENTION]${NC} $1" | tee -a "$LOG_FILE"
}

log_section() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}$1${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
}

# ============================================================================
# SECTION 3 : VÉRIFICATIONS PRÉALABLES
# ============================================================================

log_section "ÉTAPE 1 : VÉRIFICATIONS PRÉALABLES"

# Vérifier root
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi
log_success "Exécuté en tant que root"

# Vérifier fail2ban installé
if ! command -v fail2ban-client &> /dev/null; then
    log_error "fail2ban n'est pas installé"
    log_info "Installez d'abord avec : sudo apt-get install fail2ban -y"
    exit 1
fi
log_success "fail2ban est installé"

# Vérifier whois installé
if ! command -v whois &> /dev/null; then
    log_warning "whois n'est pas installé, installation..."
    apt-get install -y whois > /dev/null 2>&1
    log_success "whois installé"
fi

# Vérifier curl installé
if ! command -v curl &> /dev/null; then
    log_warning "curl n'est pas installé, installation..."
    apt-get install -y curl > /dev/null 2>&1
    log_success "curl installé"
fi

# Vérifier le fichier jail.local existe
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Le fichier $CONFIG_FILE n'existe pas"
    log_info "Créez d'abord fail2ban avec le script d'installation principal"
    exit 1
fi
log_success "Fichier de configuration trouvé"

# ============================================================================
# SECTION 4 : DÉCOUVERTE DE L'IP ACTUELLE
# ============================================================================

log_section "ÉTAPE 2 : DÉCOUVERTE DE VOTRE IP ACTUELLE"

log_info "Récupération de votre adresse IP externe..."

# Essayer plusieurs méthodes pour obtenir l'IP
CURRENT_IP=""

# Méthode 1 : curl ipify
if [ -z "$CURRENT_IP" ]; then
    CURRENT_IP=$(curl -s https://api.ipify.org 2>/dev/null | grep -oE '^[0-9\.]+$' || echo "")
    if [ -n "$CURRENT_IP" ]; then
        log_success "IP récupérée via ipify.org : $CURRENT_IP"
    fi
fi

# Méthode 2 : OpenDNS
if [ -z "$CURRENT_IP" ]; then
    CURRENT_IP=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null | grep -oE '^[0-9\.]+$' || echo "")
    if [ -n "$CURRENT_IP" ]; then
        log_success "IP récupérée via OpenDNS : $CURRENT_IP"
    fi
fi

# Méthode 3 : ifconfig.me
if [ -z "$CURRENT_IP" ]; then
    CURRENT_IP=$(curl -s https://ifconfig.me/ 2>/dev/null | grep -oE '^[0-9\.]+$' || echo "")
    if [ -n "$CURRENT_IP" ]; then
        log_success "IP récupérée via ifconfig.me : $CURRENT_IP"
    fi
fi

# Si toujours pas d'IP
if [ -z "$CURRENT_IP" ]; then
    log_error "Impossible d'obtenir votre IP externe"
    log_info "Vérifiez votre connexion réseau ou spécifiez l'IP manuellement"
    exit 1
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
echo -e "${CYAN}Votre IP actuelle : ${GREEN}$CURRENT_IP${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"

# ============================================================================
# SECTION 5 : DÉCOUVERTE DU RANGE CIDR
# ============================================================================

log_section "ÉTAPE 3 : DÉCOUVERTE DE VOTRE RANGE CIDR"

log_info "Recherche du range CIDR pour $CURRENT_IP..."
log_info "Cela peut prendre 10-30 secondes (accès à whois)..."

# Utiliser whois pour trouver le range
WHOIS_OUTPUT=$(whois "$CURRENT_IP" 2>/dev/null)

# Chercher CIDR dans la sortie whois
CIDR_RANGE=$(echo "$WHOIS_OUTPUT" | grep -i "CIDR" | head -1 | awk '{print $NF}' || echo "")

# Si pas trouvé, chercher inetnum (format IPv4)
if [ -z "$CIDR_RANGE" ]; then
    INETNUM=$(echo "$WHOIS_OUTPUT" | grep -i "inetnum" | head -1 || echo "")
    if [ -n "$INETNUM" ]; then
        # Extraire la plage (ex: 203.0.113.0 - 203.0.113.255)
        START_IP=$(echo "$INETNUM" | awk '{print $2}')
        END_IP=$(echo "$INETNUM" | awk '{print $4}')
        log_info "Format trouvé : $START_IP - $END_IP"
        
        # Convertir en CIDR (approximation : prendre /24)
        CIDR_RANGE="$(echo $START_IP | cut -d. -f1-3).0/24"
    fi
fi

# Si toujours pas trouvé, utiliser /24 par défaut
if [ -z "$CIDR_RANGE" ]; then
    log_warning "Range CIDR non trouvé, utilisation du /24 par défaut"
    CIDR_RANGE="$(echo $CURRENT_IP | cut -d. -f1-3).0/24"
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
echo -e "${CYAN}Range CIDR trouvé : ${GREEN}$CIDR_RANGE${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"

# Afficher les détails du range
log_info "Détails du range $CIDR_RANGE :"
if [[ "$CIDR_RANGE" =~ ^([0-9.]+)/([0-9]+)$ ]]; then
    BASE_IP="${BASH_REMATCH[1]}"
    SUBNET="${BASH_REMATCH[2]}"
    
    case $SUBNET in
        24)
            NUM_IPS=256
            IP_RANGE="$(echo $BASE_IP | cut -d. -f1-3).1 à $(echo $BASE_IP | cut -d. -f1-3).254"
            ;;
        23)
            NUM_IPS=512
            START=$(echo $BASE_IP | cut -d. -f1-3)
            END_OCTET=$(echo $BASE_IP | cut -d. -f4)
            IP_RANGE="$START.1 à $START.255 et $(echo $START | awk -F. '{print $1"."$2"."($3+1)}').0 à $(echo $START | awk -F. '{print $1"."$2"."($3+1)}').255"
            ;;
        22)
            NUM_IPS=1024
            IP_RANGE="Plage très large (1024 IPs)"
            ;;
        *)
            NUM_IPS="variable"
            IP_RANGE="Plage variable"
            ;;
    esac
    
    echo -e "  ${BLUE}Base${NC} : $BASE_IP" | tee -a "$LOG_FILE"
    echo -e "  ${BLUE}Subnet${NC} : /$SUBNET" | tee -a "$LOG_FILE"
    echo -e "  ${BLUE}Nombre d'IPs${NC} : $NUM_IPS" | tee -a "$LOG_FILE"
    echo -e "  ${BLUE}Plage${NC} : $IP_RANGE" | tee -a "$LOG_FILE"
fi

# ============================================================================
# SECTION 6 : CHOIX CONFIRMÉ OU MANUEL
# ============================================================================

log_section "ÉTAPE 4 : CONFIRMATION DE LA PLAGE CIDR"

log_info "Vérification : $CIDR_RANGE contient votre IP $CURRENT_IP ?"

# Valider que l'IP est bien dans le CIDR
# (Vérification simple : même première partie)
CIDR_BASE=$(echo "$CIDR_RANGE" | cut -d/ -f1)
CIDR_SUBNET=$(echo "$CIDR_RANGE" | cut -d/ -f2)
IP_BASE=$(echo "$CURRENT_IP" | cut -d. -f1-3)

if [[ "$CIDR_BASE" == "$IP_BASE"* ]]; then
    log_success "L'IP $CURRENT_IP est bien dans le range $CIDR_RANGE ✓"
else
    log_warning "Attention : l'IP ne semble pas être dans le range"
fi

# Demander confirmation
echo ""
echo -e "${CYAN}Vous êtes sur le point de configurer fail2ban avec :${NC}"
echo -e "  ${GREEN}Range CIDR : $CIDR_RANGE${NC}"
echo -e "  ${GREEN}Votre IP actuelle : $CURRENT_IP${NC}"
echo ""
echo -e "${YELLOW}⚠ Attention : Toutes les IPs de ce range seront whitelistées${NC}"
echo -e "${YELLOW}  Cela inclut d'autres utilisateurs du même ISP/réseau${NC}"
echo ""

read -p "Continuer ? (o/n) : " -n 1 -r CONFIRM
echo ""

if [[ ! "$CONFIRM" =~ ^[Oo]$ ]]; then
    log_warning "Configuration annulée par l'utilisateur"
    
    # Proposer de saisir manuellement
    read -p "Saisir manuellement un range CIDR ? (o/n) : " -n 1 -r MANUAL
    echo ""
    
    if [[ "$MANUAL" =~ ^[Oo]$ ]]; then
        read -p "Range CIDR (ex: 203.0.113.0/24) : " CIDR_RANGE
        log_info "Utilisation du range manuel : $CIDR_RANGE"
    else
        log_error "Configuration annulée"
        exit 0
    fi
fi

# ============================================================================
# SECTION 7 : MISE À JOUR DE LA CONFIGURATION
# ============================================================================

log_section "ÉTAPE 5 : MISE À JOUR DE LA CONFIGURATION FAIL2BAN"

log_info "Création d'une sauvegarde de la configuration..."
cp "$CONFIG_FILE" "$BACKUP_FILE"
log_success "Sauvegarde créée : $BACKUP_FILE"

log_info "Mise à jour du fichier de configuration..."

# Extraction de la ligne ignoreip actuelle
CURRENT_IGNOREIP=$(grep "^ignoreip = " "$CONFIG_FILE" | head -1)

if [ -z "$CURRENT_IGNOREIP" ]; then
    log_warning "Ligne 'ignoreip' non trouvée dans la configuration"
    log_info "Création d'une nouvelle ligne ignoreip..."
    
    # Ajouter après la première ligne [DEFAULT]
    sed -i "/^\[DEFAULT\]/a ignoreip = 127.0.0.1/8 ::1 $CIDR_RANGE" "$CONFIG_FILE"
else
    # Remplacer la ligne existante
    log_info "Remplacement de la ligne ignoreip existante..."
    
    # Extraire les IPs existantes (sans le CIDR de remplacement si présent)
    EXISTING_IPS=$(echo "$CURRENT_IGNOREIP" | sed 's/^ignoreip = //')
    
    # Ajouter le nouveau CIDR à la liste
    NEW_IGNOREIP="ignoreip = $EXISTING_IPS $CIDR_RANGE"
    
    # Supprimer les doublons
    NEW_IGNOREIP=$(echo "$NEW_IGNOREIP" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/ /, /g' | sed 's/, $//')
    
    # Remplacer la ligne
    sed -i "s/^ignoreip = .*/ignoreip = 127.0.0.1\/8 ::1 $CIDR_RANGE/" "$CONFIG_FILE"
fi

log_success "Fichier de configuration mis à jour"

# ============================================================================
# SECTION 8 : VÉRIFICATION DE LA CONFIGURATION
# ============================================================================

log_section "ÉTAPE 6 : VÉRIFICATION DE LA CONFIGURATION"

# Afficher la ligne modifiée
log_info "Contenu de la ligne ignoreip :"
NEW_IGNOREIP=$(grep "^ignoreip = " "$CONFIG_FILE" | head -1)
echo -e "  ${GREEN}$NEW_IGNOREIP${NC}" | tee -a "$LOG_FILE"

# Vérifier la syntaxe fail2ban
log_info "Vérification de la syntaxe fail2ban..."
if sudo fail2ban-client -t > /dev/null 2>&1; then
    log_success "Syntaxe fail2ban valide ✓"
else
    log_error "Erreur de syntaxe dans la configuration fail2ban"
    log_warning "Restauration de la configuration..."
    cp "$BACKUP_FILE" "$CONFIG_FILE"
    exit 1
fi

# ============================================================================
# SECTION 9 : REDÉMARRAGE DE FAIL2BAN
# ============================================================================

log_section "ÉTAPE 7 : REDÉMARRAGE DE FAIL2BAN"

log_info "Redémarrage de fail2ban..."
if systemctl restart fail2ban; then
    log_success "Fail2ban redémarré avec succès"
    sleep 2
else
    log_error "Erreur lors du redémarrage de fail2ban"
    log_warning "Restauration de la configuration..."
    cp "$BACKUP_FILE" "$CONFIG_FILE"
    systemctl restart fail2ban
    exit 1
fi

# ============================================================================
# SECTION 10 : VÉRIFICATIONS FINALES
# ============================================================================

log_section "ÉTAPE 8 : VÉRIFICATIONS FINALES"

# Vérifier que fail2ban est actif
log_info "Vérification du statut fail2ban..."
if systemctl is-active --quiet fail2ban; then
    log_success "Fail2ban est actif"
else
    log_error "Fail2ban n'est pas actif"
    exit 1
fi

# Afficher le statut de la jail SSH
log_info "Statut de la jail SSH :"
fail2ban-client status sshd 2>&1 | grep -E "Currently|Banned" | tee -a "$LOG_FILE"

# ============================================================================
# SECTION 11 : AFFICHAGE FINAL
# ============================================================================

log_section "✓ CONFIGURATION TERMINÉE AVEC SUCCÈS !"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              RÉSUMÉ DE LA CONFIGURATION                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Votre IP actuelle${NC}      : ${GREEN}$CURRENT_IP${NC}"
echo -e "  ${CYAN}Range CIDR whitelist${NC}  : ${GREEN}$CIDR_RANGE${NC}"
echo -e "  ${CYAN}Fichier configuré${NC}     : ${GREEN}$CONFIG_FILE${NC}"
echo -e "  ${CYAN}Sauvegarde${NC}            : ${GREEN}$BACKUP_FILE${NC}"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    RÉSULTAT FINAL                          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}✓ Fail2ban${NC}                   : ${GREEN}Actif et configuré${NC}"
echo -e "  ${CYAN}✓ Range CIDR whitelisté${NC}     : ${GREEN}$CIDR_RANGE${NC}"
echo -e "  ${CYAN}✓ Vous ne serez jamais bloqué${NC} : ${GREEN}Tant que vous restiez dans ce range${NC}"
echo ""
echo -e "${YELLOW}⚠ À RETENIR :${NC}"
echo -e "  • Si vous changez de réseau/ISP, vous devrez reconfigurer"
echo -e "  • Ce range CIDR whiteliste TOUS les utilisateurs du même range"
echo -e "  • Pour plus de sécurité, utilisez DNS Dynamique (Solution 2)"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    COMMANDES UTILES                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Vérifier la whitelist${NC}:"
echo -e "    ${BLUE}grep 'ignoreip' $CONFIG_FILE${NC}"
echo ""
echo -e "  ${CYAN}Voir les IPs bannies${NC}:"
echo -e "    ${BLUE}sudo fail2ban-client status sshd${NC}"
echo ""
echo -e "  ${CYAN}Tester la connexion SSH${NC}:"
echo -e "    ${BLUE}ssh -p 2545 user@votre-serveur${NC}"
echo ""
echo -e "  ${CYAN}Suivre les logs${NC}:"
echo -e "    ${BLUE}sudo tail -f /var/log/fail2ban.log${NC}"
echo ""
echo -e "  ${CYAN}Voir le log d'installation${NC}:"
echo -e "    ${BLUE}cat $LOG_FILE${NC}"
echo ""

# ============================================================================
# SECTION 12 : TESTS OPTIONNELS
# ============================================================================

read -p "Voulez-vous faire des tests maintenant ? (o/n) : " -n 1 -r TEST
echo ""

if [[ "$TEST" =~ ^[Oo]$ ]]; then
    log_section "TESTS DE VÉRIFICATION"
    
    log_info "Test 1 : Vérifier que le range est bien configuré"
    grep "^ignoreip" "$CONFIG_FILE" | head -1 | tee -a "$LOG_FILE"
    
    log_info "Test 2 : Vérifier que fail2ban ne vous bannit pas"
    echo "  Trying a test login (you should see this message)"
    
    log_info "Test 3 : Vérifier les IPs actuellement bannies"
    BANNED=$(fail2ban-client status sshd 2>/dev/null | grep "Banned IP" || echo "  Aucune IP bannie")
    echo "  $BANNED" | tee -a "$LOG_FILE"
fi

echo ""
log_success "Configuration complète et fonctionnelle !"
log_info "Logs disponibles dans : $LOG_FILE"

exit 0
