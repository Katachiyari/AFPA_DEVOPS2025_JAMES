#!/bin/bash
# Affiche descripteurs et données détaillées d'utilisation CPU

# Affichage de la signification des champs CPU
printf "+-------------------------------+--------------------------------------------------------------+\n"
printf "| %-29s | %-60s |\n" "Clé" "Description"
printf "+-------------------------------+--------------------------------------------------------------+\n"
printf "| %-29s | %-60s |\n" "us (user)" "Temps CPU utilisé par les processus utilisateur normaux"
printf "| %-29s | %-60s |\n" "sy (system)" "Temps CPU utilisé par les processus du noyau (kernel)"
printf "| %-29s | %-60s |\n" "ni (nice)" "Temps CPU utilisé par les processus nice (priorité ajustée)"
printf "| %-29s | %-60s |\n" "id (idle)" "Temps CPU inactif"
printf "| %-29s | %-60s |\n" "wa (I/O wait)" "Temps d'attente sur I/O"
printf "| %-29s | %-60s |\n" "hi" "Temps CPU interruptions matérielles"
printf "| %-29s | %-60s |\n" "si" "Temps CPU interruptions logicielles"
printf "| %-29s | %-60s |\n" "st (steal time)" "Temps CPU virtuel « volé » par l'hyperviseur"
printf "+-------------------------------+--------------------------------------------------------------+\n"

# Extraction et affichage détaillé des valeurs CPU via top
cpu_line=$(top -bn1 | grep "Cpu(s)")
# Découpe chaque champ (virgule comme séparateur)
IFS=',' read -ra cpu_fields <<< "${cpu_line#*:}"

# Affichage explicite formaté
echo -e "\033[1mDétail d'utilisation CPU :\033[0m"
echo "Utilisateur (us)    : $(echo "${cpu_fields[0]}" | sed -E 's/^ *([0-9\.]+).*$/\1/') %"
echo "Système (sy)        : $(echo "${cpu_fields[1]}" | sed -E 's/^ *([0-9\.]+).*$/\1/') %"
echo "Nice (ni)           : $(echo "${cpu_fields[2]}" | sed -E 's/^ *([0-9\.]+).*$/\1/') %"
echo "Idle (id)           : $(echo "${cpu_fields[3]}" | sed -E 's/^ *([0-9\.]+).*$/\1/') %"
echo "I/O Wait (wa)       : $(echo "${cpu_fields[4]}" | sed -E 's/^ *([0-9\.]+).*$/\1/') %"
echo "Hard Int. (hi)      : $(echo "${cpu_fields[5]}" | sed -E 's/^ *([0-9\.]+).*$/\1/') %"
echo "Soft Int. (si)      : $(echo "${cpu_fields[6]}" | sed -E 's/^ *([0-9\.]+).*$/\1/') %"
echo "Steal (st)          : $(echo "${cpu_fields[7]}" | sed -E 's/^ *([0-9\.]+).*$/\1/') %"

# Nombre de cœurs physiques
ncores=$(lscpu | awk '/^CPU\(s\):/ {print $2}')
printf "Nombre de coeurs CPU : %s\n" "$ncores"
# Fréquence actuelle
freq_cur=$(lscpu | awk '/^CPU MHz:/ {print $3}')
printf "Fréquence actuelle : %s MHz\n" "$freq_cur"

