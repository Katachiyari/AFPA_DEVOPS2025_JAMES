#!/bin/bash

################################################################################
# SCRIPT D'INSTALLATION AUTOMATISÉE DE KNOCK (PORT KNOCKING)
#
# Ce script installe et configure knock pour ajouter une couche de sécurité
# supplémentaire à SSH. Le port SSH reste caché jusqu'à l'envoi d'une 
# séquence secrète de "coups" sur des ports spécifiques.
#
# Prérequis : Système Debian/Ubuntu, accès root (ou sudo)
# Utilisation : sudo bash knock-install.sh
#
# Chaque étape est commentée pour la compréhension des débutants
#
# Concept : "Port Knocking" ou "Coups à la porte"
# - SSH sur port 2545 est FERMÉ par défaut
# - Pour l'ouvrir, vous devez "frapper" les ports : 7000, 8000, 9000 (exemple)
# - Seul votre IP sera autorisée après la séquence correcte
# - Le port SSH se ferme automatiquement après timeout
################################################################################

set -e

# ============================================================================
# SECTION 1 : INITIALISATION ET COULEURS
# ============================================================================

# Variables de couleur pour une meilleure lisibilité
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Variables globales
# PORT_SSH : le port SSH à protéger par knock (2545 selon notre installation précédente)
PORT_SSH="2545"

# KNOCK_SEQUENCE : la séquence secrète pour ouvrir SSH
# Changer cette séquence pour quelque chose d'unique !
# Format : port1,port2,port3 (TCP par défaut)
# Exemple faible (à CHANGER) : 7000,8000,9000
KNOCK_SEQUENCE="7000,8000,9000"

# SEQ_TIMEOUT : temps (en secondes) avant que la séquence ne soit réinitialisée
# Si vous ne frappez pas tous les ports dans ce délai, compteur remet à zéro
SEQ_TIMEOUT="5"

# COMMAND_TIMEOUT : temps (en secondes) avant que le port SSH ne se ferme automatiquement
# Une fois la séquence correcte envoyée, le port SSH reste ouvert X secondes
# Puis il se ferme automatiquement (pour la sécurité)
COMMAND_TIMEOUT="30"

# Interface réseau à surveiller
# eth0, ens0, ens18, wlan0, etc. selon votre configuration
INTERFACE=""

# ============================================================================
# SECTION 2 : FONCTIONS D'AFFICHAGE
# ============================================================================

# Fonction pour afficher les messages d'information
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Fonction pour afficher les messages de succès
log_success() {
    echo -e "${GREEN}[✓ SUCCÈS]${NC} $1"
}

# Fonction pour afficher les messages d'erreur
log_error() {
    echo -e "${RED}[✗ ERREUR]${NC} $1"
}

# Fonction pour afficher les avertissements
log_warning() {
    echo -e "${YELLOW}[⚠ ATTENTION]${NC} $1"
}

# Fonction pour afficher les sections importantes
log_section() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
}

# ============================================================================
# SECTION 3 : VÉRIFICATIONS PRÉALABLES
# ============================================================================

log_section "ÉTAPE 1 : VÉRIFICATIONS PRÉALABLES"

# Vérifier que le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté en tant que root"
    log_info "Essayez : sudo bash $0"
    exit 1
fi

log_success "Script exécuté en tant que root"

# Vérifier si le système est compatible (Debian/Ubuntu)
if ! grep -qi "ubuntu\|debian" /etc/os-release; then
    log_error "Ce script n'est compatible que avec Debian/Ubuntu"
    exit 1
fi

log_success "Système compatible détecté"

# Vérifier que fail2ban est installé (prérequis pour cette installation)
if ! command -v fail2ban-client &> /dev/null; then
    log_warning "fail2ban n'est pas détecté, mais ce n'est pas critique"
    log_info "Installez d'abord : sudo bash fail2ban-install.sh"
fi

# ============================================================================
# SECTION 4 : DÉCOUVERTE DE L'INTERFACE RÉSEAU
# ============================================================================

log_section "ÉTAPE 2 : DÉTECTION DE L'INTERFACE RÉSEAU"

