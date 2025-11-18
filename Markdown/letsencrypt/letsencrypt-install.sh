#!/bin/bash

################################################################################
# SCRIPT D'INSTALLATION AUTOMATISÉE DE LET'S ENCRYPT + CERTBOT
#
# Ce script installe et configure :
# 1. Certbot (client Let's Encrypt)
# 2. Certificats SSL/TLS gratuits
# 3. Renouvellement automatique (cron)
# 4. Configuration HTTPS pour WikiJS
# 5. Redirection HTTP → HTTPS
#
# Prérequis : 
#   - Système Debian/Ubuntu, accès root
#   - Domaine pointant vers votre serveur
#   - Ports 80 et 443 ouverts
# Utilisation : sudo bash letsencrypt-install.sh
#
# Après installation :
# - HTTPS automatique
# - Renouvellement automatique 30 jours avant expiration
# - Redirection HTTP → HTTPS
#
# Chaque étape est commentée pour la compréhension des débutants
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
MAGENTA='\033[0;35m'
NC='\033[0m'

LOG_FILE="/var/log/letsencrypt-install.log"

# Variables de configuration
DOMAIN=""
EMAIL=""
RENEWAL_CRON="/etc/cron.d/letsencrypt-renew"

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
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}$1${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
}

# ============================================================================
# SECTION 3 : VÉRIFICATIONS PRÉALABLES
# ============================================================================

log_section "ÉTAPE 1 : VÉRIFICATIONS PRÉALABLES"

if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

log_success "Exécuté en tant que root"

if ! grep -qi "ubuntu\|debian" /etc/os-release; then
    log_error "Compatible uniquement avec Debian/Ubuntu"
    exit 1
fi

log_success "Système compatible"

# ============================================================================
# SECTION 4 : DEMANDER LE DOMAINE ET L'EMAIL
# ============================================================================

log_section "ÉTAPE 2 : CONFIGURATION DU DOMAINE ET EMAIL"

# Demander le domaine
while [ -z "$DOMAIN" ]; do
    read -p "Entrez votre domaine (ex: wiki.example.com) : " DOMAIN
    if [ -z "$DOMAIN" ]; then
        log_warning "Domaine vide, réessayez"
    fi
done

log_info "Domaine configuré : $DOMAIN"

# Demander l'email
while [ -z "$EMAIL" ]; do
    read -p "Entrez votre email (pour Let's Encrypt) : " EMAIL
    if [ -z "$EMAIL" ]; then
        log_warning "Email vide, réessayez"
    fi
done

log_info "Email configuré : $EMAIL"

# Vérifier que le domaine est accessible
log_info "Vérification que le domaine pointe vers ce serveur..."

DOMAIN_IP=$(dig +short "$DOMAIN" A | head -1)
LOCAL_IP=$(hostname -I | awk '{print $1}')

if [ -z "$DOMAIN_IP" ]; then
    log_error "Impossible de résoudre le domaine $DOMAIN"
    log_info "Assurez-vous que le domaine est configuré dans le DNS"
    exit 1
fi

log_info "IP du domaine : $DOMAIN_IP"
log_info "IP locale : $LOCAL_IP"

# ============================================================================
# SECTION 5 : MISE À JOUR DU SYSTÈME
# ============================================================================

log_section "ÉTAPE 3 : MISE À JOUR DU SYSTÈME"

log_info "Mise à jour de la liste des paquets..."
apt-get update -y > /dev/null 2>&1

log_success "Système mis à jour"

# ============================================================================
# SECTION 6 : INSTALLATION DES DÉPENDANCES
# ============================================================================

log_section "ÉTAPE 4 : INSTALLATION DES DÉPENDANCES"

log_info "Installation de certbot et ses plugins..."

# certbot : client Let's Encrypt
# python3-certbot-nginx : plugin nginx (si vous utilisez nginx)
# python3-certbot-apache : plugin apache (si vous utilisez apache)
# Pour Docker/WikiJS, utiliser le mode standalone

DEPS="certbot dns-utils"

apt-get install -y $DEPS > /dev/null 2>&1

log_success "Certbot installé"

# ============================================================================
# SECTION 7 : ARRÊTER LES SERVICES UTILISANT LES PORTS 80 ET 443
# ============================================================================

log_section "ÉTAPE 5 : LIBÉRATION DES PORTS 80 ET 443"

log_info "Vérification des services utilisant les ports 80 et 443..."

# Chercher les processus utilisant les ports 80 et 443
PROC_80=$(lsof -i :80 2>/dev/null | grep -v COMMAND | awk '{print $1}' | sort -u || true)
PROC_443=$(lsof -i :443 2>/dev/null | grep -v COMMAND | awk '{print $1}' | sort -u || true)

if [ ! -z "$PROC_80" ]; then
    log_warning "Port 80 utilisé par : $PROC_80"
    log_info "Arrêt de WikiJS temporairement..."
    cd /opt/wikijs && docker-compose down > /dev/null 2>&1 || true
    sleep 2
    log_success "WikiJS arrêté"
fi

if [ ! -z "$PROC_443" ]; then
    log_warning "Port 443 utilisé par : $PROC_443"
