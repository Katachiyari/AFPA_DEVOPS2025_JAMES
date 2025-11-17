#!/bin/bash

######################################################################
# Script de menu système avec couleurs ANSI et options
######################################################################

#user=$(whoami)
#if groups "$user" | grep -qw "sudo"; then

# --- Définition couleurs/styling ANSI (toujours \033, jamais \e)
GREEN="\033[32m"
BLUE="\033[34m"
RED="\033[31m"
YELLOW="\033[33m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[97m"
BLINK="\033[5m"
INVERSE="\033[7m"
STRIKE="\033[9m"
NC="\033[0m"
BOLD="\033[1m"
UNDERLINE="\033[4m"

# --- Affichage du menu principal propre et coloré
printf "1 $CYAN - Usage disk $NC \t\t|| 2$CYAN - Usage disk à emplacement donné $NC \n"
printf "3 $CYAN - Save system/zip $NC \t|| 4 $CYAN - SCP send backup files $NC \n"
printf "5 $CYAN - Usage CPU\t\t|| 6 $CYAN - Usage RAM $NC \n"
printf "7 $CYAN - Network \t || - 8 $CYAN Network ++ $NC\n"
printf "9 $CYAN - Display modif from file $NC $BOLD /var/www $NC \n"
printf "10$CYAN - Exit $NC \n"

printf "${UNDERLINE}Fais ton choix${NC} : "
read menu

