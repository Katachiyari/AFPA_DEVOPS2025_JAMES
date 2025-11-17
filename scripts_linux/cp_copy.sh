#!/bin/bash
CYAN="\033[1;36m"
NC="\033[0m"
OK="\033[1;32m✅\033[0m"      # Succès
FAIL="\033[1;31m❌\033[0m"    # Échec
INFO="\033[1;34m☑️\033[0m"    # Info

printf "%bSur quel serveur ?%b\n" "$CYAN" "$NC"
printf "%b1%b Srv-1 AFPA  |  %b2%b Srv-2 VPS\n" "$CYAN" "$NC" "$CYAN" "$NC"
read -p "Ton choix (1 ou 2) : " menu

if [ "$menu" -eq 1 ]; then
    printf "%bTransfert vers AFPA...%b\n" "$INFO" "$NC"
    scp /opt/scripts/gsrv.sh james@10.8.0.30:/opt/scripts
    if [ $? -eq 0 ]; then
        printf "%b Transfert réussi vers AFPA !%b\n" "$OK" "$NC"
    else
        printf "%b Échec du transfert vers AFPA !%b\n" "$FAIL" "$NC"
    fi
elif [ "$menu" -eq 2 ]; then
    printf "%bTransfert vers VPS...%b\n" "$INFO" "$NC"
    scp /opt/scripts/gsrv.sh wakidaisho@185.45.112.40:/opt/scripts
    if [ $? -eq 0 ]; then
        printf "%b Transfert réussi vers VPS !%b\n" "$OK" "$NC"
    else
        printf "%b Échec du transfert vers VPS !%b\n" "$FAIL" "$NC"
    fi
else
    printf "%b Choix invalide.%b\n" "$FAIL" "$NC"
fi