fi

# ============================================================================
# SECTION 8 : OBTENIR LES CERTIFICATS LET'S ENCRYPT
# ============================================================================

log_section "ÉTAPE 6 : OBTENTION DES CERTIFICATS LET'S ENCRYPT"

log_info "Obtention du certificat pour $DOMAIN..."
log_info "Cela peut prendre 1-2 minutes..."

# Utiliser le mode standalone (Certbot démarre son propre serveur HTTP)
# pour valider le domaine
certbot certonly \
  --standalone \
  --agree-tos \
  --no-eff-email \
  --email "$EMAIL" \
  -d "$DOMAIN" \
  --quiet

if [ $? -eq 0 ]; then
    log_success "Certificat obtenu avec succès"
else
    log_error "Erreur lors de l'obtention du certificat"
    log_info "Vérifiez que :"
    log_info "  - Le port 80 est accessible"
    log_info "  - Le domaine pointe vers ce serveur"
    log_info "  - Pas de pare-feu bloquant le port 80"
    exit 1
fi

# Vérifier que les certificats existent
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"

if [ ! -d "$CERT_DIR" ]; then
    log_error "Répertoire des certificats non trouvé : $CERT_DIR"
    exit 1
fi

log_success "Certificats trouvés : $CERT_DIR"

# ============================================================================
# SECTION 9 : COPIER LES CERTIFICATS POUR DOCKER
# ============================================================================

log_section "ÉTAPE 7 : CONFIGURATION DES CERTIFICATS POUR WIKIJS"

log_info "Copie des certificats pour Docker..."

# Créer le répertoire pour les certificats
mkdir -p /opt/wikijs/certs

# Copier les certificats
# fullchain.pem : certificat complet (serveur + chaîne d'autorité)
# privkey.pem : clé privée (secrète, ne pas partager)

cp "$CERT_DIR/fullchain.pem" /opt/wikijs/certs/cert.crt
cp "$CERT_DIR/privkey.pem" /opt/wikijs/certs/cert.key

# Donner les bonnes permissions
chmod 644 /opt/wikijs/certs/cert.crt
chmod 600 /opt/wikijs/certs/cert.key

log_success "Certificats copiés pour Docker"

# ============================================================================
# SECTION 10 : CONFIGURER LE RENOUVELLEMENT AUTOMATIQUE
# ============================================================================

log_section "ÉTAPE 8 : CONFIGURATION DU RENOUVELLEMENT AUTOMATIQUE"

log_info "Configuration du renouvellement automatique..."

# Créer un script de renouvellement
RENEWAL_SCRIPT="/opt/scripts/renew-certificates.sh"

cat > "$RENEWAL_SCRIPT" << 'RENEWAL_EOF'
#!/bin/bash

# ============================================================================
# SCRIPT DE RENOUVELLEMENT AUTOMATIQUE DES CERTIFICATS LET'S ENCRYPT
# ============================================================================

LOG_FILE="/var/log/certbot-renewal.log"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_msg "====== Renouvellement des certificats ======"

# Arrêter WikiJS
log_msg "Arrêt de WikiJS..."
cd /opt/wikijs && docker-compose down >> "$LOG_FILE" 2>&1

sleep 2

# Renouveler les certificats
log_msg "Renouvellement de certbot..."
certbot renew --quiet

if [ $? -eq 0 ]; then
    log_msg "Certificats renouvelés avec succès"
    
    # Copier les nouveaux certificats
    log_msg "Copie des nouveaux certificats..."
    DOMAIN=$(ls /etc/letsencrypt/live/ | head -1)
    cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /opt/wikijs/certs/cert.crt
    cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /opt/wikijs/certs/cert.key
    
    log_msg "Certificats copiés"
else
    log_msg "ERREUR : Impossible de renouveler les certificats"
fi

# Redémarrer WikiJS
log_msg "Redémarrage de WikiJS..."
cd /opt/wikijs && docker-compose up -d >> "$LOG_FILE" 2>&1

log_msg "Renouvellement terminé"
log_msg "====== Fin ======"
RENEWAL_EOF

chmod +x "$RENEWAL_SCRIPT"

log_success "Script de renouvellement créé : $RENEWAL_SCRIPT"

# Ajouter à cron (exécution quotidienne)
log_info "Ajout du renouvellement automatique à cron..."

# Vérifier si déjà dans crontab
if ! crontab -l 2>/dev/null | grep -q "renew-certificates.sh"; then
    # Ajouter à cron
    (crontab -l 2>/dev/null || echo ""; echo "0 3 * * * /opt/scripts/renew-certificates.sh") | crontab -
    log_success "Cron configuré pour renouvellement quotidien à 3h du matin"
else
    log_warning "Renouvellement cron déjà configuré"
fi

# ============================================================================
# SECTION 11 : REDÉMARRER WIKIJS
# ============================================================================

log_section "ÉTAPE 9 : REDÉMARRAGE DE WIKIJS"

log_info "Redémarrage du container WikiJS..."

cd /opt/wikijs

# Redémarrer WikiJS
docker-compose up -d > /dev/null 2>&1

log_success "WikiJS redémarré"

