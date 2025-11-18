# 🔧 Trucs, Astuces et Dépannage - SSH Authentification par Clé

---

## 🚀 ASTUCES DE PRODUCTIVITÉ

### ⏱️ Connexion super rapide sans repasser la passphrase

Utilisez `ssh-agent` pour charger votre clé une fois et l'utiliser partout :

```bash
# Démarrer l'agent SSH (à faire au démarrage ou une fois par session)
eval $(ssh-agent)

# Ajouter votre clé
ssh-add ~/.ssh/id_ed25519
# Tapez la passphrase une seule fois
Enter passphrase for /home/admin/.ssh/id_ed25519: ••••••••••••

# À présent, connectez-vous sans passphrase !
ssh admin@serveur1
ssh admin@serveur2
ssh admin@serveur3
# ✅ Aucune demande de passphrase !
```

**Automatiser au démarrage (Linux/Mac) :**

```bash
# Ajouter ceci à ~/.bashrc ou ~/.zshrc
if [ -z "$SSH_AGENT_PID" ]; then
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519 2>/dev/null
fi
```

---

### 🎯 Configuration SSH client pour éviter de retaper les paramètres

Créer `~/.ssh/config` pour simplifier les connexions :

```bash
# Éditer le fichier
nano ~/.ssh/config

# Ajouter une entrée pour chaque serveur
Host serveur-prod
    HostName 203.0.113.50
    User admin
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes
    IdentitiesOnly yes
    
Host serveur-dev
    HostName 203.0.113.51
    User dev-user
    Port 2222
    IdentityFile ~/.ssh/id_dev_ed25519
    AddKeysToAgent yes
    IdentitiesOnly yes

Host *
    # Configuration par défaut pour tous les hosts
    ServerAliveInterval 60
    ServerAliveCountMax 3
    compression yes

# Sauvegarder et définir les permissions
chmod 600 ~/.ssh/config

# À présent, connexion simple :
ssh serveur-prod          # Au lieu de : ssh -i ~/.ssh/id_ed25519 admin@203.0.113.50
ssh serveur-dev           # Au lieu de : ssh -i ~/.ssh/id_dev_ed25519 -p 2222 dev-user@203.0.113.51
```

---

### 🔗 Tunnels SSH (Port Forwarding)

#### Forward Local Port (accéder à un service distant)

```bash
# Accéder à un service sur le serveur (ex: base de données MySQL sur port 3306)
ssh -L 3306:127.0.0.1:3306 admin@serveur

# À présent sur votre client, MySQL est accessible en local :
mysql -h 127.0.0.1 -u user -p

# Syntaxe : -L [port_local]:[adresse_serveur]:[port_serveur]
```

#### Reverse Port Forwarding (exposer un service local)

```bash
# Exposer un service local (ex: application sur port 8080)
ssh -R 8080:127.0.0.1:8080 admin@serveur

# À présent sur le serveur, votre app est accessible :
curl http://127.0.0.1:8080

# Syntaxe : -R [port_serveur]:[adresse_local]:[port_local]
```

---

### 📁 Transfert de fichiers avec SCP (Secure Copy)

```bash
# Copier un fichier vers le serveur
scp ~/monFichier.txt admin@serveur:~/

# Copier un fichier depuis le serveur
scp admin@serveur:~/fichier.txt ~/

# Copier un répertoire récursivement
scp -r ~/maApplication admin@serveur:~/

# Utiliser une clé spécifique
scp -i ~/.ssh/id_ed25519 ~/fichier.txt admin@serveur:~/

# Via la configuration ~/.ssh/config (simplifié)
scp ~/fichier.txt serveur-prod:~/
```

---

### 🔄 Synchronisation avec RSYNC

```bash
# Synchroniser un dossier local vers serveur
rsync -avz -e ssh ~/maApplication admin@serveur:~/

# Synchroniser depuis serveur vers local
rsync -avz -e ssh admin@serveur:~/applis/* ~/applis/

# Avec compression et exclusions
rsync -avz --exclude=".git" --exclude="node_modules" -e ssh ~/app admin@serveur:~/

# Options utiles :
# -a : archive (préserve permissions, timestamps, etc)
# -v : verbose
# -z : compression
# -e : protocole (ssh)
# --delete : supprime les fichiers supprimés localement aussi sur serveur
```

