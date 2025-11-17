#!/bin/bash
#for element in "${infos[@]}"
#do
#    echo "$element"
#done

#recupere les utilisateurs courant
users=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 10000 {print $1}')

echo -e "Veuillez entrer le chemin absolu : (/repertoire = absolu, repertoire/ = relatif)"
printf "Les utilisateurs présents :\n"
printf "%s\n" $users
read absoluPath

# Tableau des champs de la ligne de df
read -ra infos <<< "$(df -h "$absoluPath" | awk 'NR==2')"

# Extraire le nom du disque physique à partir de la partition (champ 0)
disk=$(echo "${infos[0]}" | cut -d'/' -f3 | cut -c1-3)

printf "%s\n" "Le répertoire $absoluPath occupe ${infos[4]} sur le disque $disk"
