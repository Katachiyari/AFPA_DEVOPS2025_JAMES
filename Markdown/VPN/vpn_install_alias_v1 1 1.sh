#!/bin/bash


# ─────────────────────────────────────────────────────────────────────────────
# Install + Configure Stunnel + Start OpenVPN (sans modifier le .ovpn)
# Respecte l'ordre : install → stunnel OK → openvpn → vérifs
# Place ce script dans le même dossier que ton .ovpn
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

# Vars (modifie si besoin)
REMOTE_HOST="82.22.7.32"
REMOTE_PORT="443"
LOCAL_LISTEN_PORT="1194"
STUNNEL_LOG_DIR="/var/log/stunnel4"
STUNNEL_PID_DIR="/run/stunnel4"
OVPN_LOG="/var/log/openvpn_client.log"

# ── Affichage (cosmétique, sans impact fonctionnel) ──────────────────────────
: "${QUIET:=0}"      # 1 = moins de blabla
: "${NO_COLOR:=0}"   # 1 = pas de couleurs (ex: CI)
: "${USE_ICONS:=1}"  # 0 = pas d’emojis

is_tty() { [ -t 1 ]; }
if [ "$NO_COLOR" -eq 1 ] || ! is_tty; then
  C_BOLD=""; C_RED=""; C_GRN=""; C_YLW=""; C_BLU=""; C_RST=""
else
  C_BOLD="$(printf '\033[1m')"; C_RST="$(printf '\033[0m')"
  C_RED="$(printf '\033[31m')"; C_GRN="$(printf '\033[32m')"
  C_YLW="$(printf '\033[33m')"; C_BLU="$(printf '\033[34m')"
fi
i_ok="✅"; i_err="❌"; i_inf="ℹ️ "; i_wrn="⚠️"
[ "$USE_ICONS" -eq 1 ] || { i_ok="[OK]"; i_err="[ERREUR]"; i_inf="[INFO]"; i_wrn="[AVERT]"; }

section()  { [ "$QUIET" -eq 0 ] && printf "\n%b==>%b %s\n" "$C_BOLD" "$C_RST" "$*"; }
log_ok()   { printf "%b%s%b %s\n" "$C_GRN" "$i_ok" "$C_RST" "$*"; }
log_err()  { printf "%b%s%b %s\n" "$C_RED" "$i_err" "$C_RST" "$*"; }
log_warn() { printf "%b%s%b %s\n" "$C_YLW" "$i_wrn" "$C_RST" "$*"; }
log_info() { [ "$QUIET" -eq 0 ] && printf "%b%s%b %s\n" "$C_BLU" "$i_inf" "$C_RST" "$*"; }

# ─────────────────────────────────────────────────────────────────────────────
section "Nettoyage des interfaces TUN"
for i in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^tun[0-9]+'); do
  log_info "Suppression ${i}"
  sudo ip link delete "$i" 2>/dev/null || true
done

section "Dépendances (openvpn, stunnel4, curl)"
missing=()
dpkg -s openvpn  >/dev/null 2>&1 || missing+=("openvpn")
dpkg -s stunnel4 >/dev/null 2>&1 || missing+=("stunnel4")
command -v curl   >/dev/null 2>&1 || missing+=("curl")

if [ "${#missing[@]}" -gt 0 ]; then
  log_info "Installation manquante : ${missing[*]}"
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get -qq update < /dev/null
  # Installation silencieuse, log en cas de problème
  if ! sudo apt-get -y -qq \
      -o=Dpkg::Use-Pty=0 \
      -o=Acquire::Retries=2 \
      --no-install-recommends install "${missing[@]}" \
      < /dev/null > /tmp/vpn_install_deps.log 2>&1; then
        log_err "Échec d'installation. Voir : /tmp/vpn_install_deps.log"
        exit 1
  fi
  log_ok "Paquets installés : ${missing[*]}"
else
  log_ok "Déjà présents : openvpn, stunnel4, curl"
