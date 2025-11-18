#!/bin/bash

################################################################################
# SCRIPT DE CORRECTION : KNOCKD CONFIGURATION
#
# Ce script corrige les erreurs de syntaxe dans knockd.conf
# et relance le service
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# ============================================================================
# VÉRIFIER ROOT
# ============================================================================

if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

# ============================================================================
# CRÉER UNE CONFIGURATION VALIDE
# ============================================================================

log_info "Création d'une configuration knockd valide..."

# Sauvegarder l'ancienne
if [ -f /etc/knockd.conf ]; then
    cp /etc/knockd.conf /etc/knockd.conf.broken-$(date +%Y%m%d-%H%M%S)
    log_success "Ancienne configuration sauvegardée"
fi

# Créer une nouvelle configuration SIMPLE ET VALIDE
cat > /etc/knockd.conf << 'EOF'
[options]
	logfile = /var/log/knockd.log
	interface = eth0

[openSSH]
	sequence = 7000,8000,9000
	seq_timeout = 5
	start_command = /sbin/iptables -I INPUT 1 -s %IP% -p tcp --dport 2545 -j ACCEPT
	tcpflags = syn
	start_command = /usr/bin/logger 'knockd: SSH port opened for %IP%'

[closeSSH]
	sequence = 9000,8000,7000
	seq_timeout = 5
	start_command = /sbin/iptables -D INPUT -s %IP% -p tcp --dport 2545 -j ACCEPT
	start_command = /usr/bin/logger 'knockd: SSH port closed for %IP%'
	tcpflags = syn
EOF

log_success "Fichier knockd.conf créé"

# ============================================================================
# VÉRIFIER LA SYNTAXE
# ============================================================================

log_info "Vérification de la syntaxe knockd..."

# Tester la syntaxe
if knockd -c /etc/knockd.conf -D 2>&1 | grep -q "error\|Error"; then
    log_error "Erreur de syntaxe détectée"
    log_info "Contenu du fichier :"
    cat /etc/knockd.conf
    exit 1
fi

log_success "Syntaxe valide"

# ============================================================================
# REDÉMARRER LE SERVICE
# ============================================================================

log_info "Arrêt de knockd..."
systemctl stop knockd 2>/dev/null || true

sleep 2

log_info "Démarrage de knockd..."
systemctl start knockd

sleep 2

# ============================================================================
# VÉRIFIER QUE ÇA MARCHE
# ============================================================================

if systemctl is-active --quiet knockd; then
    log_success "knockd est actif et fonctionne !"
else
    log_error "knockd n'est pas actif"
    log_info "Vérification des logs :"
    sudo journalctl -u knockd -n 20
    exit 1
fi

# ============================================================================
# AFFICHER LE RÉSUMÉ
# ============================================================================

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Configuration corrigée et appliquée !${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Informations :${NC}"
echo "  Fichier config : /etc/knockd.conf"
echo "  Log fichier    : /var/log/knockd.log"
echo "  Séquence       : 7000,8000,9000 (ouvrir)"
echo "  Séquence ferme : 9000,8000,7000 (fermer)"
echo "  Port SSH       : 2545"
echo ""
echo -e "${BLUE}Prochaines étapes :${NC}"
echo "  1. Installer le client sur votre machine :"
echo "     sudo apt-get install knockd -y"
echo ""
echo "  2. Frapper à la porte :"
echo "     knock <IP_SERVEUR> 7000 8000 9000"
echo ""
echo "  3. Se connecter à SSH :"
echo "     ssh -p 2545 user@<IP_SERVEUR>"
echo ""
echo -e "${BLUE}Vérification :${NC}"
echo "  Statut knockd :"
sudo systemctl status knockd --no-pager | head -5
echo ""
echo "  Derniers logs :"
sudo tail -n 5 /var/log/knockd.log 2>/dev/null || echo "  (Pas de logs encore - c'est normal)"
echo ""

log_success "Terminé !"

exit 0
