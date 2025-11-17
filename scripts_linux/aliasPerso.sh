#!/bin/bash
ZSHRC="$HOME/.zshrc"

# Corrige la ligne de thème. Si la ligne n'existe pas, l'ajoute.
if grep -q '^ZSH_THEME=' "$ZSHRC"; then
    sed -i 's|^ZSH_THEME="[^"]*"|ZSH_THEME="jonathan"|' "$ZSHRC"
else
    echo "ZSH_THEME=\"jonathan\"" >> "$ZSHRC"
fi

declare -A aliases=(
    ["cls"]="clear"
    ["update"]="sudo apt update -y && sudo apt upgrade -y"
    ["remove"]="sudo apt remove"
    ["autoremove"]="sudo apt autoremove"
    ["start"]="systemctl start"
    ["status"]="systemctl status"
    ["stop"]="systemctl stop"
    ["sus"]="sudo su"
    ["purg"]="sudo apt-get purge --auto-remove -y && sudo apt-get autoremove --purge -y"
)

# Fonction inst : installation rapide d'un paquet avec apt
function_inst='inst() {\n  sudo apt install "$1" -y\n}'

# Ajout des alias dans le .zshrc seulement s'ils n'existent pas déjà
for alias_name in "${!aliases[@]}"; do
    if ! grep -q "^alias $alias_name=" "$ZSHRC"; then
        echo "alias $alias_name='${aliases[$alias_name]}'" >> "$ZSHRC"
        echo "Alias $alias_name ajouté."
    else
        echo "Alias $alias_name déjà présent."
    fi
    done

# Ajout de la fonction inst si absente
grep -q '^inst()' "$ZSHRC" || {
    echo -e "\n$function_inst" >> "$ZSHRC"
    echo "Fonction inst ajoutée."
}