---

### 🔐 Plusieurs clés pour plusieurs projets

```bash
# Créer des clés séparées par contexte
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_travail_ed25519 -C "travail@2025"
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_github_ed25519 -C "github@2025"
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_critique_ed25519 -C "critique@2025"

# Configuration ~/.ssh/config pour utiliser les bonnes clés
Host travail-serveur
    HostName 203.0.113.50
    IdentityFile ~/.ssh/id_travail_ed25519

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_github_ed25519

Host serveur-critique
    HostName 203.0.113.99
    IdentityFile ~/.ssh/id_critique_ed25519
    # Ajouter une confirmation interactive pour ce serveur critique
    ConfirmUserID ask

# Ajouter plusieurs clés à l'agent (pour chaque session)
ssh-add ~/.ssh/id_travail_ed25519
ssh-add ~/.ssh/id_github_ed25519
ssh-add ~/.ssh/id_critique_ed25519
```

---

## 🐛 DÉPANNAGE : Les problèmes les plus courants

### ❌ "Permission denied (publickey)"

#### Diagnostic complet

```bash
# Mode verbose pour voir exactement où ça échoue
ssh -vvv admin@serveur

# Chercher dans la sortie :
# "Offering public key" = clé trouvée ✓
# "Server accepts key" = clé acceptée ✓
# "Trying password authentication" = clé rejetée ✗
```

#### Cause 1 : Fichier authorized_keys cassé

```bash
# Sur le SERVEUR, vérifier le format du fichier
cat ~/.ssh/authorized_keys | head -1

# ✅ Bon format :
# ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... admin@client

# ❌ Mauvais format :
# Ligne cassée/tronquée
# Caractères de contrôle
# Lignes vides

# Solution : Regénérer avec ssh-copy-id
ssh-copy-id -i ~/.ssh/id_ed25519.pub admin@serveur
```

#### Cause 2 : Permissions incorrectes

```bash
# Sur le SERVEUR, vérifier et corriger
ls -la ~/.ssh/

# ✅ Bon :
# drwx------ user user  .ssh
# -rw------- user user  authorized_keys

# ❌ Mauvais (exemple) :
# drwxr-xr-x user user  .ssh       ← Trop de permissions !
# -rw-r--r-- user user  authorized_keys  ← Lisible par d'autres !

# Corriger immédiatement
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys2  # Si existe
```

#### Cause 3 : Mauvaise clé utilisée

```bash
# Sur le CLIENT, vérifier quelle clé est utilisée
ssh -v admin@serveur 2>&1 | grep "Trying private key"
# Output: debug1: Trying private key: /home/user/.ssh/id_rsa
#         debug1: Trying private key: /home/user/.ssh/id_ed25519

# Spécifier une clé précise :
ssh -i ~/.ssh/id_ed25519 admin@serveur

# Ou dans ~/.ssh/config :
Host serveur
    HostName 203.0.113.50
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes  # ← Force JUSTE cette clé
```

#### Cause 4 : Problème de propriété

```bash
# Sur le SERVEUR, vérifier la propriété
ls -la ~/.ssh/authorized_keys

# Doit être : propriétaire:groupe
# ✅ admin:admin
# ❌ root:admin (mauvaise propriété)

# Corriger :
sudo chown admin:admin ~/.ssh/authorized_keys
sudo chown -R admin:admin ~/.ssh
```

---

### ❌ "Could not open connection to authentication agent"

```bash
# Problème : ssh-agent n'est pas lancé
# Solution : le lancer

eval $(ssh-agent)
ssh-add ~/.ssh/id_ed25519

# Vérifier que l'agent est actif :
echo $SSH_AGENT_PID
# Doit retourner un PID (numéro)

# Si vide, l'agent n'est pas lancé.
```

---

### ❌ "Connection refused"

