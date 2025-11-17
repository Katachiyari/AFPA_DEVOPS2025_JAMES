#!/bin/bash

#####################################################################
# Script Menu Système Avancé avec Couleurs, Icônes et Fonctions
# Usage clair, maintenable et commenté
#####################################################################

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

# === Icônes Unicode pour affichage visuel agréable ===
ICON_DISK="💽"
ICON_CPU="🖥️"
ICON_RAM="🧠"
ICON_NET="🌐"
ICON_FIREWALL="🛡️"
ICON_DOCKER="🐳"
ICON_BACKUP="💾"
ICON_OK="✅"
ICON_FAIL="❌"
ICON_WARN="⚠️"
ICON_INFO="ℹ️"
ICON_PROCESS="⚙️"
ICON_LOG="📄"
ICON_TRAFFIC="📡"

# === Fonction : Affichage usage disque avec pourcentage ===
usage_disk() {
  echo -e "${BOLD}${CYAN}${ICON_DISK} Usage disque détaillé ${RESET}"
  
  df -h | awk '
# Fonction convert_to_MB : convertit la taille exprimée en GB, MB ou KB vers le nombre de mégaoctets (MB).
# Elle prend l’argument size, détecte l’unité à la fin (G, M, K), extrait la valeur numérique, et fait la conversion.
# Elle s’utilise à chaque appel sur une valeur, par exemple $2, pour harmoniser l’affichage et faciliter les calculs et comparaisons.

    function convert_to_MB(size) {
      unit = substr(size, length(size))
      n = substr(size, 1, length(size)-1) + 0
      if (unit == "G") return n * 1024
      else if (unit == "M") return n
      else if (unit == "K") return n / 1024
      else return size + 0
    }
    NR == 1 { next }
    BEGIN {
      printf "%-15s %-10s %-10s %-8s %-30s\n", "Daemon", "Taille", "Utilisé", "Util%", "Point de montage"
      print "---------------------------------------------------------------------------------"
    }
    {
      size_mb = convert_to_MB($2)
      used_mb = convert_to_MB($3)
      percent = (used_mb / size_mb) * 100
      printf "%-15s %-10s %-10s %7.2f%% %-30s\n", $1, $2, $3, percent, $6
    }
  '
  echo
}