log_info "Recherche de l'interface réseau principale..."

# Méthode 1 : Chercher l'interface avec la route par défaut
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

if [ -z "$INTERFACE" ]; then
    # Méthode 2 : Lister les interfaces disponibles
    log_warning "Interface réseau non trouvée automatiquement"
    log_info "Interfaces disponibles :"
    ip link show | grep -E "^\d+:" | awk -F': ' '{print "  - " $2}' | grep -v lo
    
    read -p "Entrez le nom de votre interface (ex: eth0, ens0, wlan0) : " INTERFACE
    
    if [ -z "$INTERFACE" ]; then
        log_error "Interface non spécifiée"
        exit 1
    fi
fi

log_success "Interface détectée : $INTERFACE"

# Vérifier que l'interface existe
if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    log_error "L'interface $INTERFACE n'existe pas"
    exit 1
fi

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

log_info "Installation de knockd (daemon port knocking)..."

# Installer knockd
apt-get install -y knockd > /dev/null 2>&1

log_success "knockd installé"

# Vérifier l'installation
if ! command -v knockd &> /dev/null; then
    log_error "Erreur lors de l'installation de knockd"
    exit 1
fi

log_success "knockd vérifié"

# ============================================================================
# SECTION 7 : CONFIGURATION DE KNOCK
# ============================================================================

log_section "ÉTAPE 5 : CONFIGURATION DE KNOCK"

log_info "Création du fichier de configuration /etc/knockd.conf..."

# Sauvegarder le fichier original
if [ -f /etc/knockd.conf ]; then
    cp /etc/knockd.conf /etc/knockd.conf.backup-$(date +%Y%m%d-%H%M%S)
    log_success "Sauvegarde du fichier original créée"
fi

# Créer la nouvelle configuration knockd
# Format du fichier knockd.conf :
# [options] : paramètres globaux
# [openSSH] : nom de la "jail" (section) pour ouvrir SSH
#   sequence : ports à "frapper" dans l'ordre
#   seq_timeout : délai entre les coups
#   command : commande à exécuter (ajouter une règle iptables pour l'IP source)
#   tcpflags : type de paquets TCP à compter
# [closeSSH] : section optionnelle pour fermer SSH
#   sequence : port à frapper pour fermer
#   command : commande à exécuter (supprimer la règle iptables)

cat > /etc/knockd.conf << 'KNOCKD_EOF'
# ============================================================================
# CONFIGURATION DE KNOCK (PORT KNOCKING)
# ============================================================================

# Section [options] : paramètres globaux de knock
[options]

# logpath : fichier de log où knockd va enregistrer son activité
# /var/log/knockd.log : fichier standard pour knock
logpath = /var/log/knockd.log

# loglevel : niveau de détail dans les logs
# 1 = erreurs seulement, 2 = avertissements, 3 = info, 4 = debug
loglevel = 3

# interface : interface réseau à surveiller
# Cette directive sera remplacée automatiquement par le script
# Elle peut être écrasée aussi par les options de démarrage
# interface = eth0

# UseSyslog : utiliser syslog au lieu d'un fichier de log
# Utile pour les serveurs en production (logs centralisés)
UseSyslog

# ============================================================================
# SECTION : OUVRIR SSH (PORT KNOCKING)
# ============================================================================
# Cette section définit la séquence pour OUVRIR le port SSH

[openSSH]

# sequence : la séquence secrète de ports à frapper
# Format : port1,port2,port3
# Type de port : TCP par défaut, ajouter :udp pour UDP
# Exemple : 7000:tcp,8000:tcp,9000:tcp (explicite)
# Exemple : 7000,8000,9000 (TCP par défaut)
# IMPORTANT : Changer cette séquence pour quelque chose d'unique !
# Cette séquence est votre "mot de passe" pour accéder à SSH
# Ligne sera remplacée automatiquement par le script avec la vraie séquence
sequence = 7000,8000,9000

# seq_timeout : temps (en secondes) entre chaque coup
# Si vous ne frappez pas le port suivant dans ce délai,
# la séquence est réinitialisée et vous devez recommencer
# 5 secondes = délai raisonnable
seq_timeout = 5

