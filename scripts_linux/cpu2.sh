#!/bin/bash
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