# === Fonction : Usage disque pour emplacement donné avec infos détaillées ===
usage_disk_location() {
  # Lister utilisateurs courants pour info
  echo -e "${BOLD}${CYAN}${ICON_INFO} Utilisateurs courants :${RESET}"
  getent passwd | awk -F: '$3 >= 1000 && $3 < 10000 {print $1}'
  echo

  while true; do
    echo -ne "${UNDERLINE}Entrez chemin absolu (ex: /home): ${RESET}"
    read -e absoluPath
    if [[ -z "$absoluPath" || "$absoluPath" != /* || ! -e "$absoluPath" ]]; then
      echo -e "${RED}${ICON_FAIL} Chemin invalide ou inexistant: $absoluPath${RESET}"
    else
      break
    fi
  done

  # Récupération infos disque et fichiers
  read -ra infos <<< "$(df -h "$absoluPath" | awk 'NR==2')" # Stocke chaque champ de la 2e ligne de 'df -h' dans le tableau infos.
  disk=$(echo "${infos[0]}" | cut -d'/' -f3 | cut -c1-3) # Extrait les 3 premiers caractères du nom de disque
  size=$(du -sh "$absoluPath" 2>/dev/null | awk '{print $1}') # Récupère la taille réelle du dossier
  nfiles=$(find "$absoluPath" -type f 2>/dev/null | wc -l)  #Compte le nombre total de fichiers
  ndirs=$(find "$absoluPath" -type d 2>/dev/null | wc -l) # Compte le nombre total de dossiers
  lastmod=$(stat -c "%Y" "$absoluPath" 2>/dev/null | xargs -I{} date "+%d/%m/%Y %H:%M:%S" -d @{}) # Affiche la date de dernière modification
  owner=$(stat -c "%U" "$absoluPath" 2>/dev/null)  # Récupère le propriétaire du dossier
  group=$(stat -c "%G" "$absoluPath" 2>/dev/null)  # Récupère le groupe du dossier
  rights=$(stat -c "%A" "$absoluPath" 2>/dev/null) # Récupère les droits d'accès du dossier

  # Affichage tableau clair
  echo -e "${BOLD}${MAGENTA}${ICON_DISK} Détails du répertoire :${RESET}"
  printf "+----------------------+------------------------------+\n"
  printf "| %-20s | %-28s |\n" "Clé" "Valeur"
  printf "+----------------------+------------------------------+\n"
  printf "| %-20s | %-28s |\n" "Répertoire" "$absoluPath"
  printf "| %-20s | %-28s |\n" "Taille réelle" "$size"
  printf "| %-20s | %-28s |\n" "Fichiers" "$nfiles"
  printf "| %-20s | %-28s |\n" "Dossiers" "$ndirs"
  printf "| %-20s | %-28s |\n" "Dernière modif." "$lastmod"
  printf "| %-20s | %-28s |\n" "Propriétaire" "$owner"
  printf "| %-20s | %-28s |\n" "Groupe" "$group"
  printf "| %-20s | %-28s |\n" "Droits" "$rights"
  printf "+----------------------+------------------------------+\n"

  # Résumé df
  echo -e "${CYAN}Résumé espace disque${RESET}: utilisé ${infos[2]}, disponible ${infos[3]}, total ${infos[1]} sur disque $disk"
  echo
}

# === Fonction : Backup système compressé et transfert sécurisé ===
# read -p  Affiche un prompt avant la saisie utilisateur
# echo -e Active l’interprétation des séquences d’échappement.
# $? Code de sortie de la dernière commande (0 = succès, autre = erreur)
# 
backup_system() {
  echo -e "${BOLD}${BLUE}${ICON_BACKUP} Démarrage backup système compressé ${RESET}"

  read -p "Utilisateur SSH : " utilisateur
  read -p "IP distante SSH : " ip
  read -p "Port SSH (default 22) : " port
  port=${port:-22}

  SRC=(/home /etc /var /opt)
  ARCHIVE="/tmp/backup_$(date +%Y%m%d_%H%M%S).tar.xz"
  REMOTE_DIR="/opt/save"
  REMOTE_ARCHIVE="$REMOTE_DIR/$(basename "$ARCHIVE")"

  echo -e "${ICON_INFO} Compression en cours..."
  tar -I "xz -9e" -cpf "$ARCHIVE" "${SRC[@]}"
  if [ $? -ne 0 ]; then
    echo -e "${RED}${ICON_FAIL} Erreur compression.${RESET}"
    exit 1
  fi

  SUM_LOCAL=$(sha256sum "$ARCHIVE" | awk '{print $1}')
  echo -e "${GREEN}${ICON_OK} Archive prête: $ARCHIVE (${SUM_LOCAL})${RESET}"

  echo -e "${ICON_INFO} Test connexion SSH..."
  ssh -p "$port" -o ConnectTimeout=7 "$utilisateur@$ip" exit
  if [ $? -ne 0 ]; then
    echo -e "${RED}${ICON_FAIL} Connexion SSH impossible.${RESET}"
    rm -f "$ARCHIVE"
    exit 2
  fi

  echo -e "${ICON_INFO} Préparation dossier distant..."
  ssh -t -p "$port" "$utilisateur@$ip" "sudo mkdir -p $REMOTE_DIR && sudo chown $utilisateur:$utilisateur $REMOTE_DIR"

 # Transfert de l’archive compressé tar.xz avec compression active du flux réseau (option -z rsync).
  echo -e "${ICON_INFO} Transfert archive..."
  rsync -avzP -e "ssh -p $port" --progress --stats "$ARCHIVE" "$utilisateur@$ip:$REMOTE_ARCHIVE"
  if [ $? -ne 0 ]; then
    echo -e "${RED}${ICON_FAIL} Transfert échoué.${RESET}"
    rm -f "$ARCHIVE"
    exit 3
  fi

  echo -e "${ICON_INFO} Vérification intégrité distante..."
  SUM_DIST=$(ssh -p "$port" "$utilisateur@$ip" "sha256sum '$REMOTE_ARCHIVE' | awk '{print \$1}'")
  if [[ "$SUM_LOCAL" == "$SUM_DIST" && -n "$SUM_DIST" ]]; then
    echo -e "${GREEN}${ICON_OK} Intégrité vérifiée (${SUM_DIST})${RESET}"
  else
    echo -e "${RED}${ICON_FAIL} Vérification échouée ! Suppression distante de l’archive.${RESET}"
    ssh -p "$port" "$utilisateur@$ip" "rm -f '$REMOTE_ARCHIVE'"
    rm -f "$ARCHIVE"
    exit 4
  fi

  rm -f "$ARCHIVE"
  echo -e "${GREEN}${ICON_OK} Sauvegarde terminée et sécurisée.${RESET}"
  echo
}

# === Fonction : Affichage usage CPU détaillé avec top et mpstat ===
usage_cpu() {
  echo -e "${BOLD}${CYAN}${ICON_CPU} Audit CPU avancé${RESET}"

  # Vérification et installation mpstat
  if ! command -v mpstat &>/dev/null; then
    echo -e "${ICON_WARN} mpstat absent, installation..."
    sudo apt-get update -qq && sudo apt-get install -y sysstat
    sudo systemctl enable --now sysstat &>/dev/null
  fi

  echo -e "${BOLD}Statistiques CPU par cœur (mpstat -P ALL 1 1):${RESET}"
    # us : temps CPU utilisateur (user mode)
    # sy : temps CPU système (kernel mode)
    # ni : temps CPU pour processus nice
    # id : temps CPU idle (inactif)
    # wa : temps CPU en attente I/O (iowait)
    # hi : temps CPU gestion interruptions hardware
    # si : temps CPU gestion interruptions software
    # st : temps CPU volé par hyperviseur (steal)
  mpstat -P ALL 1 1 | grep -E 'all|^[0-9]+' | awk '
    BEGIN { 
      printf "%-5s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s\n", "CPU", "us", "sy", "ni", "id", "wa", "hi", "si", "st"
      print "---------------------------------------------------------------------"
    }
    {
      if (NR>3) printf "%-5s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s\n", $2, $3, $4, $5, $6, $7, $8, $9, $10
    }
  '
  echo

  echo -e "${ICON_INFO} Processus les plus gourmands en CPU:"
	# Affiche la liste des processus triés par utilisation CPU décroissante
	# - 'ps -eo pid,pcpu,comm' : sélectionne ID de processus, pourcentage CPU, commande
	# - '--sort=-pcpu' : trie selon l'utilisation CPU décroissante (du plus gourmand au moins gourmand)
	# - 'head -n 5' : limite l'affichage aux 5 premiers processus
  ps -eo pid,pcpu,comm --sort=-pcpu | head -n 5
  echo
}

# === Fonction : Rapport usage mémoire avec free, vmstat et top ===
usage_ram() {
  echo -e "${BOLD}${CYAN}${ICON_RAM} Rapport d'utilisation RAM${RESET}"
  echo

  echo -e "${BOLD}${GREEN}${ICON_RAM} Résumé mémoire (free -h) :${RESET}"
  free -h
  echo

  echo -e "${BOLD}${YELLOW}${ICON_RAM} Détails mémoire clés (/proc/meminfo) :${RESET}"
  grep -E 'MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree' /proc/meminfo | while read -r line; do
      key=$(echo "$line" | cut -d: -f1)
      value=$(echo "$line" | cut -d: -f2- | sed 's/^[ \t]*//')
      case $key in
          MemTotal*)  echo -e "${GREEN}$key: ${RESET}$value" ;;
          MemFree*)   echo -e "${CYAN}$key: ${RESET}$value" ;;
          MemAvailable*) echo -e "${BLUE}$key: ${RESET}$value" ;;
          SwapTotal*) echo -e "${YELLOW}$key: ${RESET}$value" ;;
          SwapFree*)  echo -e "${RED}$key: ${RESET}$value" ;;
      esac
  done
  echo

  echo -e "${BOLD}${MAGENTA}${ICON_PROCESS} Top 10 processus (RSS) par consommation mémoire :${RESET}"
	# Affiche les 11 processus consommant le plus de mémoire (RSS)
	# - ps aux :
	#   * a : affiche les processus de tous les utilisateurs (pas seulement ceux du terminal courant)
	#   * u : affiche les informations détaillées en mode utilisateur (colonnes UID, PID, CPU%, MEM%, etc.)
	#   * x : inclut les processus sans terminal associé (démons, services)
	# - --sort=-rss : trie la liste par ordre décroissant de RSS (Resident Set Size)
	#   qui est la mémoire physique réellement utilisée par le processus (plus pertinente que VSZ)
	# - head -n 11 limite la sortie aux 11 premières lignes (1 entête + 10 processus)
  ps aux --sort=-rss | head -n 11
  echo

  echo -e "${BOLD}${BLUE}${ICON_STAT} Statistiques mémoire et swap (vmstat 1 5) :${RESET}"
	# vmstat affiche des statistiques sur la mémoire, l'activité CPU, l'I/O et les processus.
	# 1 : intervalle en secondes entre chaque rapport (1 seconde ici)
	# 5 : nombre total de rapports à afficher (5 relevés)
  vmstat 1 5
  echo
}