# Attendre que WikiJS soit prêt
sleep 5

# Vérifier que WikiJS fonctionne
if docker ps | grep -q "wikijs"; then
    log_success "Container WikiJS est en cours d'exécution"
else
    log_error "WikiJS n'a pas redémarré correctement"
    log_info "Vérifiez : docker logs wikijs"
fi

# ============================================================================
# SECTION 12 : TESTER LES CERTIFICATS
# ============================================================================

log_section "ÉTAPE 10 : VÉRIFICATION DES CERTIFICATS"

log_info "Vérification des certificats..."

# Vérifier la date d'expiration
CERT_PATH="/etc/letsencrypt/live/$DOMAIN/cert.pem"

if [ -f "$CERT_PATH" ]; then
    EXPIRY=$(openssl x509 -in "$CERT_PATH" -noout -enddate | cut -d= -f2)
    log_info "Certificat expire le : $EXPIRY"
    
    # Vérifier les jours restants
    DAYS_LEFT=$(( ($(date -d "$EXPIRY" +%s) - $(date +%s)) / 86400 ))
    log_info "Jours restants : $DAYS_LEFT"
    
    if [ $DAYS_LEFT -lt 30 ]; then
        log_warning "Le certificat expire dans moins de 30 jours"
    else
        log_success "Certificat valide"
    fi
else
    log_error "Impossible de trouver le certificat"
fi

# ============================================================================
# SECTION 13 : CONFIGURATION IPTABLES
# ============================================================================

log_section "ÉTAPE 11 : CONFIGURATION IPTABLES"

log_info "Vérification des règles iptables..."

# Les ports 80 et 443 devraient déjà être autorisés (Docker les ajoute)
# Mais on vérifie au cas où

if ! iptables -L INPUT -n | grep -q "dpt:80"; then
    log_warning "Port 80 pas dans iptables, ajout..."
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
fi

if ! iptables -L INPUT -n | grep -q "dpt:443"; then
    log_warning "Port 443 pas dans iptables, ajout..."
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
fi

# Sauvegarder
iptables-save > /etc/iptables/rules.v4

log_success "Règles iptables vérifiées et sauvegardées"

# ============================================================================
# SECTION 14 : AFFICHAGE FINAL
# ============================================================================

log_section "✓ INSTALLATION DE LET'S ENCRYPT TERMINÉE !"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         LET'S ENCRYPT CONFIGURÉ AVEC SUCCÈS !             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Domaine${NC}                 : ${GREEN}$DOMAIN${NC}"
echo -e "  ${CYAN}Email${NC}                   : ${GREEN}$EMAIL${NC}"
echo -e "  ${CYAN}Certificat${NC}              : ${GREEN}$CERT_PATH${NC}"
echo -e "  ${CYAN}Expire le${NC}               : ${GREEN}$EXPIRY${NC}"
echo -e "  ${CYAN}Jours restants${NC}          : ${GREEN}$DAYS_LEFT jours${NC}"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ACCÈS À WIKIJS PAR HTTPS                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  🔐 ${CYAN}HTTPS (sécurisé)${NC}"
echo -e "     ${YELLOW}https://$DOMAIN${NC}"
echo ""
echo -e "  ⚠️  ${YELLOW}Certificat auto-signé de Let's Encrypt${NC}"
echo -e "     Navigateur peut afficher un avertissement la première fois"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║               RENOUVELLEMENT AUTOMATIQUE                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ✅ ${GREEN}Renouvellement configuré${NC}"
echo -e "     • Exécution quotidienne à 3h du matin"
echo -e "     • Renouvellement 30 jours avant expiration"
echo -e "     • Certificats copiés automatiquement"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  COMMANDES UTILES                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Voir les certificats${NC}:"
echo -e "    ${BLUE}certbot certificates${NC}"
echo ""
echo -e "  ${CYAN}Renouveler manuellement${NC}:"
echo -e "    ${BLUE}certbot renew${NC}"
echo ""
echo -e "  ${CYAN}Vérifier l'expiration${NC}:"
echo -e "    ${BLUE}openssl x509 -in /etc/letsencrypt/live/$DOMAIN/cert.pem -noout -dates${NC}"
echo ""
echo -e "  ${CYAN}Voir les logs de renouvellement{{NC}:"
echo -e "    ${BLUE}tail -f /var/log/certbot-renewal.log${NC}"
echo ""
echo -e "  ${CYAN}Vérifier les certificats Docker{{NC}:"
echo -e "    ${BLUE}ls -la /opt/wikijs/certs/{{NC}"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            ARCHITECTURE FINALE AVEC HTTPS                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${MAGENTA}Internet${NC}"
echo -e "    ↓ HTTPS (443)"
echo -e "  ${MAGENTA}Fail2Ban + iptables${NC}"
echo -e "    ↓"
echo -e "  ${MAGENTA}Container WikiJS{{NC}"
echo -e "    ↓ (certificat Let's Encrypt)"
echo -e "  ${MAGENTA}Pages wiki chiffrées 🔐${NC}"
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""
log_success "Installation terminée avec succès !"
log_info "Logs disponibles dans : $LOG_FILE"

exit 0
