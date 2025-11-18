<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# fait moi un cheat sheet en .md a télécharger

Ultra complet
avec des icones moderne

Voici un cheat sheet Git ultra complet au format Markdown avec des icônes modernes, prêt à télécharger et utiliser. Il couvre les commandes essentielles, le travail avec les branches, la gestion des remotes, l’authentification SSH, et plus encore.

***

# 🐙 Git Cheat Sheet Complet

## 🚀 Commandes de base

- `git init` : Initialiser un dépôt Git local
- `git clone <url>` : Cloner un dépôt distant
- `git status` : Voir l'état des fichiers
- `git add <fichier>` : Ajouter un fichier à l'index (stage)
- `git add .` : Ajouter tous les fichiers modifiés
- `git commit -m "message"` : Enregistrer les changements avec un message
- `git log` : Afficher l'historique des commits


## 🌿 Branches

- `git branch` : Lister les branches locales
- `git branch <nom>` : Créer une nouvelle branche
- `git checkout <branche>` : Se déplacer sur une branche
- `git checkout -b <branche>` : Créer et changer de branche en même temps
- `git branch -d <branche>` : Supprimer une branche locale
- `git merge <branche>` : Fusionner une branche dans la branche courante


## 🌍 Gestion des remotes

- `git remote -v` : Lister les remotes
- `git remote add origin <url>` : Ajouter un dépôt distant nommé origin
- `git remote set-url origin <url>` : Modifier l’URL du dépôt distant
- `git push origin <branche>` : Pousser la branche vers le dépôt distant
- `git pull origin <branche>` : Récupérer et fusionner depuis le dépôt distant


## 🔐 Authentification SSH (GitHub)

- Ajouter votre clé SSH publique sur GitHub : [GitHub > Settings > SSH and GPG keys]
- Démarrer l’agent SSH et ajouter la clé :

```
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
```

- Utiliser l’URL SSH pour le remote :

```
git remote set-url origin git@github.com:Utilisateur/Depot.git
```

- Tester la connexion SSH :

```
ssh -T git@github.com
```


## 🛠 Commandes avancées

- `git stash` : Sauvegarder temporairement les modifications locales
- `git stash apply` : Réappliquer les modifications stockées
- `git reset --hard <commit>` : Revenir à un commit précis en supprimant les changements
- `git revert <commit>` : Annuler un commit avec un nouveau commit inverse
- `git fetch` : Récupérer les modifications distantes sans fusion
- `git diff` : Voir les différences entre fichiers/local et index


## 📋 Autres

- `.gitignore` : Ignorer certains fichiers/dossiers dans le dépôt
- Git alias exemple dans `.gitconfig` :

```
[alias]
  s = status -s
  co = checkout
  br = branch
  cm = commit -m
```


***

# Icônes modernes utilisées

- 🐙 Git (logo symbolique)
- 🚀 Base / démarrage
- 🌿 Branches
- 🌍 Remotes / distant
- 🔐 Sécurité / SSH
- 🛠 Avancé / outils
- 📋 Divers / autres

***

Voulez-vous que je vous fournisse ce fichier au format `.md` prêt à télécharger à partir de ce document ?

Je peux aussi l’envoyer directement en contenu ici pour que vous puissiez le copier, ou générer un lien de téléchargement si nécessaire.
<span style="display:none">[^1][^10][^2][^3][^4][^5][^6][^7][^8][^9]</span>

<div align="center">⁂</div>

[^1]: https://github.com/adam-p/markdown-here/wiki/markdown-cheatsheet

[^2]: https://education.github.com/git-cheat-sheet-education.pdf

[^3]: https://gist.github.com/6faaaa1e2b181efdce1423fab4d18662

[^4]: https://gist.github.com/4461140

[^5]: https://www.geeksforgeeks.org/git/markdown-cheat-sheet-github/

[^6]: https://dev.to/aerabi/github-markdown-cheat-sheet-for-hacktoberfest-4j8g

[^7]: https://gist.github.com/akras14/3d242d80af8388ebca60

[^8]: https://javascript.plainenglish.io/github-markdown-cheat-sheet-everything-you-need-to-know-to-write-readme-md-ce40369da21f

[^9]: https://github.com/Sunil-Pradhan/git-cheat-sheet

[^10]: https://www.markdownguide.org/cheat-sheet/

