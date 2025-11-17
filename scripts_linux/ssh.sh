#!/bin/bash
# ===========================================
# Script SSH - Debian 13
# 
# ===========================================
set -euo pipefail #sript s'arrête à la premiere erreur
LOGFILE="/var/log/sshd_install.log"

# ===== 1. Vérification et installation OpenSSH =====
if ! dpkg -l | grep -qw openssh-server; then
    echo "[INSTALL] Installation openssh-server ..." | tee -a "$LOGFILE"
    apt update && apt install -y openssh-server
fi
systemctl enable ssh
systemctl start ssh
systemctl status ssh --no-pager | tee -a "$LOGFILE"

# ===== 2. Sauvegarder le fichier de configuration =====
CONF="/etc/ssh/sshd_config"
cp "$CONF" "$CONF.bak"

# ===== 3. Configuration =====
read -p "Utilisateur SSH autorisé : " ALLOWUSER
read -p "Groupe SSH (ex: sudo) : " ALLOWGROUP
read -p "Adresse d'écoute SSH (ex: 0.0.0.0) : " LISTENADDR
PORTSSH=#$(shuf -i 2201-2299 -n 1) # Port dynamique

declare -A SETTINGS=(
    [Port]="$PORTSSH"
    [ListenAddress]="$LISTENADDR"
    [Protocol]="2"
    [PermitRootLogin]="no"
    [PasswordAuthentication]="no"
    [PubkeyAuthentication]="yes"
    [HostKey]="/etc/ssh/ssh_host_ed25519_key"
    [Ciphers]="chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr,aes128-ctr"
    [MACs]="hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com"
    [KexAlgorithms]="curve25519-sha256@libssh.org"
    [LogLevel]="VERBOSE"
    [MaxAuthTries]="3"
    [PrintLastLog]="yes"
    [StrictModes]="yes"
    [PermitEmptyPasswords]="no"
    [AllowUsers]="$ALLOWUSER"
    [AllowGroups]="$ALLOWGROUP"
    [X11Forwarding]="no"
)
#parcours le tableau et ajoute dans le CONF
for KEY in "${!SETTINGS[@]}"; do
    VALUE="${SETTINGS[$KEY]}"
    if grep -qE "^$KEY" "$CONF"; then
        sed -i "s|^$KEY.*|$KEY $VALUE|" "$CONF"
    else
        echo "$KEY $VALUE" >> "$CONF"
    fi
    echo "▶ $KEY $VALUE" | tee -a "$LOGFILE"

    # LOG FONCTIONNEL DANS LE SCRIPT
    done

# ===== 4. Générer la clé host ED25519 si absente =====
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
  ssh-keygen -t ed25519 -a 100 -C "james.malezieux@afpa-montpellier.fr" -f /etc/ssh/ssh_host_ed25519_key -N ""
  echo "[GEN] Clé serveur ED25519 générée" | tee -a "$LOGFILE"
fi

# ===== 5. Redémarrer le service SSHD =====
sshd -t # Vérification syntaxique
systemctl restart ssh

# ===== 6. Création de l’utilisateur sudo dédié =====
read -p "Nom nouvel utilisateur SSH/sudo : " NEWUSER
adduser "$NEWUSER"
usermod -aG sudo "$NEWUSER"
usermod -aG "$ALLOWGROUP" "$NEWUSER"
echo "$NEWUSER ALL=(ALL) NOPASSWD:ALL" | EDITOR='tee -a' visudo

# ===== 7. Génération de la paire de clés SSH forte =====
SSH_DIR="/home/$NEWUSER/.ssh"
KEYPATH="$SSH_DIR/id_ed25519"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
chown "$NEWUSER:$NEWUSER" "$SSH_DIR"

read -p "Passphrase forte pour la clé SSH : " PASSPHRASE
sudo -u "$NEWUSER" ssh-keygen -t ed25519 -a 100 -f "$KEYPATH" -N "$PASSPHRASE" -C "$NEWUSER@$(hostname)" -q

sudo -u "$NEWUSER" touch "$SSH_DIR/authorized_keys"
sudo -u "$NEWUSER" chmod 600 "$SSH_DIR/authorized_keys"
sudo -u "$NEWUSER" cat "$KEYPATH.pub" >> "$SSH_DIR/authorized_keys"
echo "[SEC] Clé publique ajoutée à authorized_keys." | tee -a "$LOGFILE"

chown -R "$NEWUSER:$NEWUSER" "$SSH_DIR"

# ===== 8. Installation dynamique de fail2ban =====
if ! dpkg -l | grep -qw fail2ban; then
  apt install -y fail2ban
fi
JAIL_CONF="/etc/fail2ban/jail.d/00-sshd-hardening.conf"
echo -e "[sshd]\nenabled = true\nport = $PORTSSH\nfilter = sshd\nlogpath = /var/log/auth.log\nmaxretry = 3\nbantime = 3600" > "$JAIL_CONF"
systemctl restart fail2ban

# ===== 9. Rapport visuel final en prompt + Log =====
echo "\n===================== RAPPORT INSTALLATION SSH ====================="
echo "Distribution : Debian 13"
echo "OpenSSH installé : $(dpkg -l | grep openssh-server | wc -l)"
echo "Service SSH actif : $(systemctl is-active ssh)"
echo "Configuration : $CONF (sauvegarde : $CONF.bak)"
echo "Port SSH utilisé : $PORTSSH"
echo "Utilisateur : $NEWUSER (groupes : $(groups $NEWUSER | cut -d: -f2))"
echo "Dossier clé : $SSH_DIR"
echo "Permissions .ssh : $(stat -c '%a' $SSH_DIR) - authorized_keys : $(stat -c '%a' $SSH_DIR/authorized_keys)"
echo "Fail2ban actif : $(systemctl is-active fail2ban)"
echo "Tester : ssh -p $PORTSSH $NEWUSER@<IP_SERVEUR>"
echo "Log complet : $LOGFILE"
echo "=================================================================="

echo "[INFO] Installation SSH durcie terminée le $(date)" | tee -a "$LOGFILE"
