#!/bin/bash
###################################################
# === Définition des couleurs ANSI (toujours \033, jamais \e) ===
GREEN="\033[1;32m"     # Vert vif : succès / infos
YELLOW="\033[1;33m"    # Jaune : avertissements
RED="\033[1;31m"       # Rouge : erreurs / alertes
CYAN="\033[1;36m"      # Cyan : informations techniques
BLUE="\033[1;34m"      # Bleu : info DNS / réseau
MAGENTA="\033[1;35m"   # Magenta : connexions / avancé
WHITE="\033[97m"       # Blanc vif
BLINK="\033[5m"        # Clignotant (réservé alertes)
INVERSE="\033[7m"      # Inverse color
STRIKE="\033[9m"       # Barré
RESET="\033[0m"        # Reset couleur et style
BOLD="\033[1m"         # Gras
UNDERLINE="\033[4m"    # Souligné

echo -e "$CYAN $WHITE $INVERSE +--- MENU SSH CONNECT ---+ $NC "
ssh_connect(){
echo 
}
