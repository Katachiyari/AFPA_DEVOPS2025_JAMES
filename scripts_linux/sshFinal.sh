#!/bin/bash
set -euo pipefail
#Commande set activer ou désactiver des options qui changent le comportement du shell ou du script
#-e﻿ : le script s’arrête à la première erreur
#-u﻿ : toute utilisation d’une variable non initialisée provoque une erreur
#-o pipefail﻿ : en cas d’erreur dans un pipeline, le statut d’échec est celui de la première commande en erreur
# tee copie la sortie d’une commande à la fois dans un fichier et sur le terminal (console)

# ========= VARIABLES À RENSEIGNER =========
NEWUSER="sshadmin"        # nom utilisateur SSH/Sudo
ALLOWGROUP="sshgroup"     # nom du groupe SSH autorisé
LISTENADDR="192.168.1.10" # adresse IP d'écoute SSH
ADMIN_IP="192.168.1.0/24" # IP ou réseau autorisé via iptables
ADMIN_MAIL="admin@example.com" # mail admin pour rapport/alerte
SSH_PORT=22
PASSPHRASE=""             # passphrase clé SSH (laisser vide pour préciser)
BATCH=1                    # mode batch (pas d'interaction)
LOGFILE="/var/log/sshd/install.log"
# ==========================================

# --- FONCTION LOG horodaté & rotation ---
#Crée le dossier pour le fichier de log si besoin.
#Archive le fichier de log s’il dépasse 1 Mo.
#Ajoute une ligne de log datée au fichier et l’affiche à l’écran.
log() {
  mkdir -p "$(dirname $LOGFILE)"
  [ -f "$LOGFILE" ] && [ $(stat -c%s "$LOGFILE") -gt 1048576 ] && mv "$LOGFILE" "$LOGFILE.$(date +%Y%m%d_%H%M%S)" || true
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

#trap déclencher une action automatique quand un événement ou une erreur spécifique survient dans le script.
trap 'rollback; log "⏪ Échec critique, rollback configuration."; exit 99' ERR

# --- Rollback automatique sur échec ---
#Restaure la config et la clé SSH si une sauvegarde existe
#log = Fonction qui écrit un message dans le fichier de log et/ou affiche à l’écran
rollback() {
  [ -f /etc/ssh/sshd_config.bak ] && sudo mv /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
  [ -f /etc/ssh/ssh_host_ed25519_key.bak ] && sudo mv /etc/ssh/ssh_host_ed25519_key.bak /etc/ssh/ssh_host_ed25519_key
  log "Rollback effectué (sshd_config et hostkey restaurés)."
}

# --- Détection distribution ---
#Détecte la distribution Linux depuis /etc/os-release
#Log le résultat ou arrête le script si non trouvée
detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    log "Distribution détectée : $DISTRO"
  else
    log "Impossible de détecter la distribution. Arrêt."; exit 1
  fi
}

# --- Installation OpenSSH/fail2ban ---
#Installe les paquets nécessaires selon la distribution détectée
#Affiche une erreur si la distribution n’est pas supportée
#Log l’installation des paquets
install_packages() {
  case "$DISTRO" in
    debian|ubuntu|linuxmint|raspbian|almalinux)
      PKGS="openssh-server fail2ban iptables iptables-persistent mailutils"
      sudo apt update && sudo apt install -y $PKGS
      ;;
    centos|fedora|rhel|rocky)
      PKGS="openssh-server fail2ban iptables mailx"
      sudo dnf install -y $PKGS
      ;;
    alpine)
      PKGS="openssh fail2ban iptables busybox-extras msmtp"
      sudo apk add $PKGS
      ;;
    *)
      log "Distribution non supportée automatiquement."; exit 2
      ;;
  esac
  log "Packages SSH/fail2ban installés."
}

# --- Firewall iptables : install ---
install_ipatable(){
local LOGFILE="/var/log/install_iptables.log"
echo "Début de l'installation : $(date)" >> "LOGFILE"
if command -v ipatables >/dev/null 2>&1; then
  echo "iptables est installé"
  sudo iptables -L
else
  sudo apt-get update
  sudo apt-get install iptables
  sudo apt-get install -y iptables-persistent
  sudo iptables -L
fi
}

# --- Firewall iptables : SSH restrictif ---
#Configure iptables pour restreindre l’accès SSH à ADMIN_IP
#Sauvegarde les règles et log l’application du pare-feu
setup_iptables() {
  log "Configuration iptables pour SSH/ADMIN ($ADMIN_IP)..."
  sudo iptables -F
  sudo iptables -P INPUT DROP
  sudo iptables -A INPUT -i lo -j ACCEPT
  sudo iptables -A INPUT -p tcp --dport $SSH_PORT -s "$ADMIN_IP" -j ACCEPT
  sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  sudo iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null
  log "Pare-feu iptables restreint appliqué."
}