```bash
# Problème : le serveur SSH n'écoute pas

# Sur le SERVEUR, vérifier
sudo systemctl status ssh
# Active: active (running) ?

# Si inactif, redémarrer
sudo systemctl start ssh
sudo systemctl enable ssh  # Pour démarrage auto

# Vérifier que SSH écoute
sudo netstat -tlnp | grep ssh
# ou
sudo ss -tlnp | grep ssh

# Output attendu :
# tcp    0    0 0.0.0.0:22    0.0.0.0:*    LISTEN    1234/sshd

# Si le port n'apparaît pas, chercher l'erreur dans les logs
sudo systemctl status ssh
sudo journalctl -u ssh -n 20
```

---

### ❌ "Authentications that can continue: password"

```bash
# Problème : PubkeyAuthentication est désactivé

# Sur le SERVEUR, éditer /etc/ssh/sshd_config
sudo nano /etc/ssh/sshd_config

# Vérifier la ligne :
# ✅ PubkeyAuthentication yes
# ❌ PubkeyAuthentication no (ou commentée avec #)
# ❌ #PubkeyAuthentication yes (commentée)

# Corriger si nécessaire
# Redémarrer
sudo systemctl restart ssh

# Tester
ssh admin@serveur
```

---

### ❌ "Received disconnect from X.X.X.X: Too many authentication failures"

```bash
# Problème : vous avez trop de clés et le serveur les rejette toutes

# Solution 1 : Forcer une clé précise
ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes admin@serveur

# Solution 2 : Dans ~/.ssh/config
Host serveur
    HostName 203.0.113.50
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

# Solution 3 : Nettoyer l'agent SSH (supprimer les vieilles clés)
ssh-add -l  # Lister les clés chargées
ssh-add -d ~/.ssh/vieille_cle  # Supprimer une clé
ssh-add -D  # Supprimer TOUTES les clés de l'agent
```

---

### ❌ "Host key verification failed"

```bash
# Problème : le serveur n'est pas connu (première connexion)

# Sortie :
# The authenticity of host '203.0.113.50' can't be established.
# ED25519 key fingerprint is SHA256:...
# Are you sure you want to continue connecting (yes/no)?

# Solution : Taper "yes" pour accepter

# Si vous voulez l'automatiser (à risque !) :
ssh -o "StrictHostKeyChecking=no" admin@serveur
# ⚠️ Déconseillé pour sécurité

# Vérifier manuellement l'empreinte du serveur
ssh-keyscan serveur 2>/dev/null | ssh-keygen -lf -
# Comparer avec l'empreinte attendue
```

---

## 🔐 SÉCURITÉ : Hardening avancé

### 🚫 Limiter les accès par clé sur le serveur

```bash
# Dans ~/.ssh/authorized_keys, ajouter des restrictions

# Exemple : permettre une commande spécifique uniquement
command="/usr/local/bin/backup.sh",no-port-forwarding,no-X11-forwarding ssh-ed25519 AAAAC3... admin@client

# Exemple : IP restrictions
from="192.168.1.100",no-port-forwarding ssh-ed25519 AAAAC3... admin@client

# Options les plus utiles :
# command="..." : exécuter UNE commande uniquement
# no-port-forwarding : interdire les tunnels
# no-X11-forwarding : interdire X11
# no-agent-forwarding : interdire agent forwarding
# no-pty : pas de pseudo-terminal
# from="IP" : autoriser depuis IP précise seulement
# environment="VAR=valeur" : définir des variables d'env
```

### 🔄 Rotation régulière des clés

```bash
# Script de rotation (à faire tous les 6-12 mois)
#!/bin/bash

# 1. Générer nouvelle clé
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519_new -N "passphrase"

# 2. Copier sur TOUS les serveurs
for server in serveur1 serveur2 serveur3; do
    ssh-copy-id -i ~/.ssh/id_ed25519_new.pub admin@$server
done

# 3. Tester avec nouvelle clé
ssh -i ~/.ssh/id_ed25519_new admin@serveur1

# 4. Supprimer l'ancienne (après confirmation)
rm ~/.ssh/id_ed25519
mv ~/.ssh/id_ed25519_new ~/.ssh/id_ed25519

# 5. Archiver l'ancienne (optionnel)
tar czf ~/.ssh/archive/id_ed25519_2024.tar.gz ~/.ssh/id_ed25519.old
```