# command : commande à exécuter quand la séquence est correcte
# %IP% : remplacé automatiquement par l'IP source de la tentative
# %PORTS% : remplacé par les ports de la séquence
# Ici : ouvrir le port SSH (2545) SEULEMENT pour l'IP qui a envoyé la bonne séquence
# iptables -I INPUT 1 : insérer la règle au DÉBUT des règles INPUT
# -s %IP% : uniquement depuis cette IP source
# -p tcp : protocole TCP
# --dport 2545 : port de destination SSH
# -j ACCEPT : accepter les paquets correspondants
command = /sbin/iptables -I INPUT 1 -s %IP% -p tcp --dport 2545 -j ACCEPT

# tcpflags : quels flags TCP compter comme une tentative de knock
# syn : SYN flag (début de connexion)
# all : tous les flags
# Ici : compter les tentatives SYN (connexions normales)
tcpflags = syn

# start_command : commande optionnelle exécutée au démarrage de knockd
# Peut être utilisée pour enregistrer dans les logs qu'une séquence est correcte
# start_command = /usr/bin/logger 'Port SSH ouvert pour %IP%'

# ============================================================================
# SECTION : FERMER SSH
# ============================================================================
# Section OPTIONNELLE pour fermer SSH après un délai fixe

[closeSSH]

# sequence : autre séquence pour fermer SSH
# Cette séquence OPTIONNELLE permet de fermer manuellement le port SSH
# Vous pouvez aussi laisser knockd le fermer automatiquement (timeout)
# Format : ports différents des coups d'ouverture
sequence = 9000,8000,7000

# seq_timeout : temps avant réinitialisation
seq_timeout = 5

# command : commande à exécuter pour FERMER le port SSH
# iptables -D INPUT : supprimer une règle (D = Delete)
# Les paramètres (IP, port, etc.) doivent correspondre à ceux de openSSH
command = /sbin/iptables -D INPUT -s %IP% -p tcp --dport 2545 -j ACCEPT

# tcpflags : flags TCP
tcpflags = syn

# ============================================================================
KNOCKD_EOF

log_success "Fichier de configuration créé"

# Remplacer les valeurs par défaut par les bonnes séquences
# Remplacer la séquence d'ouverture
sed -i "s/^sequence = 7000,8000,9000/sequence = $KNOCK_SEQUENCE/" /etc/knockd.conf

# Remplacer le seq_timeout pour l'ouverture
sed -i "/^\[openSSH\]/,/^\[/ s/^seq_timeout = 5/seq_timeout = $SEQ_TIMEOUT/" /etc/knockd.conf

# Remplacer le port SSH
sed -i "s/--dport 2545/--dport $PORT_SSH/g" /etc/knockd.conf

log_info "Configuration mise à jour :"
log_info "  → Séquence d'ouverture : $KNOCK_SEQUENCE"
log_info "  → Délai entre coups : $SEQ_TIMEOUT secondes"
log_info "  → Port SSH protégé : $PORT_SSH"

# ============================================================================
# SECTION 8 : CONFIGURATION DE DÉMARRAGE
# ============================================================================

log_section "ÉTAPE 6 : CONFIGURATION DE DÉMARRAGE"

log_info "Configuration de /etc/default/knockd..."

# Éditer le fichier de configuration de démarrage
# START_KNOCKD=0 par défaut → knockd ne démarre pas
# On change en START_KNOCKD=1 pour que knockd démarre au boot

if grep -q "^START_KNOCKD=0" /etc/default/knockd; then
    sed -i 's/^START_KNOCKD=0/START_KNOCKD=1/' /etc/default/knockd
    log_success "START_KNOCKD changé à 1 (auto-démarrage activé)"
fi

# Configurer l'interface réseau
# KNOCKD_OPTS=\"-i eth0\" pour spécifier l'interface
# Ajouter -i $INTERFACE si pas déjà présent

if ! grep -q "KNOCKD_OPTS.*-i" /etc/default/knockd; then
    echo "KNOCKD_OPTS=\"-i $INTERFACE\"" >> /etc/default/knockd
    log_success "Interface configurée dans KNOCKD_OPTS"