# --- Durcissement ANSSI : sshd_config et rotation clés ---
harden_sshd_config() {
  SSHC="/etc/ssh/sshd_config"
  sudo cp "$SSHC" "$SSHC.bak"
  sudo sed -i '/^#\?\(HostKey\|PermitRootLogin\|PasswordAuthentication\|PubkeyAuthentication\|Ciphers\|KexAlgorithms\|MACs\|LogLevel\|MaxAuthTries\|PrintLastLog\|Protocol\|AllowUsers\|AllowGroups\|ListenAddress\)\b/d' "$SSHC"
  cat <<EOC | sudo tee -a "$SSHC" >/dev/null
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
HostKey /etc/ssh/ssh_host_ed25519_key
Ciphers chacha20-poly1305@openssh.com,aes256-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256@libssh.org
LogLevel VERBOSE
MaxAuthTries 3
PrintLastLog yes
AllowUsers $NEWUSER
AllowGroups $ALLOWGROUP
ListenAddress $LISTENADDR
EOC
  sudo systemctl restart ssh || sudo systemctl restart sshd
  log "Durcissement sshd_config appliqué."
  # Rotation host keys (conservation backup)
  for obsolete in dsa ecdsa rsa; do sudo rm -f /etc/ssh/ssh_host_${obsolete}_key*; done
  [ -f /etc/ssh/ssh_host_ed25519_key ] && sudo mv /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.bak || true
  sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
  sudo systemctl reload ssh || sudo systemctl reload sshd
  log "HostKey ED25519 régénérée, clés faibles supprimées."
}

# --- Création utilisateur SSH/Sudo, vérif stricte ---
setup_user() {
  egrep -q '^[a-z][-a-z0-9_]{1,30}$' <<< "$NEWUSER" || { log "Nom d'utilisateur non conforme."; exit 2; }
  getent group "$ALLOWGROUP" >/dev/null || sudo groupadd "$ALLOWGROUP"
  id "$NEWUSER" &>/dev/null || sudo adduser --disabled-password --gecos "" "$NEWUSER"
  sudo usermod -aG sudo "$NEWUSER"
  sudo usermod -aG "$ALLOWGROUP" "$NEWUSER"
  echo "$NEWUSER ALL=(ALL) NOPASSWD:ALL" | sudo EDITOR='tee -a' visudo
  log "$NEWUSER/$ALLOWGROUP OK, sudo ajouté."
}

# --- Gestion dynamique de la clé utilisateur -- rotation/autorisation ---
setup_userkey() {
  USERHOME="/home/$NEWUSER"
  SSHDIR="$USERHOME/.ssh"
  KEY="$SSHDIR/id_ed25519"
  sudo -u "$NEWUSER" mkdir -p "$SSHDIR"
  sudo -u "$NEWUSER" chmod 700 "$SSHDIR"
  [ -f "$KEY" ] && sudo -u "$NEWUSER" mv "$KEY" "$KEY.old" || true
  sudo -u "$NEWUSER" ssh-keygen -t ed25519 -f "$KEY" -N "$PASSPHRASE" -q
  sudo -u "$NEWUSER" touch "$SSHDIR/authorized_keys" && sudo -u "$NEWUSER" chmod 600 "$SSHDIR/authorized_keys"
  grep -qF "$(sudo -u "$NEWUSER" cat "$KEY.pub")" "$SSHDIR/authorized_keys" || sudo -u "$NEWUSER" cat "$KEY.pub" >> "$SSHDIR/authorized_keys"
  log "Clé ED25519 user $NEWUSER créée/ajoutée à authorized_keys."
}

# --- Installation/config fail2ban, notification ---
setup_fail2ban() {
  cat << EOF | sudo tee /etc/fail2ban/jail.d/sshd.conf
[sshd]
enabled = true
port = $SSH_PORT
filter  = sshd
maxretry = 3
findtime = 3600
bantime = 86400
action = %(action_mwl)s
EOF
  sudo systemctl enable fail2ban && sudo systemctl restart fail2ban
  log "fail2ban actif/configuré (alertes mail sur ban!)."
}

# --- Audit, rapport et intégration externe ---
auditer() {
  REPORT="/tmp/ssh_audit_$(date +%Y%m%d%H%M%S).txt"
  {
    echo "== SSHd Status =="
    sudo systemctl status sshd || sudo systemctl status ssh
    echo "== sshd_config =="
    grep -E '^Protocol|PermitRoot|PasswordAuth|PubkeyAuth|Ciphers|MACs|Kex|LogLevel|MaxAuthTries|PrintLastLog|HostKey|AllowUsers|AllowGroups|ListenAddress' /etc/ssh/sshd_config
    echo "== User/Key Status =="
    id "$NEWUSER"
    sudo -u "$NEWUSER" ls -l "/home/$NEWUSER/.ssh"
    sudo fail2ban-client status sshd || echo "Fail2ban/jail sshd absent"
    sudo iptables -L -n
  } > "$REPORT"
  log "Audit rapporté dans $REPORT"
  if [ -n "$ADMIN_MAIL" ]; then mail -s "[SSH Audit] $(hostname)" "$ADMIN_MAIL" < "$REPORT"; fi
}

# --- MAIN ---
main() {
  log "================ Lancement script SSH durci batch ================"
  detect_distro
  install_packages
  setup_iptables
  harden_sshd_config
  setup_user
  setup_userkey
  setup_fail2ban
  auditer
  log "========= SCRIPT SSH BATCH : TOUT OK ========="
}

main
