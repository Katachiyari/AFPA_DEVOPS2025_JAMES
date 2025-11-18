# Git Cheat Sheet - Mode Expert : Ultra Complet

## Commandes de Base

- :sparkles: `git init` : Initialise un dépôt Git local
- :arrow_down: `git clone <url>` : Clone un dépôt distant
- :memo: `git status` : Affiche l'état du dépôt
- :pencil2: `git add <fichier>` : Ajoute un fichier à l'index
- :fire: `git rm <fichier>` : Supprime un fichier et l'ajoute à l'index
- :package: `git commit -m "message"` : Valide les changements
- :rocket: `git push` : Envoie les changements au dépôt distant
- :mag: `git pull` : Récupère et fusionne les changements distants

## Branches

- :branch: `git branch` : Liste les branches locales
- :sparkler: `git branch <nom>` : Crée une nouvelle branche
- :recycle: `git checkout <branche>` : Change de branche
- :twisted_rightwards_arrows: `git merge <branche>` : Fusionne une branche dans la branche courante
- :boom: `git branch -d <branche>` : Supprime une branche locale

## Logs & Historique

- :notebook: `git log` : Affiche l'historique des commits
- :point_left: `git log --oneline` : Historique simplifié
- :repeat: `git revert <commit>` : Annule un commit en créant un nouveau commit

## Réinitialisation & Nettoyage

- :rewind: `git reset <commit>` : Réinitialise la tête de la branche
- :broom: `git clean -f` : Supprime les fichiers non suivis

## Rebase & Cherry-pick

- :arrows_clockwise: `git rebase <branche>` : Rebase la branche courante
- :cherry_blossom: `git cherry-pick <commit>` : Applique un commit spécifique

## Configuration

- :gear: `git config --global user.name "Nom"`
- :gear: `git config --global user.email "email@exemple.com"`
- :key: `git config --global core.sshCommand "ssh -i ~/.ssh/id_rsa"

## Astuces avancées

- :zap: `git stash` : Sauvegarde les modifications en cours
- :zap: `git stash pop` : Récupère la dernière sauvegarde
- :spy: `git bisect start` : Recherche binaire d'un bug
- :bulb: `git tag <nom>` : Crée un tag pour marquer une version

## Résolution des Conflits

- :collision: `git mergetool` : Lance un outil de fusion
- :crossed_swords: Résoudre manuellement dans les fichiers puis :
  - `git add <fichier>`
  - `git commit`

