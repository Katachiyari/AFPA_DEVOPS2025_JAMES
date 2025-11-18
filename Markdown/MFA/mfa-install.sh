#!/bin/bash

################################################################################
# SCRIPT D'INSTALLATION AUTOMATISÉE DE MFA (2FA) AVEC GOOGLE AUTHENTICATOR
#
# Ce script installe et configure MFA pour SSH en utilisant Google Authenticator
# (TOTP - Time-based One-Time Password)
#
# Prérequis : Système Debian/Ubuntu, accès root (ou sudo)
# Utilisation : sudo bash mfa-install.sh
#
# Après installation, chaque connexion SSH nécessite :
# 1. Clé SSH valide (chose que vous avez)
# 2. Code MFA du téléphone (chose que vous connaissez)
#
# Chaque étape est commentée pour la compréhension des débutants
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
NC='\033[0m'

# Fichier de log
LOG_FILE="/var/log/mfa-install.log"

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

# Vérifier root
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

log_success "Exécuté en tant que root"

# Vérifier système compatible
if ! grep -qi "ubuntu\|debian" /etc/os-release; then
    log_error "Compatible uniquement avec Debian/Ubuntu"
    exit 1
fi

log_success "Système compatible"

# ============================================================================
# SECTION 4 : MISE À JOUR DU SYSTÈME
# ============================================================================

log_section "ÉTAPE 2 : MISE À JOUR DU SYSTÈME"

log_info "Mise à jour de la liste des paquets..."
apt-get update -y > /dev/null 2>&1

log_success "Système mis à jour"

# ============================================================================
# SECTION 5 : INSTALLATION DES DÉPENDANCES
# ============================================================================

log_section "ÉTAPE 3 : INSTALLATION DES DÉPENDANCES"

log_info "Installation de libpam-google-authenticator..."
# libpam-google-authenticator : module PAM pour Google Authenticator
# PAM = Pluggable Authentication Modules (système d'authentification modulaire)
# Cela permet à SSH d'utiliser le MFA Google Authenticator

apt-get install -y libpam-google-authenticator > /dev/null 2>&1

log_success "libpam-google-authenticator installé"

# ============================================================================
# SECTION 6 : CONFIGURATION DE SSH POUR MFA
# ============================================================================

log_section "ÉTAPE 4 : CONFIGURATION DE SSH POUR MFA"

log_info "Configuration de /etc/ssh/sshd_config..."

# Sauvegarder la configuration originale
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup-mfa-$(date +%Y%m%d-%H%M%S)
log_success "Sauvegarde de sshd_config créée"

# Activer l'authentification par clavier (requise pour MFA)
# KbdInteractiveAuthentication : permet les défis/réponses (comme le MFA)
log_info "  → Activation de KbdInteractiveAuthentication"

# Vérifier si la directive existe déjà
if grep -q "^KbdInteractiveAuthentication" /etc/ssh/sshd_config; then
    # Remplacer si elle existe
    sed -i 's/^KbdInteractiveAuthentication .*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config
else
    # Ajouter si elle n'existe pas
    echo "KbdInteractiveAuthentication yes" >> /etc/ssh/sshd_config
fi

log_success "KbdInteractiveAuthentication activé"

# Désactiver l'authentification vide (sécurité)
log_info "  → Désactivation de PermitEmptyPasswords"
sed -i 's/^PermitEmptyPasswords .*/PermitEmptyPasswords no/' /etc/ssh/sshd_config

# Paramètres importants pour MFA
log_info "  → Configuration des paramètres MFA"

# PubkeyAuthentication : utiliser les clés SSH
if grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config; then
    sed -i 's/^PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
else
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
fi

# PasswordAuthentication : désactivé (clés SSH uniquement)
if grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then
    sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
else
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
fi

# ChallengeResponseAuthentication : MFA (défis/réponses)
log_info "  → Activation de ChallengeResponseAuthentication (MFA)"
if grep -q "^ChallengeResponseAuthentication" /etc/ssh/sshd_config; then
    sed -i 's/^ChallengeResponseAuthentication .*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
else
    echo "ChallengeResponseAuthentication yes" >> /etc/ssh/sshd_config
fi

log_success "SSH configuré pour MFA"

# ============================================================================
# SECTION 7 : CONFIGURATION DE PAM (AUTHENTIFICATION)
# ============================================================================

log_section "ÉTAPE 5 : CONFIGURATION DE PAM"

log_info "Configuration de /etc/pam.d/sshd pour MFA..."

# Sauvegarder le fichier PAM
cp /etc/pam.d/sshd /etc/pam.d/sshd.backup-mfa-$(date +%Y%m%d-%H%M%S)

# Le fichier /etc/pam.d/sshd contrôle l'authentification SSH
# Il contient plusieurs modules :
# - pam_unix : authentification classique
# - pam_google_authenticator : authentification MFA

# Vérifier si google_authenticator est déjà configuré
if ! grep -q "pam_google_authenticator" /etc/pam.d/sshd; then
    log_info "  → Ajout de google_authenticator à PAM"
    
    # Ajouter google_authenticator au fichier PAM
    # required : MFA est OBLIGATOIRE (pas d'accès sans)
    # nullok : utiliser null si l'utilisateur n'a pas configuré MFA (permet transition graduelle)
    echo "auth required pam_google_authenticator.so nullok" >> /etc/pam.d/sshd
    
    log_success "google_authenticator ajouté à PAM"
