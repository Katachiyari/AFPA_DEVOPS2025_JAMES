#!/bin/bash

clear

echo "=== Menu d'automatisation clé SSH + durcissement serveur ==="
echo "1. Je suis sur Windows"
echo "2. Je suis sur Linux"
read -p "Sélectionne ton environnement [1/2] : " PLATFORM

if [ "$PLATFORM" = "1" ]; then
    echo
    echo "Windows détecté : procédure PowerShell à copier, coller dans la console PowerShell:"
    cat <<'EOS'

# NETTOYAGE de l'ancienne clé
Remove-Item $env:USERPROFILE\.ssh\wakidaisho*

# GÉNÉRATION nouvelle clé SSH ED25519 avec passphrase
ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\wakidaisho

# AFFICHAGE DE LA CLÉ PUBLIQUE À COPIER
Get-Content $env:USERPROFILE\.ssh\wakidaisho.pub

# Sur le serveur distant (via session existante ou console) :
# 1. Aller dans le HOME de l'utilisateur
# 2. Nettoyer les anciennes clés
rm -rf ~/.ssh
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 3. Coller la clé publique dans ~/.ssh/authorized_keys
echo "COLLE_TA_CLÉ_PUBLIQUE_ICI" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chown -R $(whoami):$(whoami) ~/.ssh

# 4. Sauvegarde et durcissement de sshd_config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bck
sudo sed -i -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
            -e 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' \
            -e 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' \
            -e 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' \
            -e 's/^#\?UsePAM.*/UsePAM yes/' \
            -e 's/^#\?Protocol.*/Protocol 2/' \
            -e 's/^#\?X11Forwarding.*/X11Forwarding no/' \
            /etc/ssh/sshd_config
sudo systemctl restart sshd

# TEST sur Windows :
ssh -i $env:USERPROFILE\.ssh\wakidaisho user@ip_serveur

EOS

elif [ "$PLATFORM" = "2" ]; then
    # Procédure Linux
    echo
    read -p "Nom du fichier de clé (ex : id_ed25519) : " KEYFILE
    [ -z "$KEYFILE" ] && KEYFILE="id_ed25519"
    echo "Suppression des anciennes clés locales..."
    rm -f ~/.ssh/${KEYFILE}*
    
    read -p "Passphrase pour la nouvelle clé : " PASSPH
    echo "Génération nouvelle clé SSH ED25519..."
    ssh-keygen -t ed25519 -f ~/.ssh/${KEYFILE} -N "$PASSPH"
    
    echo "Contenu de ta clé publique :"
    cat ~/.ssh/${KEYFILE}.pub
    
    echo
    echo "Réalise la suite sur le serveur distant dans ta session ouverte :"
    echo '
# Nettoyer/remplacer le dossier .ssh, puis ajouter la clé
rm -rf ~/.ssh
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Colle ta clé publique ci-dessus :
echo "COLLE_TA_CLÉ_PUBLIQUE_ICI" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chown -R $(whoami):$(whoami) ~/.ssh

# Sauvegarde et durcissement sshd_config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bck
sudo sed -i -e "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" \
            -e "s/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/" \
            -e "s/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/" \
            -e "s/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/" \
            -e "s/^#\?UsePAM.*/UsePAM yes/" \
            -e "s/^#\?Protocol.*/Protocol 2/" \
            -e "s/^#\?X11Forwarding.*/X11Forwarding no/" \
            /etc/ssh/sshd_config
sudo systemctl restart sshd

# TEST sur Linux :
ssh -i ~/.ssh/${KEYFILE} user@ip_serveur
    '
else
    echo "❌ Sélection invalide."
fi
