#!/bin/bash

################################################################################
# SCRIPT D'INSTALLATION AUTOMATISÉE DE FAIL2BAN SELON LES RECOMMANDATIONS ANSSI
#
# Ce script installe et configure automatiquement fail2ban selon les 
# recommandations de sécurité de l'ANSSI, avec changement du port SSH de 22 à 2545
#
# Prérequis : Système Debian/Ubuntu, accès root (ou sudo)
# Utilisation : sudo bash fail2ban-install.sh
#
# Chaque étape est commentée pour la compréhension des débutants
################################################################################

# ============================================================================
# SECTION 1 : INITIALISATION ET VÉRIFICATIONS PRÉALABLES
# ============================================================================

# set -e : Arrête le script immédiatement si une commande échoue
# Cela prévient les erreurs en cascade si une dépendance n'est pas installée
set -e

# Afficher les commandes exécutées (mode debug - à supprimer si nécessaire)
# set -x

# Variables de couleur pour une meilleure lisibilité
# RED : affichage des erreurs en rouge
# GREEN : affichage des succès en vert
# YELLOW : affichage des avertissements en jaune
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Définition des ports
# PORT_ANCIEN : port SSH par défaut (22)
# PORT_NOUVEAU : port SSH sécurisé (2545) - selon votre demande
PORT_ANCIEN="22"
PORT_NOUVEAU="2545"

# Définition du fichier syslog
# Debian/Ubuntu utilise /var/log/auth.log pour les logs d'authentification
SYSLOG_FILE="/var/log/auth.log"

# ============================================================================
# FONCTION : Affichage des messages
# ============================================================================

# Fonction pour afficher les messages d'information
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Fonction pour afficher les messages de succès
log_success() {
    echo -e "${GREEN}[SUCCÈS]${NC} $1"
}

# Fonction pour afficher les messages d'erreur
log_error() {
    echo -e "${RED}[ERREUR]${NC} $1"
}

# Fonction pour afficher les avertissements
log_warning() {
    echo -e "${YELLOW}[ATTENTION]${NC} $1"
}

# ============================================================================
# SECTION 2 : VÉRIFICATIONS INITIALES
# ============================================================================

log_info "Démarrage du script d'installation fail2ban"

# Vérifier que le script est exécuté en tant que root
# Cela garantit que nous avons les permissions nécessaires pour installer les paquets
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté en tant que root"
    log_info "Essayez : sudo bash $0"
    exit 1
fi

log_success "Script exécuté en tant que root"

# Vérifier si le système est compatible (Debian/Ubuntu)
# cat /etc/os-release : affiche les informations du système d'exploitation
if ! grep -qi "ubuntu\|debian" /etc/os-release; then
    log_error "Ce script n'est compatible que avec Debian/Ubuntu"
    exit 1
fi

log_success "Système compatible détecté"

# Créer une sauvegarde de la configuration SSH originale
# Cela permet de récupérer la configuration en cas de problème
if [ -f /etc/ssh/sshd_config ]; then
    log_info "Création d'une sauvegarde de la configuration SSH"
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup-$(date +%Y%m%d-%H%M%S)
    log_success "Sauvegarde créée"
fi

# ============================================================================
# SECTION 3 : MISE À JOUR DU SYSTÈME
# ============================================================================

log_info "Mise à jour du système..."
# apt-get update : met à jour la liste des paquets disponibles
# Cette étape est nécessaire avant toute installation pour avoir les dernières versions
apt-get update -y

# apt-get upgrade : met à jour tous les paquets installés
# Cette étape améliore la sécurité et la stabilité du système
apt-get upgrade -y

log_success "Système mis à jour"

# ============================================================================
# SECTION 4 : INSTALLATION DES DÉPENDANCES
# ============================================================================

log_info "Installation des dépendances nécessaires..."

# Les dépendances suivantes sont nécessaires pour fail2ban :
# - fail2ban : le service principal de protection contre les brute-force
# - iptables : outil de configuration du pare-feu (utilisé par fail2ban pour bannir les IPs)
# - python3 : interpréteur Python (fail2ban est écrit en Python)
# - systemd : gestionnaire de services (pour gérer fail2ban comme service)