---

## 🏥 AUDIT : Vérifier votre sécurité

### Audit client

```bash
# Lister les clés SSH présentes
ls -la ~/.ssh/

# Vérifier les permissions
# ~/.ssh/ = 700
# ~/.ssh/id_* = 600 (clés privées)
# ~/.ssh/*.pub = 644 (clés publiques)

# Voir quelle clé est chargée dans l'agent
ssh-add -l

# Vérifier la configuration SSH client
cat ~/.ssh/config | grep -E "Host|IdentityFile|Port"
```

### Audit serveur

```bash
# Sur le SERVEUR

# 1. Nombre d'accès autorisés
wc -l ~/.ssh/authorized_keys

# 2. Afficher qui a accès
cat ~/.ssh/authorized_keys | awk -F' ' '{print $(NF-1), $NF}'

# 3. Vérifier la configuration SSH
sudo sshd -T | grep -E "pubkey|password|root"

# 4. Vérifier les dernières connexions
last -n 20  # Connexions récentes

# 5. Audit des logs SSH
sudo grep "Accepted publickey" /var/log/auth.log | tail -20
sudo grep "Failed password" /var/log/auth.log | wc -l  # Nombre tentatives échouées

# 6. Ports SSH ouverts
sudo ss -tlnp | grep sshd
```

---

## 💡 TIPS & TRICKS

### Générer une clé très fort (paranoïa level)

```bash
# Clé Ed25519 avec 100 itérations (standard moderne sécurisé)
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519 -C "user@$(date +%Y-%m-%d)"

# Ou RSA 4096 avec 100 itérations (plus robuste légalement)
ssh-keygen -t rsa -b 4096 -o -a 100 -f ~/.ssh/id_rsa -C "user@$(date +%Y-%m-%d)"
```

### Tester sans se connecter (juste vérifier l'auth)

```bash
# Voir l'empreinte du serveur
ssh-keyscan 203.0.113.50 2>/dev/null | ssh-keygen -lf -

# Voir si la clé est acceptée (sans exécuter la connexion)
ssh -T admin@serveur
# Doit retourner quelque chose ou déconnecter tout seul
```

### Alias pour connexions fréquentes

```bash
# Dans ~/.bashrc ou ~/.zshrc
alias ssh-prod='ssh admin@203.0.113.50'
alias ssh-dev='ssh -i ~/.ssh/id_dev dev@203.0.113.51'
alias scp-prod='scp -r admin@203.0.113.50'

# À présent :
ssh-prod  # Connexion directe
scp-prod ~/fichier.txt:/home/admin/
```

### Monitoring des connexions SSH

```bash
# Alerter si quelqu'un se connecte
tail -f /var/log/auth.log | grep "Accepted publickey"

# Compter les tentatives échouées par IP
sudo awk '/Failed password/ {print $11}' /var/log/auth.log | sort | uniq -c | sort -rn

# Voir les connexions actuelles
w  # Ou who
```

---

## ✅ CHECKLIST DE SÉCURITÉ

- ☐ Clé privée protégée par passphrase
- ☐ Clé privée en permissions `600`
- ☐ Dossier `.ssh` en permissions `700`
- ☐ `authorized_keys` en permissions `600`
- ☐ Pas de clé root sur serveur (root ne peut pas se connecter en SSH)
- ☐ `PasswordAuthentication no` activé (après test !)
- ☐ `PubkeyAuthentication yes` activé
- ☐ `PermitRootLogin no` configuré
- ☐ Firewall autorise le port SSH
- ☐ Clés rotées régulièrement (annuellement)
- ☐ Audit des `authorized_keys` effectué
- ☐ ssh-agent utilisé pour les connexions fréquentes

---

**Dernière mise à jour : 16 novembre 2025**