else
    log_info "google_authenticator est déjà configuré dans PAM"
fi

# ============================================================================
# SECTION 8 : VÉRIFICATION DE LA SYNTAXE SSH
# ============================================================================

log_section "ÉTAPE 6 : VÉRIFICATION DE LA CONFIGURATION"

log_info "Vérification de la syntaxe SSH..."
if sshd -t; then
    log_success "Configuration SSH valide"
else
    log_error "Erreur dans la configuration SSH"
    log_warning "Restauration de la sauvegarde..."
    cp /etc/ssh/sshd_config.backup-mfa-* /etc/ssh/sshd_config
    exit 1
fi

# ============================================================================
# SECTION 9 : REDÉMARRAGE DE SSH
# ============================================================================

log_section "ÉTAPE 7 : REDÉMARRAGE DE SSH"

log_info "Redémarrage du service SSH..."
systemctl restart ssh

log_success "SSH redémarré"

# Attendre que SSH soit prêt
sleep 2

# Vérifier que SSH est actif
if systemctl is-active --quiet ssh; then
    log_success "SSH est actif et en cours d'exécution"
else
    log_error "SSH n'est pas actif"
    exit 1
fi

# ============================================================================
# SECTION 10 : AFFICHAGE FINAL
# ============================================================================

log_section "✓ INSTALLATION DE MFA TERMINÉE !"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           CONFIGURATION MFA APPLIQUÉE AVEC SUCCÈS          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}État du MFA${NC}         : ${GREEN}Installé et Configuré${NC}"
echo -e "  ${CYAN}Authentification${NC}     : Clé SSH + Code MFA (TOTP)"
echo -e "  ${CYAN}Fichier de config${NC}   : /etc/ssh/sshd_config"
echo -e "  ${CYAN}Configuration PAM${NC}   : /etc/pam.d/sshd"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              PROCHAINES ÉTAPES (IMPORTANT)                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${MAGENTA}Pour CHAQUE UTILISATEUR qui veut utiliser MFA :${NC}"
echo ""
echo -e "  1️⃣  ${BLUE}Se connecter au serveur (clé SSH)${NC}"
echo -e "     ${YELLOW}ssh -p 2545 user@server${NC}"
echo ""
echo -e "  2️⃣  ${BLUE}Initialiser MFA sur le serveur${NC}"
echo -e "     ${YELLOW}google-authenticator${NC}"
echo ""
echo -e "  3️⃣  ${BLUE}Répondre aux questions${NC}"
echo -e "     • Sauvegardez le QR code ou la clé secrète"
echo -e "     • Scannez le QR code avec Google Authenticator"
echo -e "     • Confirmez les codes générés"
echo ""
echo -e "  4️⃣  ${BLUE}À partir de maintenant, authentification MFA requise${NC}"
echo -e "     ${YELLOW}knock <IP> 7457 5234 8545 && ssh -p 2545 user@server${NC}"
echo -e "     (Puis entrer le code MFA du téléphone)"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  POINTS IMPORTANTS                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${YELLOW}⚠ SAUVEGARDER VTRE CLÉ SECRÈTE${NC}"
echo -e "     Lors de google-authenticator, une clé secrète sera affichée"
echo -e "     Sauvegardez-la dans un endroit sûr (1Password, Bitwarden, etc.)"
echo -e "     Cette clé sert de secours si vous perdez votre téléphone"
echo ""
echo -e "  ${YELLOW}⚠ CODES DE SECOURS${NC}"
echo -e "     Avant d'activer MFA, recevrez des codes de secours"
echo -e "     À utiliser si vous perdez accès à votre téléphone"
echo -e "     Sauvegardez-les aussi !"
echo ""
echo -e "  ${YELLOW}⚠ TESTE AVANT DE VOUS DÉCONNECTER${NC}"
echo -e "     Vérifiez que MFA fonctionne avant de fermer SSH"
echo -e "     Sinon vous pourriez être bloqué !"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  ARCHITECTURE FINALE                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${MAGENTA}Couche 1 : Port Knocking (Knock)${NC}"
echo -e "    → SSH caché, port fermé par défaut"
echo -e "    → Nécessite : knock <IP> 7457 5234 8545"
echo ""
echo -e "  ${MAGENTA}Couche 2 : Authentification SSH${NC}"
echo -e "    → Clé SSH obligatoire (pas de password)"
echo -e "    → Nécessite : clé privée valide"
echo ""
echo -e "  ${MAGENTA}Couche 3 : MFA (Multi-Factor Authentication)${NC}"
echo -e "    → Code temporaire depuis téléphone"
echo -e "    → Nécessite : code 6 chiffres du téléphone"
echo ""
echo -e "  ${MAGENTA}Couche 4 : Protection Brute-Force (Fail2Ban)${NC}"
echo -e "    → Automatiquement bannit après 3 tentatives échouées"
echo -e "    → Ban pour 1 heure"
echo ""
echo -e "  ${GREEN}RÉSULTAT : Sécurité EXTRÊME${NC} 🔐🔐🔐"
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""
log_success "Installation terminée avec succès !"
log_info "Logs disponibles dans : $LOG_FILE"

exit 0
