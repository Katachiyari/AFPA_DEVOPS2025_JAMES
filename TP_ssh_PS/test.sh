#!/bin/bash
# ------------------------------------------
# Installe figlet et ajoute un banner login dans ~/.bashrc
# Affiche le hostname puis l'utilisateur en figlet à chaque session interactive
# Compatible Debian/Ubuntu
# ------------------------------------------
 
# arreter l'execution du script en cas d'erreur
set -e
 
# --- Détermination de l'utilisateur cible ---
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(eval echo "~$TARGET_USER")"
BASHRC="${TARGET_HOME}/.bashrc"
 
# --- Vérifs de base ---
if [ -z "$TARGET_HOME" ] || [ ! -d "$TARGET_HOME" ]; then
  echo " Impossible de déterminer le HOME de l'utilisateur cible."
  exit 1
fi
 
# --- Installation de figlet (nécessite root/sudo) ---
if ! command -v figlet >/dev/null 2>&1; then
  if [ "$EUID" -ne 0 ]; then
    echo "🔐 Installation de figlet requiert sudo/root. Tentative via sudo..."
    sudo apt-get update -y
    sudo apt-get install -y figlet
  else
    echo "📦 Installation de figlet..."
    apt-get update -y
    apt-get install -y figlet
  fi
else
  echo " figlet est déjà installé."
fi
 
# --- Assure l'existence du .bashrc ---
if [ ! -f "$BASHRC" ]; then
  touch "$BASHRC"
  chown "$TARGET_USER":"$TARGET_USER" "$BASHRC"
fi
 
# --- Bloc à insérer dans .bashrc ---
MARK_START="# >>> figlet-login-banner >>>"
MARK_END="# <<< figlet-login-banner <<<"
 
BANNER_BLOCK=$(cat <<'EOF'
# >>> figlet-login-banner >>>
# Affiche un banner figlet au login (shell interactif uniquement)
if [ -n "$PS1" ] && command -v figlet >/dev/null 2>&1; then
  COLUMNS="$(tput cols 2>/dev/null || echo 80)"
  HOSTNAME_TO_SHOW="$(hostname)"
  USERNAME_TO_SHOW="${USER}"
  figlet -w "$COLUMNS" "$HOSTNAME_TO_SHOW"
  figlet -w "$COLUMNS" "$USERNAME_TO_SHOW"
fi
# <<< figlet-login-banner <<<
EOF
)
 
# --- Injection idempotente ---
if grep -qF "$MARK_START" "$BASHRC"; then
  echo "  Bloc déjà présent dans ${BASHRC} (aucune duplication)."
else
  echo " Ajout du banner figlet dans ${BASHRC}..."
  printf "\n%s\n" "$BANNER_BLOCK" >> "$BASHRC"
  chown "$TARGET_USER":"$TARGET_USER" "$BASHRC"
fi
 
echo " Terminé ! "
 