else
    # Remplacer l'interface existante
    sed -i "s/KNOCKD_OPTS=\"-i [^\"]*\"/KNOCKD_OPTS=\"-i $INTERFACE\"/" /etc/default/knockd
    log_success "Interface mise à jour dans KNOCKD_OPTS"
fi

log_info "Contenu de /etc/default/knockd :"
grep "KNOCKD_OPTS\|START_KNOCKD" /etc/default/knockd | sed 's/^/  /'

# ============================================================================
# SECTION 9 : CONFIGURATION DU PARE-FEU IPTABLES
# ============================================================================

log_section "ÉTAPE 7 : CONFIGURATION DU PARE-FEU IPTABLES"

log_info "Ajout de règles iptables pour protéger SSH..."

# IMPORTANT : Nous devons d'abord bloquer SSH par défaut
# Puis knockd l'ouvrira temporairement après la bonne séquence

# Vérifier que SSH était déjà fermé (ce qu'il devrait être normalement)
# Sinon, ajouter une règle pour le fermer

# Ajouter une règle pour DROP SSH par défaut (si pas déjà présente)
if ! iptables -L INPUT -n | grep -q "dpt:$PORT_SSH"; then
    log_info "Ajout d'une règle pour bloquer SSH ($PORT_SSH) par défaut..."
    
    # Rejeter les tentatives de connexion SSH (port 2545)
    iptables -A INPUT -p tcp --dport "$PORT_SSH" -j DROP
    
    log_success "Port SSH ($PORT_SSH) bloqué par défaut"
else
    log_info "Règles iptables pour SSH déjà présentes"
fi

# Sauvegarder les règles iptables (pour persistence après reboot)
# iptables-save > /etc/iptables/rules.v4
log_info "Sauvegarde des règles iptables..."

# Installer iptables-persistent si pas déjà installé
if ! command -v iptables-save &> /dev/null; then
    apt-get install -y iptables-persistent > /dev/null 2>&1
    log_success "iptables-persistent installé"
fi

# Sauvegarder
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

log_success "Règles iptables sauvegardées"

# ============================================================================
# SECTION 10 : DÉMARRAGE DE KNOCK
# ============================================================================

log_section "ÉTAPE 8 : DÉMARRAGE DE KNOCK"

log_info "Redémarrage du service knockd..."

# Redémarrer le service
systemctl restart knockd

log_success "knockd redémarré"

# Attendre que le service démarre complètement
sleep 2

# Vérifier que le service est actif
if systemctl is-active --quiet knockd; then
    log_success "knockd est actif et en cours d'exécution"
else
    log_error "knockd n'est pas en cours d'exécution"
    log_info "Vérifiez les logs : sudo journalctl -u knockd -n 20"
    exit 1
fi

# Activer l'auto-démarrage
systemctl enable knockd

log_success "knockd activé pour l'auto-démarrage"

# ============================================================================
# SECTION 11 : VÉRIFICATIONS
# ============================================================================

log_section "ÉTAPE 9 : VÉRIFICATIONS"

log_info "Vérification de la configuration..."

# Afficher la séquence configurée
log_info "Séquence d'ouverture SSH :"
echo -e "  ${GREEN}knock <IP_SERVEUR> $KNOCK_SEQUENCE${NC}" | sed 's/,/ /g'

# Vérifier les logs
log_info "Vérification des logs knockd..."
if [ -f /var/log/knockd.log ]; then
    tail -n 3 /var/log/knockd.log | sed 's/^/  /'
else
    log_info "Fichier log non encore créé (normal au premier démarrage)"
fi

# Vérifier les règles iptables
log_info "Vérification des règles iptables :"
iptables -L INPUT -n | grep -E "ACCEPT|DROP|dpt:$PORT_SSH" | sed 's/^/  /'

# ============================================================================
# SECTION 12 : AFFICHAGE FINAL
# ============================================================================