# Installation des paquets
# -y : répondre "oui" automatiquement à toutes les questions
apt-get install -y \
    fail2ban \
    iptables \
    python3 \
    systemd

log_success "Dépendances installées"

# ============================================================================
# SECTION 5 : MODIFICATION DE LA CONFIGURATION SSH
# ============================================================================

log_info "Configuration du service SSH..."

# ATTENTION : Les lignes commentées (#) sont ignorées par sshd
# Nous devons d'abord supprimer les commentaires des directives existantes

# Directive 1 : Changer le port SSH
# - find: recherche la ligne contenant "^#Port"
# - sed -i 's/.*/#Port 2545/' : remplace la ligne par "Port 2545"
# Cette étape fait passer SSH du port 22 (port par défaut et cible des attaques) au port 2545
log_info "  → Changement du port SSH de $PORT_ANCIEN à $PORT_NOUVEAU"

# Supprimer l'ancien port s'il existe
sed -i "s/^Port .*//" /etc/ssh/sshd_config

# Ajouter le nouveau port au début du fichier (après les commentaires)
sed -i "1i Port $PORT_NOUVEAU" /etc/ssh/sshd_config

# Directive 2 : Désactiver l'authentification par mot de passe pour root
# Cette recommandation ANSSI empêche les attaques par brute-force directes sur le compte root
log_info "  → Désactivation de l'authentification par mot de passe pour root"
sed -i 's/^#PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

# Directive 3 : Autoriser uniquement l'authentification par clé publique
# C'est une recommandation ANSSI fondamentale : l'authentification par clé est plus sécurisée
# que l'authentification par mot de passe (pas de brute-force possible)
log_info "  → Activation de l'authentification par clé publique"
sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Directive 4 : Désactiver l'authentification par mot de passe
# Cette directive force l'utilisation des clés publiques
log_info "  → Désactivation de l'authentification par mot de passe"
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Directive 5 : Désactiver l'authentification par clé vide
# Une clé vide n'offre aucune protection - les clés doivent avoir une passphrase
log_info "  → Désactivation des clés vides"
sed -i 's/^#PermitEmptyPasswords yes/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^PermitEmptyPasswords yes/PermitEmptyPasswords no/' /etc/ssh/sshd_config

# Directive 6 : Limiter le nombre de tentatives d'authentification
# Cette recommandation ANSSI limite les dégâts en cas de compromission de clé
log_info "  → Limitation du nombre de tentatives d'authentification"
sed -i 's/^#MaxAuthTries [0-9]*/MaxAuthTries 3/' /etc/ssh/sshd_config
if ! grep -q "^MaxAuthTries" /etc/ssh/sshd_config; then
    echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
fi

# Directive 7 : Réduire le délai d'expiration de la connexion
# LoginGraceTime défini le temps que le client a pour s'authentifier
# ANSSI recommande 30 secondes
log_info "  → Réduction du délai d'expiration de connexion"
sed -i 's/^#LoginGraceTime.*/LoginGraceTime 30/' /etc/ssh/sshd_config
if ! grep -q "^LoginGraceTime" /etc/ssh/sshd_config; then
    echo "LoginGraceTime 30" >> /etc/ssh/sshd_config
fi

# Directive 8 : Configuration des algorithmes cryptographiques selon ANSSI
# ANSSI recommande des algorithmes forts (AES-CTR) et des MAC robustes
log_info "  → Configuration des algorithmes cryptographiques (recommandations ANSSI)"

# Supprimer les anciennes directives
sed -i '/^Ciphers/d' /etc/ssh/sshd_config
sed -i '/^MACs/d' /etc/ssh/sshd_config
sed -i '/^KexAlgorithms/d' /etc/ssh/sshd_config