# === Fonction : Rapport réseau Linux natif simple ===
rapport_reseau_simple() {
  echo -e "${BOLD}${CYAN}${ICON_NET} === Rapport réseau Linux natif ===${RESET}"
  echo

  echo -e "${BOLD}${GREEN}${ICON_NET} Interfaces réseau (ip addr) :${RESET}"
	# Affiche les interfaces réseau et leurs adresses IP (IPv4 et IPv6) sans indentation
	# - ip addr show : liste toutes les interfaces réseau avec détails
	# - grep filtre lignes contenant numéro d'interface ou adresses inet
	# - sed supprime l'indentation en début de ligne pour lisibilité
  ip addr show | grep -E "^[0-9]+:|inet " | sed 's/^[ \t]*//'
  echo

  echo -e "${BOLD}${YELLOW}${ICON_ROUTE} Table de routage (ip route) :${RESET}"
	# Affiche la table de routage IP actuelle
	# Montre les réseaux, passerelles, et interfaces associées au routage des paquets
  ip route show
  echo

  echo -e "${BOLD}${MAGENTA}${ICON_CONN} Connexions réseau actives (ss -tunap, 20 lignes) :${RESET}"
	# Affiche les 20 premières connexions réseau actives avec détails :
	# -t TCP, -u UDP, -n pas de résolution noms, -a toutes les connexions, -p processus lié
	# Donne les adresses, ports, états et PID/nom du programme
  ss -tunap | head -n 20
  echo

  echo -e "${BOLD}${BLUE}${ICON_DNS} Résolution DNS (dig google.fr) :${RESET}"
	# Réalise une requête DNS simplifiée pour google.fr
	# +short affiche uniquement les réponses sans détails supplémentaires
	# head -n 3 limite à 3 adresses IP retournées (ex. dans le cas de plusieurs A ou AAAA)
  dig +short google.fr | head -n 3
  echo

  GATEWAY=$(ip route | grep default | awk '{print $3}')
  echo -e "${BOLD}${CYAN}${ICON_TRAFFIC} Ping passerelle ($GATEWAY) :${RESET}"
  ping -c 4 "$GATEWAY"
  echo

  echo -e "${BOLD}${RED}${ICON_TRAFFIC} Capture tcpdump 5 paquets interface active :${RESET}"
  ACTIVE_IF=$(ip -o link show up | grep -v " lo" | head -1 | cut -d: -f2 | sed 's/ //g')
  if [[ -n "$ACTIVE_IF" ]]; then
	# tcpdump capture et affiche les paquets réseau en temps réel
	# Utilisé pour analyser le trafic réseau sur une interface donnée
	# Nécessite souvent les privilèges root
	# Options courantes : -i <interface> pour choisir l’interface, -c <nombre> pour limiter le nombre de paquets
	# Ex : tcpdump -i eth0 -c 10 capture 10 paquets sur eth0
	# Capture 5 paquets sur l'interface active définie dans $ACTIVE_IF avec tcpdump en mode superutilisateur
	# -c 5 : limite la capture à 5 paquets
	# -i "$ACTIVE_IF" : spécifie l'interface réseau à écouter
	# Requiert sudo pour accéder aux interfaces réseau en mode promiscue
    sudo tcpdump -c 5 -i "$ACTIVE_IF"
  else
    echo -e "${YELLOW}Aucune interface réseau active détectée pour tcpdump.${RESET}"
  fi
  echo

  echo -e "${BOLD}${GREEN}${ICON_OK} === Fin rapport réseau natif ===${RESET}"
}
##############################
#RAPPORT RESEAU AVANCEE      #
##############################
rapport_reseau_avance() {
  echo -e "${BOLD}${CYAN}${ICON_NET} === Rapport réseau avancé Linux et Docker ===${RESET}"
  echo

  echo -e "${BOLD}${GREEN}${ICON_NET} Interfaces réseau (ip addr) :${RESET}"
  ip addr show | grep -E "^[0-9]+:|inet " | sed 's/^[ \t]*//'
  # Affiche uniquement les lignes contenant le numéro d’interface ou les adresses IP, en supprimant l’indentation
  echo

  echo -e "${BOLD}${YELLOW}${ICON_ROUTE} Table de routage (ip route) :${RESET}"
  ip route show 
  # Liste les routes configurées indiquant les chemins de routage des paquets
  echo

  echo -e "${BOLD}${MAGENTA}${ICON_CONN} Connexions réseau actives (ss -tunap) :${RESET}"
  ss -tunap | head -n 20 
  # Limite l’affichage aux 20 premières connexions pour lisibilité
  echo

  echo -e "${BOLD}${BLUE}${ICON_DNS} Résolution DNS (dig google.fr) :${RESET}"
  dig +short google.fr | head -n 3 
  # Affiche jusqu’à 3 adresses IP retournées par le serveur DNS
  echo

  GATEWAY=$(ip route | grep default | awk '{print $3}')
  echo -e "${BOLD}${CYAN}${ICON_TRAFFIC} Ping passerelle ($GATEWAY) :${RESET}"
  ping -c 4 "$GATEWAY" 
  # Envoie 4 paquets ICMP echo-request vers la passerelle pour vérifier la connectivité locale
  echo

  echo -e "${BOLD}${RED}${ICON_FIREWALL} Règles iptables -v (INPUT, OUTPUT, FORWARD) :${RESET}"
  sudo iptables -L -v --line-numbers | grep -E "Chain|pkts|ACCEPT|DROP"
  # Liste les règles iptables avec compteurs de paquets/bytes et numéros de ligne
  # Filtre pour afficher uniquement les chaînes, paquets, règles ACCEPT et DROP
  echo

  echo -e "${BOLD}${RED}${ICON_FIREWALL} Règles nftables (30 lignes, si présentes) :${RESET}"
  # Affiche les 30 premières lignes des règles nftables si nft est installé
  # nft list ruleset : liste l'ensemble des tables, chaînes et règles en place
  # head -n 30 limite la sortie pour éviter un affichage trop long
  # Message avertit si nftables non configuré ou absent
  if command -v nft &>/dev/null; then
    sudo nft list ruleset | head -n 30
  else
    echo -e "${YELLOW}nftables non installé ou configuré.${RESET}"
  fi
  echo

  echo -e "${BOLD}${GREEN}${ICON_DOCKER} Réseaux Docker (docker network ls) :${RESET}"
  if ! docker info &>/dev/null; then
    echo -e "${RED}${ICON_FAIL} Impossible de se connecter au démon Docker. Docker semble ne pas tourner.${RESET}"
  else
    docker network ls
    echo

    echo -e "${BOLD}${GREEN}${ICON_DOCKER} Inspection réseau docker 'bridge' :${RESET}"
    docker network inspect bridge | jq '.[] | {Name,Id,Containers}'
    echo

    echo -e "${BOLD}${GREEN}${ICON_DOCKER} Conteneurs docker actifs :${RESET}"
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"
    echo

    echo -e "${BOLD}${GREEN}${ICON_DOCKER} IP et connexions dans conteneurs docker :${RESET}"
    for cid in $(docker ps -q); do
      cname=$(docker inspect --format '{{.Name}}' "$cid" | sed 's/^\/\(.*\)/\1/')
      echo -e "${BOLD}Conteneur:${RESET} $cname"
      echo -ne " IP: "
      docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$cid"
      echo
      echo -e " Connexions réseau (ss -tunap dans conteneur):"
      docker exec "$cid" ss -tunap | head -n 10
      echo
    done
  fi

  echo -e "${BOLD}${RED}${ICON_TRAFFIC} Capture tcpdump avancée (15 paquets ICMP + TCP port 80) :${RESET}"
  ACTIVE_IF=$(ip -o link show up | grep -v " lo" | head -1 | cut -d: -f2 | sed 's/ //g')
  if [[ -n "$ACTIVE_IF" ]]; then
    # Lance tcpdump avec timeout pour éviter blocage long
    timeout 10s sudo tcpdump -c 15 -i "$ACTIVE_IF" icmp or tcp port 80 || echo -e "${YELLOW}tcpdump interrompu ou timeout${RESET}"
  else
    echo -e "${YELLOW}Interface active introuvable pour tcpdump.${RESET}"
  fi
  echo

  echo -e "${BOLD}${MAGENTA}${ICON_ADV} Scan ports local (nmap localhost) :${RESET}"
  if command -v nmap &>/dev/null; then
    sudo timeout 10s nmap -sS -O localhost | head -n 30
  else
    echo -e "${YELLOW}nmap non installé. Tentative d'installation en cours...${RESET}"
    sudo apt-get update -qq && sudo apt-get install -y nmap
    if command -v nmap &>/dev/null; then
      echo -e "${GREEN}nmap installé avec succès, relance du scan...${RESET}"
      sudo timeout 10s nmap -sS -O localhost | head -n 30
    else
      echo -e "${RED}Échec installation nmap. Scan impossible.${RESET}"
    fi
  fi
  echo

  echo -e "${BOLD}${MAGENTA}${ICON_ADV} Test débit (iperf3 vers localhost port 5201) :${RESET}"
  if command -v iperf3 &>/dev/null; then
    iperf3 -c 127.0.0.1 -p 5201 -t 3 || echo -e "${YELLOW}Serveur iperf3 non disponible ou test échoué.${RESET}"
  else
    echo -e "${YELLOW}iperf3 non installé. Tentative d'installation en cours...${RESET}"
    sudo apt-get update -qq && sudo apt-get install -y iperf3
    if command -v iperf3 &>/dev/null; then
      echo -e "${GREEN}iperf3 installé avec succès, relance du test...${RESET}"
      iperf3 -c 127.0.0.1 -p 5201 -t 3 || echo -e "${YELLOW}Test iperf3 échoué.${RESET}"
    else
      echo -e "${RED}Échec installation iperf3. Test impossible.${RESET}"
    fi
  fi
  echo

  echo -e "${BOLD}${GREEN}${ICON_OK} === Fin rapport réseau avancé ===${RESET}"
}