fi

section "Configuration stunnel (client)"
# Dossiers PID/LOG avec bons droits (évite 'no pid=...' et erreurs de log)
sudo install -d -o stunnel4 -g stunnel4 -m 0755 "$STUNNEL_PID_DIR"
sudo install -d -o stunnel4 -g stunnel4 -m 0750 "$STUNNEL_LOG_DIR"

# Activer stunnel côté Debian/Ubuntu
echo 'ENABLED=1' | sudo tee /etc/default/stunnel4 >/dev/null

# Libérer le port local s'il est déjà pris
sudo fuser -k "${LOCAL_LISTEN_PORT}"/tcp 2>/dev/null || true

# Conf stunnel **avec pid** + setuid/setgid
sudo tee /etc/stunnel/stunnel.conf >/dev/null <<EOF
setuid = stunnel4
setgid = stunnel4
pid = ${STUNNEL_PID_DIR}/stunnel4.pid

client = yes
foreground = no
debug = info
output = ${STUNNEL_LOG_DIR}/client.log

[openvpn]
accept  = 127.0.0.1:${LOCAL_LISTEN_PORT}
connect = ${REMOTE_HOST}:${REMOTE_PORT}
verify = 0
EOF

# Démarrage (SysV derrière systemd) + unmask si besoin
sudo systemctl daemon-reload
sudo systemctl unmask stunnel4 2>/dev/null || true
sudo update-rc.d stunnel4 defaults >/dev/null 2>&1 || true
sudo service stunnel4 restart || sudo service stunnel4 start

section "Vérifications stunnel"
# Attente service actif (max 20s)
for i in {1..20}; do
  # Le script SysV peut renvoyer 0 même inactif → on vérifie le port
  if ss -ltn 2>/dev/null | grep -q "127\.0\.0\.1:${LOCAL_LISTEN_PORT}"; then
    log_ok "Port local 127.0.0.1:${LOCAL_LISTEN_PORT} en écoute"
    break
  fi
  sleep 1
  if [ "$i" -eq 20 ]; then
    log_err "127.0.0.1:${LOCAL_LISTEN_PORT} non détecté"
    [ -f "${STUNNEL_LOG_DIR}/client.log" ] && sudo tail -n 80 "${STUNNEL_LOG_DIR}/client.log" || true
    exit 1
  fi
done

# (Optionnel) Test reachabilité du serveur distant
command -v nc >/dev/null 2>&1 && nc -vzn "${REMOTE_HOST}" "${REMOTE_PORT}" || true

section "Détection du fichier client OpenVPN (.ovpn)"
OVPN="$(ls -1t "${SCRIPT_DIR}"/*.ovpn 2>/dev/null | head -n1 || true)"
if [ -z "${OVPN}" ]; then
  log_err "Aucun .ovpn trouvé dans ${SCRIPT_DIR}"
  exit 1
fi
log_ok "Fichier détecté : ${OVPN}"

section "Patch .ovpn (désactivation directives Windows)"
# Supprimer anciens backups .ovpn.bak.*
sudo find "${SCRIPT_DIR}" -maxdepth 1 -type f -name "$(basename "${OVPN}").bak.*" -print -delete 2>/dev/null || true
# Créer un nouveau backup propre
sudo cp -a "${OVPN}" "${OVPN}.bak.$(date +%Y%m%d%H%M%S)"   # Backup
sudo sed -i -E \
  -e 's/^[[:space:]]*ignore-unknown-option block-outside-dns.*/;# auto-disabled for Linux: &/I' \
  -e 's/^[[:space:]]*setenv opt block-outside-dns.*/;# auto-disabled for Linux: &/I' \
  -e 's/^[[:space:]]*explicit-exit-notify.*/;# auto-disabled for Linux: &/I' \
  "${OVPN}"
log_ok "Patch appliqué (backup créé)"