# Ajouter les nouvelles directives selon les recommandations ANSSI
# Ciphers : algorithmes de chiffrement symétriques (AES-CTR est plus sûr que AES-CBC)
echo "Ciphers aes256-ctr,aes192-ctr,aes128-ctr" >> /etc/ssh/sshd_config

# MACs : Message Authentication Codes pour vérifier l'intégrité (HMAC-SHA512 est recommandé)
echo "MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256" >> /etc/ssh/sshd_config

# KexAlgorithms : algorithmes d'échange de clés (ECDH est plus moderne et sûr que Diffie-Hellman)
echo "KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256" >> /etc/ssh/sshd_config

# Vérifier la syntaxe du fichier de configuration
# sshd -t : teste la syntaxe sans redémarrer le service
log_info "Vérification de la syntaxe SSH..."
if sshd -t; then
    log_success "Configuration SSH valide"
else
    log_error "Erreur dans la configuration SSH!"
    log_warning "Restauration de la configuration originale..."
    cp /etc/ssh/sshd_config.backup-* /etc/ssh/sshd_config 2>/dev/null || true
    exit 1
fi

log_success "Configuration SSH complétée"

# ============================================================================
# SECTION 6 : INSTALLATION ET CONFIGURATION DE FAIL2BAN
# ============================================================================

log_info "Configuration de fail2ban..."

# Étape 1 : Créer le fichier de configuration local
# Les modifications doivent être dans jail.local et non jail.conf
# Cela garantit que les mises à jour ne suppriment pas nos configurations
log_info "  → Création du fichier de configuration jail.local"

# Vérifier si le fichier jail.local existe déjà
if [ ! -f /etc/fail2ban/jail.local ]; then
    # Si jail.local n'existe pas, le copier depuis jail.conf
    # jail.conf contient les paramètres par défaut
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    log_success "Fichier jail.local créé"
else
    log_info "Fichier jail.local existant détecté"
fi

# Créer une sauvegarde du fichier jail.local
cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.backup-$(date +%Y%m%d-%H%M%S)

# Étape 2 : Configuration de fail2ban pour utiliser systemd
# systemd est le backend recommandé car il lit directement les journaux système
# C'est plus efficace et plus fiable que de lire les fichiers log directement
log_info "  → Configuration du backend (systemd)"

# Remplacer "backend = auto" par "backend = systemd"
sed -i 's/^backend = auto/backend = systemd/' /etc/fail2ban/jail.local

# Étape 3 : Configuration des paramètres par défaut
# Ces paramètres s'appliquent à tous les jails (prisons) sauf override
log_info "  → Configuration des paramètres par défaut"

# Ajouter/modifier la section [DEFAULT]
# Cette section doit être au début du fichier

# Supprimer l'ancienne section DEFAULT s'il y en a une au mauvais endroit
sed -i '/^\[DEFAULT\]/d' /etc/fail2ban/jail.local

# Créer un fichier temporaire avec la nouvelle configuration
TEMP_CONFIG=$(mktemp)

# Écrire la nouvelle section [DEFAULT] au début du fichier
cat > "$TEMP_CONFIG" << 'EOF'
# ============================================================================
# CONFIGURATION PAR DÉFAUT DE FAIL2BAN
# Ces paramètres s'appliquent à tous les jails sauf override spécifique
# ============================================================================

[DEFAULT]

# ignoreip : liste des IPs à ne pas bannir
# - 127.0.0.1/8 : localhost (boucle locale)
# - ::1 : localhost IPv6
# Ajouter vos IPs de confiance ici pour ne pas vous bannir accidentellement
ignoreip = 127.0.0.1/8 ::1

# bantime : durée du bannissement en secondes
# 3600 = 1 heure (recommandé pour une première offense)
# Pour les attaques récidivistes, utiliser des durées plus longues
bantime = 3600

# findtime : fenêtre de temps pour compter les tentatives échouées
# 600 = 10 minutes
# Si maxretry échecks surviennent dans cette fenêtre, l'IP est bannée
findtime = 600

