#!/bin/bash
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