case $menu in
  1)
    df -h | awk '
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
        printf "%-15s %-15s %-15s %-10s %-30s\n", "Daemon", "Taille RAM", "Utilisé", "Util%", "Point de montage"
        print "-------------------------------------------------------------------------------------------"
      }
      {
        size_mb = convert_to_MB($2)
        used_mb = convert_to_MB($3)
        percent = (used_mb / size_mb) * 100
        printf "%-15s %-15s %-15s %9.2f%% %-30s\n", $1, $2, $3, percent, $6
      }'
    ;;
  2)
	# Utilisateurs courants (UID 1000 à 9999)
	users=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 10000 {print $1}')
	printf "${CYAN}Utilisateurs présents :${NC}\n"
	printf "%s\n" $users

	# Demande du chemin absolu, vérification entrée
	while true; do
	    printf "\n${UNDERLINE}Veuillez entrer le chemin absolu : ${NC}"
	    read -e absoluPath #-e completion avancée
	#-z si champ vide ou null = true | -e verifie que le fichier existe
	    if [[ -z "$absoluPath" ]] || [[ "$absoluPath" != /* ]] || [[ ! -e "$absoluPath" ]]; then
	        printf "${RED}Chemin invalide : %s${NC}\n" "$absoluPath"
	    else
	        break
	    fi
	done

	# Tableau des champs de la ligne de df
	#-r ne traite pas les \ | -a permet de stocké chaque mot dans un array
	read -ra infos <<< "$(df -h "$absoluPath" | awk 'NR==2')"

	# Extraire nom disque physique
	disk=$(echo "${infos[0]}" | cut -d'/' -f3 | cut -c1-3)
	size=$(du -sh "$absoluPath" | awk '{print $1}')
	nfiles=$(find "$absoluPath" -type f 2>/dev/null | wc -l)
	ndirs=$(find "$absoluPath" -type d 2>/dev/null | wc -l)
	# Date fr 
	#stat -c donne le timestamp de la derniere modif
	#date -d @temestamp -> format à la francaise
	#xarg -> passe à la date automatiquement
	lastmod=$(stat -c "%Y" "$absoluPath" 2>/dev/null | xargs -I {} date "+%d/%m/%Y %H:%M:%S" -d @{})
	owner=$(stat -c "%U" "$absoluPath" 2>/dev/null)
	group=$(stat -c "%G" "$absoluPath" 2>/dev/null)
	rights=$(stat -c "%A" "$absoluPath" 2>/dev/null)

	printf "+----------------------+------------------------------+\n"
	printf "| %-20s | %-28s |\n" "Clé" "Valeur"
	printf "+----------------------+------------------------------+\n"
	printf "| %-20s | %-28s |\n" "Répertoire" "$absoluPath"
	printf "| %-20s | %-28s |\n" "Taille réelle" "$size"
	printf "| %-20s | %-28s |\n" "Fichiers" "$nfiles"
	printf "| %-20s | %-28s |\n" "Dossiers" "$ndirs"
	printf "| %-20s | %-28s |\n" "Dernière modification" "$lastmod"
	printf "| %-20s | %-28s |\n" "Propriétaire" "$owner"
	printf "| %-20s | %-28s |\n" "Groupe" "$group"
	printf "| %-20s | %-28s |\n" "Droits" "$rights"
	printf "+----------------------+------------------------------+\n"
	#% = passage de variable
	#20 = largeur de 20 caractères minimum (28)
	#- =alignement a gauche
	#s = chaine de caractere

	# Récap disk
	printf "Le répertoire %s occupe %s\n(%s utilisés, %s disponibles, taille totale %s) sur le disque %s\n" \
	  "$absoluPath" "${infos[4]}" "${infos[2]}" "${infos[3]}" "${infos[1]}" "$disk"

    ;;
  3)
	printf "${NC} - Backup System and zip\n"
	OK="\033[1;32m✅\033[0m"
	FAIL="\033[1;31m❌\033[0m"
	INFO="\033[1;34m☑️\033[0m"
	WAIT="\033[1;36m⏳\033[0m"
	ASK="\033[1;35m❓\033[0m"
	NC="\033[0m"

	# 1. Saisie utilisateur simple
	read -p "Nom d'utilisateur SSH : " utilisateur
	read -p "Adresse IP distante SSH : " ip
	read -p "Port SSH : " port

	SRC=(/home /etc /var /opt)
	ARCHIVE="/tmp/backup_$(date +%Y%m%d_%H%M%S).tar.xz"
	REMOTE_DIR="/opt/save"
	REMOTE_ARCHIVE="$REMOTE_DIR/$(basename "$ARCHIVE")"

	# 2. Compression maximale et calcul de somme
	printf "%b Compression...\n" "$WAIT"
	tar -I "xz -9e" -cpf "$ARCHIVE" "${SRC[@]}"

	# Archive les dossiers /home, /etc, /var, /opt avec la compression xz maximale
	# -I "xz -9e" : utilise xz en mode compression++
	# -c : crée une archive
	# -p : préserve les permissions
	# -f : nom du fichier à créer
	# SRC[@] : tous les dossiers à sauvegarder

	if [ $? -ne 0 ]; then echo -e "$FAIL Echec de la compression."; exit 1; fi
	# Calcule la somme SHA-256 de larchive, extrait uniquement le hash
	SUM_LOCAL=$(sha256sum "$ARCHIVE" | awk '{print $1}')
	printf "%b Archive prête : %s (%s)\n" "$OK" "$ARCHIVE" "$SUM_LOCAL"

	# 3. Test SSH et création dossier distant (sudo)
	printf "%b Test SSH ... " "$INFO"
	ssh -p "$port" -o ConnectTimeout=7 "$utilisateur@$ip" exit 2>/dev/null
	if [ $? -ne 0 ]; then echo -e "\n$FAIL Impossible de se connecter."; rm -f "$ARCHIVE"; exit 2; fi
	printf "$OK\n"
	printf "%b Préparation du dossier distant\n" "$INFO"
	ssh -t -p "$port" "$utilisateur@$ip" "sudo mkdir -p $REMOTE_DIR && sudo chown $utilisateur:$utilisateur $REMOTE_DIR"

	# 4. Transfert de l'archive (progression, compression, SSH)
	printf "%b Transfert de l'archive :\n" "$WAIT"
	rsync -avzP -e "ssh -p $port" --progress --stats "$ARCHIVE" "$utilisateur@$ip:$REMOTE_ARCHIVE"
	if [ $? -ne 0 ]; then echo -e "$FAIL Echec du transfert."; rm -f "$ARCHIVE"; exit 3; fi

	# 5. Vérification de la somme à distance
	SUM_DIST=$(ssh -p "$port" "$utilisateur@$ip" "sha256sum '$REMOTE_ARCHIVE' 2>/dev/null | awk '{print \$1}'")

	if [[ "$SUM_LOCAL" == "$SUM_DIST" && -n "$SUM_DIST" ]]; then
	  echo -e "$OK Vérification d'intégrité réussie ($SUM_DIST) !"
	else
	  echo -e "$FAIL Somme locale : $SUM_LOCAL\n$FAIL Somme distante: $SUM_DIST"
	  echo -e "$FAIL Corruption possible ! Supprime et abandon."
	  ssh -p "$port" "$utilisateur@$ip" "rm -f '$REMOTE_ARCHIVE'"
	  rm -f "$ARCHIVE"
	  exit 4
	fi

	# 6. Nettoyage local (optionnel)
	rm -f "$ARCHIVE"
	echo -e "$OK Sauvegarde sécurisée et vérifiée dans $REMOTE_DIR sur $ip."





	##############################################################################################
	#Fichiers a sauvegarder                                                                      #
	#/home /etc /var /opt /root /usr/local/opt/save/                                             #
	##############################################################################################
	# -a  : mode archive, copie récursive et préserve droits, dates, liens, groupes, propriétaires
	# -A  : préserve les ACLs (Listes de Contrôle d’Accès avancées)[5]
	# -X  : préserve les attributs étendus (xattrs)[5]
	# -v  : mode verbeux, affiche le détail des transferts (verbose)
# -P  : affiche la progression et conserve les transferts partiels en cas d’interruption[5]
    ;;
  4)
    printf "${NC} - SCP - send backup files FTP or USB or SCP\n"
    ;;
  5)
	printf "${NC} - Usage CPU\n"
	# Audit CPU avancé avec emojis réels et couleurs ANSI

	OK="\033[1;32m✅\033[0m"
	FAIL="\033[1;31m❌\033[0m"
	INFO="\033[1;34m☑️\033[0m"

	printf "%-8s │ %-45s\n" "us" "Temps utilisateur (processus non système)"
	printf "%-8s │ %-45s\n" "sy" "Temps système (kernel)"
	printf "%-8s │ %-45s\n" "ni" "Processus nice (priorité ajustée, ex: \"gentil\")"
	printf "%-8s │ %-45s\n" "id" "Inactif (CPU au repos, disponible)"
	printf "%-8s │ %-45s\n" "wa" "Attente E/S (disques, réseau)"
	printf "%-8s │ %-45s\n" "hi" "Interruption matérielle (périphériques)"
	printf "%-8s │ %-45s\n" "si" "Interruption logicielle (OS, soft IRQ)"
	printf "%-8s │ %-45s\n" "st" "Steal time (CPU utilisé par une autre VM)"

	# 1. Installation et activation de mpstat
	if ! command -v mpstat &>/dev/null; then
	    printf "%b mpstat non présent, installation automatique...\n" "$INFO"
	    sudo apt-get update -qq && sudo apt-get install -y sysstat
	    if grep -qiE 'debian|ubuntu' /etc/os-release; then
	        sudo sed -i 's/ENABLED=\"false\"/ENABLED=\"true\"/' /etc/default/sysstat 2>/dev/null
	        sudo systemctl enable --now sysstat &>/dev/null
	    fi
	    if command -v mpstat &>/dev/null; then
	        printf "%b mpstat installé et activé avec succès\n" "$OK"
	    else
	        printf "%b Installation de mpstat échouée\n" "$FAIL"
	        exit 1
	    fi
	else
	    printf "%b mpstat déjà présent sur le système\n" "$OK"
	fi

	# 2. Affichage synthétique CPU
	printf "%6s  %8s  %8s  %8s  %8s  %8s  %8s  %8s  %8s\n" \
	  "Coeur" "us" "sy" "ni" "id" "wa" "hi" "si" "st"
	printf '%s\n' "---------------------------------------------------------------"
	printf "%6s  %8.2f  %8.2f  %8.2f  %8.2f  %8.2f  %8.2f  %8.2f  %8.2f\n" \
	  "all" 0.00 0.00 0.00 100.00 0.00 0.00 0.00 0.00
	# Exemple pour chaque coeur :
	for core in 0 1 2 3 4 5 6 7; do
	    printf "%6d  %8.2f  %8.2f  %8.2f  %8.2f  %8.2f  %8.2f  %8.2f  %8.2f\n" \
	      "$core" 0.00 0.00 0.00 100.00 0.00 0.00 0.00 0.00
	done

	# 3. Vue instantanée avec top
	printf "%b [top] Consommation CPU globale :\n" "$INFO"
	top -bn1 | grep "Cpu(s)" | awk '{print "us:", $2 "% | sy:", $4 "% | ni:", $6 "% | id:", $8 "% | wa:", $10 "% | hi:", $12 "% | si:", $14 "% | st:", $16 "%"}'
	printf "\n"

	# 4. Processus les plus consommateurs
	printf "%b TOP 5 processus les plus gourmands :\n" "$INFO"
	printf "%5s %8s  %s\n" "PID" "%CPU" "Commande"
	ps -eo pid,pcpu,comm --sort=-pcpu | head -n 6

	# 5. Informations matérielles CPU
	printf "%b Infos matérielles (lscpu) :\n" "$INFO"
	lscpu | grep -E 'Model name|CPU\(s\):|Thread|MHz|NUMA' | sort | uniq
	printf "\n"

	# 6. Export dans le log
	LOGF="/var/log/cpu_audit.log"
	echo "------ CPU AUDIT $(date '+%d/%m/%Y %H:%M') ------" >> "$LOGF"
	top -bn1 | grep "Cpu(s)" | awk '{print "Global CPU : us=" $2 ", sy=" $4 ", ni=" $6 ", id=" $8 ", wa=" $10 ", hi=" $12 ", si=" $14 ", st=" $16 }' >> "$LOGF"
	ps -eo pid,pcpu,comm --sort=-pcpu | head -n 6 >> "$LOGF"
	printf "%b Rapport exporté dans %s\n" "$OK" "$LOGF"
    ;;
  6)

	# Couleurs pour la sortie
	GREEN="\033[1;32m"
	YELLOW="\033[1;33m"
	RED="\033[1;31m"
	CYAN="\033[1;36m"
	BLUE="\033[1;34m"
	RESET="\033[0m"
	BOLD="\033[1m"

	# Icônes Unicode pour la RAM, swap, processus, etc.
	ICON_RAM="🧠"
	ICON_SWAP="💾"
	ICON_PROC="⚙️"
	ICON_STAT="📊"
	ICON_CHECK="✅"
	ICON_ALERT="⚠️"
	ICON_TITLE="📋"

	echo -e "${BOLD}${CYAN}${ICON_TITLE} === Rapport d'utilisation RAM ===${RESET}"
	echo

	# Résumé de la mémoire avec free, titre coloré
	echo -e "${BOLD}${GREEN}${ICON_RAM} Résumé mémoire (free -h) :${RESET}"
	free -h
	echo

	# Extraction des infos clés depuis /proc/meminfo avec couleurs
	echo -e "${BOLD}${YELLOW}${ICON_RAM} Détails mémoire clés (/proc/meminfo) :${RESET}"
	grep -E 'MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree' /proc/meminfo | while read -r line; do
	    key=$(echo $line | cut -d: -f1)
	    value=$(echo $line | cut -d: -f2- | sed 's/^[ \t]*//')
	    case $key in
	        MemTotal*)  echo -e "${GREEN}$key: ${RESET}$value" ;;
	        MemFree*)   echo -e "${CYAN}$key: ${RESET}$value" ;;
	        MemAvailable*) echo -e "${BLUE}$key: ${RESET}$value" ;;
	        SwapTotal*) echo -e "${YELLOW}$key: ${RESET}$value" ;;
	        SwapFree*)  echo -e "${RED}$key: ${RESET}$value" ;;
	    esac
	done
	echo

	# Top 10 processus consommateurs mémoire avec titre coloré et icône
	echo -e "${BOLD}${MAGENTA}${ICON_PROC} Top 10 processus par consommation mémoire (RSS) :${RESET}"
	ps aux --sort=-rss | head -n 11
	echo

	# Statistiques mémoire et swap en temps réel avec vmstat et titre coloré
	echo -e "${BOLD}${BLUE}${ICON_STAT} Statistiques mémoire en temps réel (vmstat 1 5) :${RESET}"
	vmstat 1 5
	echo

	echo -e "${BOLD}${CYAN}${ICON_CHECK} === Fin du rapport ===${RESET}"

    ;;
  7)
	# Définition des codes couleur pour la sortie
	GREEN="\033[1;32m"    # Vert vif pour succès/info
	YELLOW="\033[1;33m"   # Jaune pour warning/attention
	RED="\033[1;31m"      # Rouge pour alertes/erreurs
	CYAN="\033[1;36m"     # Cyan pour les sections info
	BLUE="\033[1;34m"     # Bleu pour DNS ou info technique
	MAGENTA="\033[1;35m"  # Magenta pour connexions réseau
	RESET="\033[0m"       # Reset des couleurs
	BOLD="\033[1m"        # Gras pour titres

	# Définition des icônes Unicode pour visuel clair
	ICON_NET="🌐"         # Globe pour section réseau générale
	ICON_IFACE="🔌"       # Prise pour interfaces réseau
	ICON_ROUTE="🛣️"       # Route pour table de routage
	ICON_CONN="🔍"        # Loupe pour connexions réseau
	ICON_DNS="⚙️"         # Engrenage pour DNS
	ICON_TRAFFIC="📡"     # Antenne pour trafic/ping
	ICON_ALERT="⚠️"       # Alerte pour paquets tcpdump
	ICON_SUCCESS="✅"     # Succès pour fin rapport

	# Affichage du titre principal du rapport avec couleur et icône
	echo -e "${BOLD}${CYAN}${ICON_NET} === Rapport réseau Linux natif ===${RESET}"
	echo

	# Affiche les interfaces réseau actives avec ip addr, en filtrant les lignes utiles
	echo -e "${BOLD}${GREEN}${ICON_IFACE} Interfaces réseau (ip addr) :${RESET}"
	ip addr show | grep -E "^[0-9]+:|inet " | sed 's/^[ \t]*//'
	echo

	# Affiche la table de routage IP actuelle de la machine
	echo -e "${BOLD}${YELLOW}${ICON_ROUTE} Table de routage (ip route) :${RESET}"
	ip route show
	echo

	# Montre les connexions TCP/UDP en cours, avec les processus associés, limité à 20 lignes
	echo -e "${BOLD}${MAGENTA}${ICON_CONN} Connexions réseau actives (ss -tunap) :${RESET}"
	ss -tunap | head -n 20
	echo

	# Teste la résolution DNS de google.fr, affiche les 3 premières IPs retournées
	echo -e "${BOLD}${BLUE}${ICON_DNS} Résolution DNS pour google.fr (dig) :${RESET}"
	dig +short google.fr | head -n 3
	echo

	# Détecte automatiquement la passerelle par défaut pour un ping de test
	GATEWAY=$(ip route | grep default | awk '{print $3}')
	echo -e "${BOLD}${CYAN}${ICON_TRAFFIC} Ping vers la passerelle par défaut (${GATEWAY}) :${RESET}"
	ping -c 4 $GATEWAY
	echo

	# Trouve une interface réseau active autre que lo pour une capture tcpdump
	echo -e "${BOLD}${RED}${ICON_ALERT} Capture 5 paquets sur interface active (tcpdump) :${RESET}"
	ACTIVE_IF=$(ip -o link show up | grep -v " lo" | head -1 | cut -d: -f2 | sed 's/ //g')
	# Lance tcpdump si interface valide, sinon avertit
	if [[ -n "$ACTIVE_IF" ]]; then
	  sudo tcpdump -c 5 -i $ACTIVE_IF
	else
	  echo "Aucune interface réseau active détectée pour tcpdump."
	fi
	echo

	# Indique la fin du rapport avec icône et couleur
	echo -e "${BOLD}${GREEN}${ICON_SUCCESS} === Fin du rapport réseau ===${RESET}"

    ;;
  8)
    printf "${NC} - Network ++\n"

	# Couleurs pour sortie
	GREEN="\033[1;32m"       # Vert vif pour succès/info
	YELLOW="\033[1;33m"      # Jaune pour avertissements
	RED="\033[1;31m"         # Rouge pour alertes
	CYAN="\033[1;36m"        # Cyan pour sections et infos techniques
	BLUE="\033[1;34m"        # Bleu pour infos DNS et réseaux
	MAGENTA="\033[1;35m"     # Magenta pour connexions réseau
	RESET="\033[0m"          # Reset couleur
	BOLD="\033[1m"           # Gras pour titres

	# Icônes Unicode pour une meilleure visibilité
	ICON_NET="🌐"             # Réseau général
	ICON_IFACE="🔌"           # Interfaces réseau
	ICON_ROUTE="🛣️"           # Table de routage
	ICON_CONN="🔍"            # Connexions réseau
	ICON_DNS="⚙️"             # DNS
	ICON_TRAFFIC="📡"         # Ping / trafic
	ICON_ALERT="⚠️"           # Alerte / danger
	ICON_SUCCESS="✅"         # Succès / fin de rapport
	ICON_FIREWALL="🛡️"        # Firewall
	ICON_DOCKER="🐳"           # Docker
	ICON_ADV="🚀"              # Outils avancés

	echo -e "${BOLD}${CYAN}${ICON_NET} === Rapport réseau avancé Linux et Docker ===${RESET}"
	echo

	##############################
	# Interfaces réseau (ip addr) #
	##############################
	echo -e "${BOLD}${GREEN}${ICON_IFACE} Interfaces réseau (ip addr) :${RESET}"
	ip addr show | grep -E "^[0-9]+:|inet " | sed 's/^[ \t]*//'
	echo

	##############################
	# Table de routage IP (ip route) #
	##############################
	echo -e "${BOLD}${YELLOW}${ICON_ROUTE} Table de routage (ip route) :${RESET}"
	ip route show
	echo

	##################################
	# Connexions actives (ss -tunap) #
	##################################
	echo -e "${BOLD}${MAGENTA}${ICON_CONN} Connexions réseau actives (ss -tunap) :${RESET}"
	ss -tunap | head -n 20
	echo

	##############################
	# Résolution DNS (dig google.fr) #
	##############################
	echo -e "${BOLD}${BLUE}${ICON_DNS} Résolution DNS pour google.fr (dig) :${RESET}"
	dig +short google.fr | head -n 3
	echo

	##################################
	# Ping vers passerelle par défaut #
	##################################
	GATEWAY=$(ip route | grep default | awk '{print $3}')
	echo -e "${BOLD}${CYAN}${ICON_TRAFFIC} Ping vers la passerelle (${GATEWAY}) :${RESET}"
	ping -c 4 $GATEWAY
	echo

	##########################
	# Analyse Règles Firewall #
	##########################
	echo -e "${BOLD}${RED}${ICON_FIREWALL} Règles iptables (filter - chain INPUT, FORWARD, OUTPUT) :${RESET}"
	sudo iptables -L -v --line-numbers | grep -E "Chain|pkts|ACCEPT|DROP"
	echo

	echo -e "${BOLD}${RED}${ICON_FIREWALL} Règles nftables (si présentes) :${RESET}"
	if command -v nft &>/dev/null; then
	    sudo nft list ruleset | head -n 30
	else
	    echo -e "${YELLOW}nftables non installé ou non configuré.${RESET}"
	fi
	echo

	##############################
	# Docker : réseau et conteneurs #
	##############################
	echo -e "${BOLD}${GREEN}${ICON_DOCKER} Réseaux Docker (docker network ls) :${RESET}"
	docker network ls
	echo

	echo -e "${BOLD}${GREEN}${ICON_DOCKER} Détails réseau du réseau bridge (docker network inspect bridge) :${RESET}"
	docker network inspect bridge | jq '.[] | {Name,Id,Containers}'
	echo

	# Liste conteneurs en cours
	echo -e "${BOLD}${GREEN}${ICON_DOCKER} Conteneurs Docker actifs (docker ps) :${RESET}"
	docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"
	echo

	# Pour chaque conteneur actif, afficher IP et états réseaux
	echo -e "${BOLD}${GREEN}${ICON_DOCKER} Détails IP et connexions dans conteneurs Docker :${RESET}"
	for cid in $(docker ps -q); do
	    cname=$(docker inspect --format '{{.Name}}' $cid | sed 's/^\/\(.*\)/\1/')
	    echo -e "${BOLD}Conteneur:${RESET} $cname"
	    # Affichage IP réseau docker
	    docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $cid
	    # Connexions réseau dans le conteneur (ss)
	    docker exec $cid ss -tunap | head -n 10
	    echo
	done

	###########################
	# Analyse tcpdump avancée #
	###########################
	echo -e "${BOLD}${RED}${ICON_ALERT} Capture tcpdump avancée (15 paquets, filtre ICMP + TCP port 80) sur interface active :${RESET}"
	ACTIVE_IF=$(ip -o link show up | grep -v " lo" | head -1 | cut -d: -f2 | sed 's/ //g')
	if [[ -n "$ACTIVE_IF" ]]; then
	  sudo tcpdump -c 15 -i $ACTIVE_IF icmp or tcp port 80
	else
	  echo -e "${YELLOW}Aucune interface réseau active détectée pour tcpdump.${RESET}"
	fi
	echo

	####################
	# Outils réseau avancés #
	####################
	echo -e "${BOLD}${MAGENTA}${ICON_ADV} Scan ports locaux (nmap localhost) :${RESET}"
	if command -v nmap &>/dev/null; then
	    sudo nmap -sS -O localhost | head -n 30
	else
	    echo -e "${YELLOW}nmap non installé.${RESET}"
	fi
	echo

	echo -e "${BOLD}${MAGENTA}${ICON_ADV} Test débit réseau (iperf3 vers localhost port 5201) :${RESET}"
	if command -v iperf3 &>/dev/null; then
	    # iperf3 doit être lancé côté serveur séparément, ici test client basique
	    iperf3 -c 127.0.0.1 -p 5201 -t 3 || echo -e "${YELLOW}iperf3 serveur non disponible.${RESET}"
	else
	    echo -e "${YELLOW}iperf3 non installé.${RESET}"
	fi
	echo

	##########################
	# Fin du rapport réseau #
	##########################
	echo -e "${BOLD}${GREEN}${ICON_SUCCESS} === Fin du rapport réseau avancé ===${RESET}"

    ;;
  10)
    printf "${NC}- Exit\n"
    ;;
  *)
    printf "${RED}${BLINK}Option invalide${NC}\n"
    ;;
esac