# maxretry : nombre de tentatives échouées avant bannissement
# 3 = bannir après 3 tentatives échouées (recommandation ANSSI pour SSH)
# Valeur ajustée pour la sécurité sans bloquer les utilisateurs légitimes
maxretry = 3

# destemail : adresse email pour les notifications
# Laisser vide si aucune notification n'est nécessaire
destemail = root@localhost

# sendername : nom du sender pour les notifications
sendername = Fail2Ban

# action_ : définie l'action de bannissement
# Utiliser iptables pour mettre à jour le pare-feu
# Le port est défini dans chaque jail
action_ = %(banaction)s[port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]

# Notification par email (optionnel, laisser commenté pour la plupart)
# action_mw : Ban + mail with whois information
# action = %(action_)s
# Pour activer les emails, décommenter et configurer un serveur mail

# ============================================================================

EOF

# Append le reste du fichier original (en supprimant les anciennes lignes DEFAULT)
tail -n +2 /etc/fail2ban/jail.local >> "$TEMP_CONFIG"

# Remplacer le fichier original
mv "$TEMP_CONFIG" /etc/fail2ban/jail.local

log_success "Paramètres par défaut configurés"

# Étape 4 : Créer un fichier de configuration spécifique pour SSH
# Cela permet une meilleure modularité et maintenance
log_info "  → Création de la configuration pour SSH"

# Créer le fichier /etc/fail2ban/jail.d/sshd.local
# La raison d'utiliser jail.d/ : c'est plus modulaire et lisible
mkdir -p /etc/fail2ban/jail.d

cat > /etc/fail2ban/jail.d/sshd.local << EOF
# ============================================================================
# CONFIGURATION DE FAIL2BAN POUR SSH
# Ce fichier configure la surveillance du service SSH selon ANSSI
# ============================================================================

[sshd]

# enabled : activer cette jail (prison)
# true = surveiller et bannir les tentatives de brute-force SSH
enabled = true

# port : le port à surveiller
# Ici, port 2545 car nous avons changé SSH du port 22
# Si vous aviez plusieurs ports SSH, les lister : port = ssh,2545,2546
port = $PORT_NOUVEAU

# filter : filtre à appliquer pour déterminer une tentative échouée
# sshd : utiliser le filtre prédéfini pour SSH
# Les filtres sont définis dans /etc/fail2ban/filter.d/
filter = sshd

# logpath : fichier log à surveiller
# %(sshd_log)s : variable qui pointe vers /var/log/auth.log sur Debian/Ubuntu
logpath = %(sshd_log)s

# backend : source des logs pour cette jail
# systemd : lire les logs depuis le journal systemd (plus efficace)
backend = systemd

# maxretry : nombre de tentatives échouées avant bannissement pour cette jail
# 3 : valeur recommandée par ANSSI pour SSH (stricte mais acceptable)
# Changer à 5 ou 6 si vous avez trop de faux positifs
maxretry = 3

# bantime : durée du bannissement pour cette jail
# 3600 = 1 heure
# Pour une meilleure sécurité, augmenter à 86400 (24 heures)
bantime = 3600

# findtime : fenêtre de temps pour compter les tentatives
# 600 = 10 minutes (même que DEFAULT)
findtime = 600

# mode : mode de détection pour SSH
# normal : détection standard des tentatives échouées
# aggressive : détection plus stricte, peut générer des faux positifs
# extra : très strict, surveille aussi les autres comportements suspects
mode = normal

# action : quelle action effectuer lors du bannissement
# Par défaut, utilise la directive action_ de [DEFAULT]
# Laisser commenté pour utiliser la valeur par défaut
# action = %(action_)s

# ============================================================================
EOF

log_success "Configuration SSH créée"

# Étape 5 : Configuration d'une jail supplémentaire pour les récidivistes
# Cette jail bannit les IPs qui sont bannies plusieurs fois (monitorage des recidivistes)
log_info "  → Configuration de la jail pour les récidivistes"