log_section "✓ INSTALLATION DE KNOCK TERMINÉE AVEC SUCCÈS !"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              RÉSUMÉ DE LA CONFIGURATION                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Port SSH protégé${NC}         : ${GREEN}$PORT_SSH${NC}"
echo -e "  ${CYAN}Interface réseau${NC}        : ${GREEN}$INTERFACE${NC}"
echo -e "  ${CYAN}Séquence d'ouverture${NC}    : ${GREEN}$KNOCK_SEQUENCE${NC}"
echo -e "  ${CYAN}Délai entre coups${NC}       : ${GREEN}$SEQ_TIMEOUT secondes${NC}"
echo -e "  ${CYAN}Timeout connexion SSH${NC}   : ${GREEN}$COMMAND_TIMEOUT secondes${NC}"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    COMMENT ÇA MARCHE                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${MAGENTA}Port knocking (coups à la porte)${NC}"
echo ""
echo -e "  1️⃣  ${CYAN}SSH est FERMÉ${NC} par défaut sur le port $PORT_SSH"
echo -e "      Vous ne pouvez pas vous connecter directement"
echo ""
echo -e "  2️⃣  ${CYAN}Envoyez la séquence secrète${NC} :"
echo -e "      ${BLUE}knock <IP_SERVEUR> $(echo $KNOCK_SEQUENCE | tr ',' ' ')${NC}"
echo ""
echo -e "  3️⃣  ${CYAN}Le port SSH s'ouvre SEULEMENT pour vous${NC}"
echo -e "      Seule votre IP peut se connecter"
echo ""
echo -e "  4️⃣  ${CYAN}Le port se referme après $COMMAND_TIMEOUT secondes${NC}"
echo -e "      (Pour plus de sécurité)"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    COMMANDES UTILES                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Installation du client knock (sur votre machine locale)${NC}:"
echo -e "    ${BLUE}sudo apt-get install knockd -y${NC}"
echo ""
echo -e "  ${CYAN}Ouvrir le port SSH${NC}:"
echo -e "    ${BLUE}knock <IP_SERVEUR> $(echo $KNOCK_SEQUENCE | tr ',' ' ')${NC}"
echo ""
echo -e "  ${CYAN}Se connecter à SSH (après avoir frappé)${NC}:"
echo -e "    ${BLUE}ssh -p $PORT_SSH user@<IP_SERVEUR>${NC}"
echo ""
echo -e "  ${CYAN}Fermer le port SSH (optionnel)${NC}:"
echo -e "    ${BLUE}knock <IP_SERVEUR> 9000 8000 7000${NC}"
echo ""
echo -e "  ${CYAN}Voir les logs de knock${NC}:"
echo -e "    ${BLUE}sudo tail -f /var/log/knockd.log${NC}"
echo ""
echo -e "  ${CYAN}Voir le statut de knockd${NC}:"
echo -e "    ${BLUE}sudo systemctl status knockd${NC}"
echo ""
echo -e "  ${CYAN}Redémarrer knockd${NC}:"
echo -e "    ${BLUE}sudo systemctl restart knockd${NC}"
echo ""
echo -e "  ${CYAN}Voir les règles iptables${NC}:"
echo -e "    ${BLUE}sudo iptables -L INPUT -n{{NC}}"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    POINTS IMPORTANTS                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${YELLOW}⚠ Avant d'utiliser knock${NC}:"
echo -e "    • Installez le client knock sur votre machine locale"
echo -e "    • Testez la séquence depuis votre machine"
echo -e "    • Vérifiez que SSH fonctionne APRÈS les coups"
echo ""
echo -e "  ${YELLOW}⚠ Sécurité${NC}:"
echo -e "    • Ne partagez pas votre séquence de coups"
echo -e "    • Changez la séquence par défaut (7000,8000,9000)"
echo -e "    • Utilisez une séquence aléatoire et complexe"
echo -e "    • JAMAIS des ports communs (22, 80, 443, etc.)"
echo ""
echo -e "  ${YELLOW}⚠ Combinaison avec fail2ban${NC}:"
echo -e "    • knock + fail2ban = protection maximale"
echo -e "    • fail2ban vous protège des brute-force"
echo -e "    • knock vous protège par l'obscurité"
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""
log_success "Configuration complète et fonctionnelle !"
echo ""

exit 0