# === Fonction : Partie 9 - Compléments réseau & diagnostics avancés ===
# arp : affiche et modifie la table ARP (association adresses IP / MAC).
# iproute2 : suite d'outils pour configurer les interfaces, routes et règles réseau (commande ip).
# ethtool : permet d'interroger et configurer les paramètres matériels des interfaces Ethernet (vitesse, duplex, tests).
# mtr : trace route dynamique combinant ping et traceroute pour diagnostic réseau.
# netcat-openbsd : outil polyvalent pour créer des connexions réseau, scanner des ports, servir de canal de transfert.

partie_9_complements_reseau() {
  echo -e "${BOLD}${CYAN}=== Compléments réseau et diagnostics avancés ===${RESET}"
  echo

  # --- Vérification et installation outils nécessaires ---
  for pkg in arp iproute2 ethtool mtr netcat-openbsd; do
    if ! command -v "$pkg" &>/dev/null; then
      echo -e "${YELLOW}Le paquet ${pkg} n'est pas installé. Installation en cours...${RESET}"
      sudo apt-get update -qq
      sudo apt-get install -y "$pkg"
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}Installation de ${pkg} réussie.${RESET}"
      else
        echo -e "${RED}Échec de l'installation de ${pkg}. Certaines fonctionnalités pourront manquer.${RESET}"
      fi
    fi
  done
  echo

  # --- Inspection avancée ARP ---
  echo -e "${BOLD}${GREEN}Table ARP (relations IP <> MAC) :${RESET}"
  echo -e "Affiche la table ARP (liaisons IP <-> MAC) et état des voisins réseau."
  ip neigh show 
  echo

  # --- Etude du matériel réseau avec ethtool ---
  # Pour chaque interface réseau active sauf loopback
  # Affiche 15 premières lignes des infos matérielles et statut via ethtool
  for iface in $(ip -o link show up | grep -v " lo" | cut -d: -f2 | sed 's/ //g'); do
    echo -e "${BOLD}${MAGENTA}Infos ethtool sur interface $iface :${RESET}"
    sudo ethtool "$iface" | head -n 15
    echo
  done

  # --- Traceroute dynamique avec mtr ---
  # Teste la route réseau vers 8.8.8.8 avec mtr (traceur + ping en continu, nécessite sudo), 
  # avec timeout de 15s. Si mtr absent, utilise traceroute classique en fallback.

	echo -e "${BOLD}${BLUE}Test traceroute dynamique (mtr vers 8.8.8.8) :${RESET}"
	if command -v mtr &>/dev/null; then
	  echo -e "${YELLOW}Attention: mtr nécessite souvent sudo pour fonctionner complètement.${RESET}"
	  # Utilisation timeout et sudo
	  timeout 15s sudo mtr -rwzbc5 8.8.8.8 2>/dev/null || echo -e "${RED}mtr interrompu ou échec${RESET}"
	else
	  echo -e "${YELLOW}mtr non installé, test traceroute simple avec traceroute:${RESET}"
	  if command -v traceroute &>/dev/null; then
	    traceroute 8.8.8.8 | head -n 20
	  else
	    echo -e "${RED}traceroute non installé non plus.${RESET}"
	  fi
	fi
	echo

  # --- Test de port TCP avec netcat ---
  # Exemples ports connus SSH 22 et HTTP 80 sur localhost
  # Teste si les ports TCP 22 et 80 sont ouverts localement en tentant une connexion avec délai de 3s.
  echo -e "${BOLD}${CYAN}Test de connectivité port (netcat) :${RESET}"
  for port in 22 80; do
    nc -zv -w3 127.0.0.1 "$port" &>/dev/null && \
    echo -e "Port $port : ${GREEN}Ouvert${RESET}" || \
    echo -e "Port $port : ${RED}Fermé ou inaccessible${RESET}"
  done
  echo

  # --- Vérification état services réseau critiques ---
  # Vérifie si les services critiques (ssh, networking, docker) sont actifs.
  SERVICES=("ssh" "networking" "docker")
  echo -e "${BOLD}${MAGENTA}Vérification état services critiques :${RESET}"
  for svc in "${SERVICES[@]}"; do
    systemctl is-active --quiet "$svc"
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}$svc actif${RESET}"
    else
      echo -e "${RED}$svc inactif ou absent${RESET}"
    fi
  done
  echo

  # --- Lecture ciblée des logs réseau récents ---
  # Affiche les 20 dernières lignes des logs système réseau (syslog, NetworkManager) si accessibles,
  # puis liste les processus clés liés au réseau (docker, ssh).

  echo -e "${BOLD}${YELLOW}Lecture logs réseau récents (syslog, NetworkManager) :${RESET}"
  echo -e "${ICON_LOG} /var/log/syslog (dernières 20 lignes) :"
  tail -n 20 /var/log/syslog 2>/dev/null || echo "Accès syslog impossible"
  echo
  echo -e "${ICON_LOG} journalctl -u NetworkManager (20 dernières lignes) :"
  journalctl -u NetworkManager -n 20 --no-pager 2>/dev/null || echo "Aucun NetworkManager ou accès refusé"
  echo

  # --- Analyse des processus réseaux importants ---
  echo -e "${BOLD}${CYAN}Processus réseau principaux (dockerd, containerd, sshd, autre) :${RESET}"
  ps aux | grep -E "dockerd|containerd|sshd" | grep -v grep
  echo

  echo -e "${BOLD}${GREEN}=== Fin Compléments réseau et diagnostics avancés ===${RESET}"
  echo
}