section "Démarrage d'OpenVPN"
sudo touch "$OVPN_LOG" && sudo chmod 640 "$OVPN_LOG"
sudo openvpn --config "${OVPN}" --daemon --log "$OVPN_LOG"

# Attendre la création d'une interface tunX (jusqu'à 30s)
TUN_IF=""
for i in {1..30}; do
  TUN_IF="$(ip -o link show | awk -F': ' '/tun[0-9]+/ {print $2; exit}')"
  if [ -n "${TUN_IF:-}" ] && ip link show "${TUN_IF}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if [ -n "${TUN_IF:-}" ] && ip link show "${TUN_IF}" >/dev/null 2>&1; then
  VPN_IP="$(ip -4 addr show dev "${TUN_IF}" | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)"
  if [ -n "${VPN_IP}" ]; then
    log_ok  "Interface VPN : ${TUN_IF}"
    log_info "IP interne : ${VPN_IP}"
  else
    log_warn "Interface ${TUN_IF} détectée, mais pas d'IP v4"
  fi
else
  log_err "Aucune interface tunX détectée. Vérifie les logs OpenVPN : $OVPN_LOG"
  sudo tail -n 80 "$OVPN_LOG" || true
  exit 1
fi

# IP publique (via le tunnel si la route par défaut passe par tunX)
PUB_IP="$(curl -s -4 https://ifconfig.me || true)"
[ -n "${PUB_IP}" ] && log_info "IP publique : ${PUB_IP}"

section "Post-install : Aliases Bash & Zsh (idempotent)"
set +u
ALIAS_DIR="$HOME/.config/shell"
ALIAS_ENV="$ALIAS_DIR/vpnctl.env"
ALIAS_FILE="$ALIAS_DIR/aliases-vpn.sh"
set -u

mkdir -p "$ALIAS_DIR"

# 1) Enregistre l'environnement détecté par le script
cat >"$ALIAS_ENV" <<EOF
# --- vpnctl.env (auto) ---
VPN_CONF="$(readlink -f "${OVPN}")"
OVPN_LOG="${OVPN_LOG}"
STUNNEL_SERVICE="stunnel4"
EOF
chmod 600 "$ALIAS_ENV"

# 2) Aliases communs (Bash & Zsh)
cat >"$ALIAS_FILE" <<'EOF'
# --- aliases-vpn.sh (auto) ---
[ -f "$HOME/.config/shell/vpnctl.env" ] && . "$HOME/.config/shell/vpnctl.env"

_vpn_require_conf() {
  if [ -z "${VPN_CONF:-}" ]; then
    echo "❌ VPN_CONF non défini. Ex: export VPN_CONF=\"$HOME/mon.ovpn\""
    return 1
  fi
}

_vpn_running() {
  [ -n "${VPN_CONF:-}" ] && pgrep -fa "openvpn.*--config[= ]${VPN_CONF}" >/dev/null 2>&1
}

_vpn_start_proc() { sudo openvpn --config "$VPN_CONF" --daemon ${OVPN_LOG:+--log "$OVPN_LOG"}; }
_vpn_stop_proc()  { pgrep -f "openvpn.*--config[= ]${VPN_CONF}" >/dev/null 2>&1 \
                      && sudo pkill -f "openvpn.*--config[= ]${VPN_CONF}" \
                      || sudo pkill -x openvpn >/dev/null 2>&1 || true; }