cat > /etc/fail2ban/jail.d/recidive.local << 'EOF'
# ============================================================================
# JAIL POUR LES RÉCIDIVISTES
# Bannir les IPs qui sont bannies plusieurs fois par différents jails
# C'est une couche de sécurité supplémentaire recommandée
# ============================================================================

[recidive]

# enabled : activer la surveillance des récidivistes
enabled = true

# logpath : fichier log de fail2ban lui-même (pour détecter les récidivistes)
# Fail2Ban scanne son propre log pour détecter les IPs bannies plusieurs fois
logpath = /var/log/fail2ban.log

# banaction_allports : bannir sur TOUS les ports (pas seulement SSH)
# Utilise %(banaction_allports)s défini dans jail.local
banaction = %(banaction_allports)s

# maxretry : nombre de fois où une IP doit être bannies pour être bannie ici
# 2 = si l'IP est bannies 2 fois (par différents jails), bannir globalement
maxretry = 2

# findtime : fenêtre de temps pour compter les bannissements
# 86400 = 24 heures (si 2 bans en 24h, ajouter à la jail recidive)
findtime = 86400

# bantime : durée du bannissement pour les récidivistes
# 604800 = 7 jours (beaucoup plus long que les jails individuelles)
# Les récidivistes reçoivent un traitement plus sévère
bantime = 604800

# ============================================================================
EOF

log_success "Configuration des récidivistes créée"

# Étape 6 : Vérifier la configuration de fail2ban
log_info "Vérification de la configuration fail2ban..."

# Utiliser fail2ban-client pour valider la configuration
# Cette vérification s'assurera que la syntaxe est correcte
if fail2ban-client -t 2>&1 | grep -q "OK"; then
    log_success "Configuration fail2ban valide"
else
    log_error "Erreur dans la configuration fail2ban"
    log_warning "Vérifiez les fichiers de configuration"
fi

# ============================================================================
# SECTION 7 : ACTIVATION ET DÉMARRAGE DE FAIL2BAN
# ============================================================================

log_info "Activation et démarrage des services..."

# Étape 1 : Redémarrer SSH avec la nouvelle configuration
log_info "  → Redémarrage du service SSH"
systemctl restart ssh

log_success "SSH redémarré (port $PORT_NOUVEAU)"

# Étape 2 : Activer fail2ban au démarrage du système
log_info "  → Activation de fail2ban au démarrage"
# systemctl enable : ajoute fail2ban aux services autostart
systemctl enable fail2ban

log_success "Fail2ban activé au démarrage"

# Étape 3 : Redémarrer fail2ban pour charger la nouvelle configuration
log_info "  → Redémarrage de fail2ban"
# systemctl restart : arrête puis redémarre le service
systemctl restart fail2ban

log_success "Fail2ban redémarré"

# ============================================================================
# SECTION 8 : VÉRIFICATIONS ET TESTS
# ============================================================================

log_info "Vérification du bon fonctionnement..."

# Attendre 2 secondes pour que fail2ban soit complètement prêt
sleep 2

# Vérifier le statut global de fail2ban
log_info "  → Statut de fail2ban :"
fail2ban-client status

# Vérifier le statut de la jail SSH
log_info "  → Statut de la jail SSH :"
fail2ban-client status sshd || log_warning "Impossible de récupérer le statut sshd (normal si pas encore d'événements)"

# Vérifier les règles iptables créées par fail2ban
log_info "  → Règles iptables créées par fail2ban :"
iptables -S | grep -i "f2b" || log_info "Aucune règle iptables créée (normal au premier démarrage)"

# ============================================================================
# SECTION 9 : INFORMATION FINALE
# ============================================================================