# === MENU PRINCIPAL ===
clear
echo -e "${BOLD}${WHITE}${INVERSE}============ MENU SYSTÈME ===========${RESET}"
echo -e "1) ${CYAN}Usage disque${RESET}"
echo -e "2) ${CYAN}Usage disque emplacement donné${RESET}"
echo -e "3) ${CYAN}Backup système compressé${RESET}"
echo -e "5) ${CYAN}Usage CPU avancé${RESET}"
echo -e "6) ${CYAN}Usage RAM${RESET}"
echo -e "7) ${CYAN}Rapport réseau natif Linux${RESET}"
echo -e "8) ${CYAN}Rapport réseau avancé Docker & Firewall${RESET}"
echo -e "9) ${CYAN}Compléments réseau & diagnostics avancés${RESET}"
echo -e "10) ${CYAN}Quitter${RESET}"
echo -ne "${UNDERLINE}Votre choix : ${RESET}"
read menu

case $menu in
  1)
    usage_disk
    ;;
  2)
    usage_disk_location
    ;;
  3)
    backup_system
    ;;
  5)
    usage_cpu
    ;;
  6)
    usage_ram
    ;;
  7)
    rapport_reseau_simple
    ;;
  8)
    rapport_reseau_avance
    ;;
  9)
    partie_9_complements_reseau
    ;;	
  10)
    echo -e "${GREEN}Sortie du script. Bye !${RESET}"
    exit 0
    ;;
  *)
    echo -e "${RED}${BLINK}Option invalide.${RESET}"
    ;;
esac