vpn-start()   { _vpn_require_conf || return 1;
                [ -n "${STUNNEL_SERVICE:-}" ] && { sudo service "$STUNNEL_SERVICE" restart >/dev/null 2>&1 || sudo service "$STUNNEL_SERVICE" start >/dev/null 2>&1 || true; }
                _vpn_running && echo "ℹ️  OpenVPN déjà démarré" || { _vpn_start_proc && echo "✅ VPN démarré"; }
                sleep 2; command -v curl >/dev/null 2>&1 && { echo -n "IP publique: "; curl -s -4 https://ifconfig.me; echo; }; }

vpn-stop()    { _vpn_require_conf || return 1; _vpn_stop_proc && echo "🛑 VPN arrêté"; }
vpn-restart() { _vpn_require_conf || return 1; _vpn_stop_proc;
                [ -n "${STUNNEL_SERVICE:-}" ] && { sudo service "$STUNNEL_SERVICE" restart >/dev/null 2>&1 || true; }
                _vpn_start_proc && echo "🔄 VPN redémarré";
                sleep 2; command -v curl >/dev/null 2>&1 && { echo -n "IP publique: "; curl -s -4 https://ifconfig.me; echo; }; }

vpn-status()  { _vpn_require_conf || return 1;
                echo "=== stunnel ==="; [ -n "${STUNNEL_SERVICE:-}" ] && (service "$STUNNEL_SERVICE" status 2>/dev/null || true | sed -n '1,12p') || echo "(stunnel non configuré)";
                echo; echo "=== openvpn ==="; _vpn_running && echo "✔️  actif pour: $VPN_CONF" || echo "✖️  non détecté pour: $VPN_CONF";
                echo; echo "=== réseau ==="; ip -brief addr show | awk '/^tun[0-9]+/ {print "IF:",$1,"→",$3}';
                command -v curl >/dev/null 2>&1 && { echo -n "IP publique: "; curl -s -4 https://ifconfig.me; echo; }; }

# Raccourcis stunnel (optionnels)
stunnel-start()  { [ -n "${STUNNEL_SERVICE:-}" ] && sudo service "$STUNNEL_SERVICE" start  && echo "✅ stunnel démarré"  || echo "stunnel non configuré"; }
stunnel-stop()   { [ -n "${STUNNEL_SERVICE:-}" ] && sudo service "$STUNNEL_SERVICE" stop   && echo "🛑 stunnel arrêté"   || echo "stunnel non configuré"; }
stunnel-status() { [ -n "${STUNNEL_SERVICE:-}" ] && service "$STUNNEL_SERVICE" status --full | sed -n '1,20p' || echo "stunnel non configuré"; }
# --- fin aliases-vpn.sh ---
EOF
chmod 644 "$ALIAS_FILE"

# 3) Sourcing idempotent dans Bash & Zsh (création du fichier si absent)
for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$RC" ] || : > "$RC"
  grep -Fq "$ALIAS_FILE" "$RC" || {
    printf '\n# VPN aliases (auto)\n[ -f "%s" ] && . "%s"\n' "$ALIAS_FILE" "$ALIAS_FILE" >> "$RC"
  }
done

# (Optionnel) s'assurer que .profile source .bashrc pour les shells de login
PROFILE="$HOME/.profile"
if [ -f "$HOME/.bashrc" ]; then
  grep -Fq '.bashrc' "$PROFILE" 2>/dev/null || {
    printf '\n# Source .bashrc si shell de login\n[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"\n' >> "$PROFILE"
  }
fi

# 4) Recharge immédiate si on est en Bash interactif
if [ -n "${BASH_VERSION-}" ] && [ -t 1 ]; then
  . "$ALIAS_FILE" || true
fi

log_ok "Aliases installés (Bash & Zsh)"
[ "$QUIET" -eq 0 ] && {
  printf "%s\n" "   ▶ vpn-start     → démarre stunnel + openvpn"
  printf "%s\n" "   ▶ vpn-stop      → arrête openvpn"
  printf "%s\n" "   ▶ vpn-restart   → redémarre stunnel + openvpn"
  printf "%s\n" "   ▶ vpn-status    → état du VPN + IP + interface tun"
  printf "%s\n" ""
  printf "%s\n" "   ▶ stunnel-start → démarre stunnel"
  printf "%s\n" "   ▶ stunnel-stop  → arrête stunnel"
  printf "%s\n" "   ▶ stunnel-status→ état de stunnel"
  printf "%s\n" ""
  log_info "Recharge : 'source ~/.bashrc' (bash) ou 'source ~/.zshrc' (zsh)"
}

section "Terminé"