log_success "Installation et configuration de fail2ban terminées avec succès !"
log_info ""
log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║               INFORMATIONS IMPORTANTES                         ║"
log_info "╚════════════════════════════════════════════════════════════════╝"
log_info ""
log_info "✓ SSH écoute désormais sur le port : $PORT_NOUVEAU"
log_info "✓ Fail2ban surveille les tentatives échouées sur SSH"
log_info "✓ Chiffrement SSH : ANSSI (AES-CTR, HMAC-SHA512)"
log_info "✓ Configuration stockée dans :"
log_info "  - /etc/fail2ban/jail.local (configuration générale)"
log_info "  - /etc/fail2ban/jail.d/sshd.local (SSH)"
log_info "  - /etc/fail2ban/jail.d/recidive.local (récidivistes)"
log_info ""
log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║                    PROCHAINES ÉTAPES                           ║"
log_info "╚════════════════════════════════════════════════════════════════╝"
log_info ""
log_warning "1. IMPORTANT : Vérifiez que vous pouvez vous reconnecter via SSH !"
log_warning "   ssh -p $PORT_NOUVEAU user@votre-serveur"
log_warning "   Si vous êtes bloqué, accédez au serveur via la console physique"
log_warning ""
log_info "2. Whitelist vos adresses IP de confiance pour éviter le bannissement :"
log_info "   Éditez /etc/fail2ban/jail.local et modifiez :"
log_info "   ignoreip = 127.0.0.1/8 ::1 VOTRE_IP_PUBLIQUE"
log_info "   Exemple : ignoreip = 127.0.0.1/8 ::1 203.0.113.50"
log_info ""
log_info "3. Pour tester fail2ban (sans risquer le ban) :"
log_info "   - Tentez 3+ connexions SSH avec un mauvais mot de passe"
log_info "   - Vérifiez : fail2ban-client status sshd"
log_info ""
log_info "4. Pour débannir une IP :"
log_info "   sudo fail2ban-client set sshd unbanip ADRESSE_IP"
log_info ""
log_info "5. Pour consulter les IPs actuellement bannies :"
log_info "   sudo fail2ban-client status sshd"
log_info ""
log_info "6. Fichiers de configuration à connaître :"
log_info "   - /etc/ssh/sshd_config (configuration SSH - sauvegarde : *.backup)"
log_info "   - /etc/fail2ban/jail.local (configuration générale fail2ban)"
log_info "   - /etc/fail2ban/jail.d/sshd.local (spécifique à SSH)"
log_info "   - /etc/fail2ban/jail.d/recidive.local (récidivistes)"
log_info ""
log_info "7. Fichiers de logs :"
log_info "   - /var/log/auth.log (tentatives SSH)"
log_info "   - /var/log/fail2ban.log (actions de fail2ban)"
log_info "   Commande pour suivre : tail -f /var/log/fail2ban.log"
log_info ""
log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║              CONFIGURATION APPLIQUÉE (RÉSUMÉ)                  ║"
log_info "╚════════════════════════════════════════════════════════════════╝"
log_info ""
log_info "SSH :"
log_info "  ✓ Port changé de 22 à 2545"
log_info "  ✓ Authentification par mot de passe désactivée (clés publiques obligatoires)"
log_info "  ✓ Root ne peut pas se connecter directement avec mot de passe"
log_info "  ✓ Algorithmes cryptographiques : ANSSI (AES-CTR, HMAC-SHA512)"
log_info "  ✓ MaxAuthTries limité à 3 tentatives"
log_info "  ✓ LoginGraceTime réduit à 30 secondes"
log_info ""
log_info "Fail2Ban :"
log_info "  ✓ Backend : systemd (plus efficace)"
log_info "  ✓ Bannissement automatique après 3 tentatives échouées"
log_info "  ✓ Durée du ban : 1 heure (SSH)"
log_info "  ✓ Durée du ban : 7 jours (récidivistes)"
log_info "  ✓ Surveillance du port $PORT_NOUVEAU"
log_info ""
log_info "Recommandations ANSSI appliquées :"
log_info "  ✓ Authentification SSH robuste (clés Ed25519 recommandées)"
log_info "  ✓ Chiffrement fort (AES-CTR)"
log_info "  ✓ MAC robustes (HMAC-SHA512-ETM)"
log_info "  ✓ Limitation des tentatives"
log_info "  ✓ Protection brute-force (fail2ban)"
log_info ""
log_info "═══════════════════════════════════════════════════════════════════"

exit 0
