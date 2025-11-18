# SSH par Clé - Trucs, Astuces et Dépannage
## Solutions Pratiques et Avancées

---

## 🛠️ Astuces Pratiques

### Alias SSH Rapides

```bash
# Ajouter à ~/.bashrc ou ~/.zshrc
alias ssh-prod='ssh admin@prod.exemple.com'
alias ssh-dev='ssh developer@dev.exemple.com'
alias ssh-list='ssh-add -l'
alias ssh-test='ssh -v localhost'
```

### SSH One-Liner Courants

```bash
# Copier un fichier du serveur
scp utilisateur@serveur:/path/fichier.txt ~/local/

# Copier récursivement
scp -r utilisateur@serveur:/remote/dir ~/local/

# Exécuter une commande sans shell interactif
ssh utilisateur@serveur 'ls -la /home' > local_output.txt

# Transférer via SSH compressé
ssh -C utilisateur@serveur 'tar czf - /dossier' | tar xzf -

# Tunnel local (port forwarding)
ssh -L 8080:localhost:80 utilisateur@serveur
# Puis naviguer vers http://localhost:8080

# Tunnel distant (reverse forwarding)
ssh -R 9090:localhost:3000 utilisateur@serveur

# Monter un répertoire distant via SSH (SSHFS)
sshfs utilisateur@serveur:/remote ~/mnt/remote
umount ~/mnt/remote  # Pour démonter

# Synchroniser fichiers bidirectionnels (rsync via SSH)
rsync -avz -e ssh utilisateur@serveur:/source/ ~/destination/

# Exécuter multiple commandes
ssh utilisateur@serveur << 'EOF'
cd /var/log
ls -la
tail -n 50 syslog
EOF

# Générer fingerprint du serveur en SSHv2 format
ssh-keyscan serveur.exemple.com 2>/dev/null | ssh-keygen -lf -
```

### Génération de Clés avec Commentaires Utiles

```bash
# Clé production
ssh-keygen -t ed25519 -f ~/.ssh/id_prod -C "prod-$(whoami)-$(hostname)-$(date +%Y%m%d)"

# Clé développement
ssh-keygen -t ed25519 -f ~/.ssh/id_dev -C "dev-$(whoami)-$(hostname)-$(date +%Y%m%d)"

# Clé personnelle
ssh-keygen -t ed25519 -f ~/.ssh/id_personal -C "$(whoami)@$(hostname)"

# Consulter tous les commentaires
for key in ~/.ssh/id_*; do
    [ -f "$key" ] && echo "$key:" && ssh-keygen -l -f "$key"
done
```

### Gestion Avancée de l'Agent SSH

```bash
# Démarrer l'agent avec une durée de vie limitée
ssh-agent -t 3600  # Expire après 1 heure

# Ajouter une clé avec timeout
ssh-add -t 1800 ~/.ssh/id_ed25519  # 30 minutes

# Vérifier la durée restante
ssh-add -l -E sha256

# Supprimer une clé spécifique
ssh-add -d ~/.ssh/id_ed25519

# Supprimer TOUTES les clés
ssh-add -D

# Ajouter les clés automatiquement (script)
#!/bin/bash
KEYS=~/.ssh/id_*
for key in $KEYS; do
    [ -f "$key" ] && ssh-add "$key" 2>/dev/null
done
```

### Configuration Multi-Serveurs Simplifiée

```
# ~/.ssh/config - Groupes logiques
Host production *
    User admin
    IdentityFile ~/.ssh/id_prod_ed25519
    IdentitiesOnly yes
    StrictHostKeyChecking yes

Host production web-*
    HostName %h.prod.exemple.com

Host production web-01
    HostName web01.prod.exemple.com

Host production web-02
    HostName web02.prod.exemple.com

Host development *
    User devuser
    IdentityFile ~/.ssh/id_dev_ed25519
    IdentitiesOnly yes

Host development dev-lab
    HostName 192.168.1.100
    Port 2222
```

Utilisation :
```bash
ssh web-01          # → admin@web01.prod.exemple.com
ssh web-02          # → admin@web02.prod.exemple.com
ssh dev-lab         # → devuser@192.168.1.100:2222
```

---

## 🔍 Dépannage Détaillé

### Problème 1 : "Permission denied (publickey)"

#### Diagnostic Complet

```bash
# 1. Vérifier que la clé existe
ls -la ~/.ssh/id_ed25519
# Doit exister avec permissions 600

# 2. Afficher la clé publique
cat ~/.ssh/id_ed25519.pub

# 3. Sur le serveur, vérifier authorized_keys
ssh utilisateur@serveur 'cat ~/.ssh/authorized_keys'

# 4. Vérifier permissions sur serveur
ssh utilisateur@serveur 'ls -la ~/.ssh/'
# Attendu :
# drwx------ .ssh
# -rw------- authorized_keys

# 5. Logs détaillés
ssh -vvv utilisateur@serveur 2>&1 | grep -A 5 "Authentications"

# 6. Sur serveur, vérifier logs
sudo tail -n 30 /var/log/auth.log | grep sshd

# 7. Vérifier empreinte de clé
ssh-keygen -l -f ~/.ssh/id_ed25519
# Comparer avec :
ssh -v utilisateur@serveur 2>&1 | grep "Offering key"
```

#### Solutions

```bash
# ✓ Copier la clé (nouvelle approche)
ssh-copy-id -i ~/.ssh/id_ed25519.pub utilisateur@serveur

# ✓ Ou manuel
cat ~/.ssh/id_ed25519.pub | ssh utilisateur@serveur 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'

# ✓ Corriger permissions
ssh utilisateur@serveur 'chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys'

# ✓ Vérifier le contenu (chercher de blancs indésirables)
ssh utilisateur@serveur 'cat ~/.ssh/authorized_keys | od -c | head -n 5'
```

### Problème 2 : SSH Demande le Mot de Passe au Lieu de Passphrase

#### Diagnostic

```bash
# 1. Vérifier PasswordAuthentication sur le serveur
ssh utilisateur@serveur 'sudo grep PasswordAuthentication /etc/ssh/sshd_config'

# 2. Vérifier que PubkeyAuthentication est enabled
ssh utilisateur@serveur 'sudo grep PubkeyAuthentication /etc/ssh/sshd_config'

# 3. Vérifier la configuration complète
sudo sshd -T | grep -E "pubkey|password"
```

#### Solution

```bash
# 1. Éditer sshd_config
sudo nano /etc/ssh/sshd_config

# 2. Insérer/modifier
PubkeyAuthentication yes
PasswordAuthentication no

# 3. Tester et redémarrer
sudo sshd -t
sudo systemctl restart ssh

# 4. Supprimer la clé de authorized_keys si vide
ssh utilisateur@serveur 'cat ~/.ssh/authorized_keys | wc -l'

# 5. Réimporter si nécessaire
ssh-copy-id -i ~/.ssh/id_ed25519.pub utilisateur@serveur
```

### Problème 3 : "Bad permissions on ~/.ssh"

#### Diagnostic

```bash
# Vérifier permissions exactes
ls -ld ~/.ssh/
stat -c "%A %a" ~/.ssh/

# Vérifier fichiers internes
ls -la ~/.ssh/
stat -c "%A %a" ~/.ssh/id_ed25519
```

#### Solution

```bash
# ✓ Corriger les permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
chmod 600 ~/.ssh/authorized_keys (sur serveur)
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/known_hosts

# ✓ Vérifier les droits du fichier sshd_config
sudo chmod 600 /etc/ssh/sshd_config
sudo chmod 600 /etc/ssh/sshd_config.d/*

# ✓ Script d'audit automatique
chmod_check() {
    for file in ~/.ssh/id_* ~/.ssh/config ~/.ssh/authorized_keys; do
        [ -f "$file" ] && chmod 600 "$file"
    done
    [ -d ~/.ssh ] && chmod 700 ~/.ssh
    echo "✓ Permissions SSH corrigées"
}
chmod_check
```

### Problème 4 : "Timeout Connection Refused"

#### Diagnostic

```bash
# 1. Vérifier que le serveur répond
ping serveur.exemple.com

# 2. Vérifier le port SSH
telnet serveur.exemple.com 22
# Attendu : Connected to ...

# 3. Ou avec nc (netcat)
nc -zv serveur.exemple.com 22
# Attendu : Connection successful

# 4. Vérifier SSH agent du serveur
ssh -v serveur.exemple.com
# Chercher : "Attempting to connect to"

# 5. Vérifier firewall local
sudo iptables -L -n | grep 22
sudo ufw status

# 6. Vérifier serveur (logs)
sudo tail -f /var/log/sshd.log
```

#### Solution

```bash
# ✓ Tester avec timeout
ssh -o ConnectTimeout=10 serveur.exemple.com

# ✓ Vérifier que SSH est activé sur serveur
sudo systemctl status ssh
sudo systemctl start ssh

# ✓ Ouvrir port firewall
sudo ufw allow 22/tcp
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --reload

# ✓ Utiliser port alternatif si 22 bloqué
ssh -p 2222 utilisateur@serveur
```

### Problème 5 : Clé Privée Protégée par Mot de Passe, SSH-Agent Ne Fonctionne Pas

#### Diagnostic

```bash
# 1. Vérifier que l'agent fonctionne
echo $SSH_AUTH_SOCK

# 2. Vérifier les clés en l'agent
ssh-add -l
# Résultat : "The agent has no identities" → Clés non chargées

# 3. Vérifier logs de l'agent
ps aux | grep ssh-agent
```

#### Solution

```bash
# ✓ Démarrer l'agent correctement
eval "$(ssh-agent -s)"

# ✓ Charger les clés
ssh-add ~/.ssh/id_ed25519
# Saisir passphrase

# ✓ Vérifier
ssh-add -l

# ✓ Automatiser (dans ~/.bashrc)
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
    ssh-add ~/.ssh/id_ed25519 2>/dev/null
fi
```

---

## 🔐 Améliorations de Sécurité

### Monitorage des Logins SSH

```bash
#!/bin/bash
# Script pour monitorer les connexions SSH réussies

echo "=== Connexions SSH Réussies (dernières 24h) ==="
sudo journalctl --since "24 hours ago" -u ssh SYSLOG_IDENTIFIER=sshd | \
    grep "Accepted publickey" | \
    awk '{print $1, $2, $3, $14, $15}' | \
    sort | uniq -c

echo ""
echo "=== Tentatives Échouées (dernières 24h) ==="
sudo journalctl --since "24 hours ago" -u ssh SYSLOG_IDENTIFIER=sshd | \
    grep "Failed password\|Invalid user" | \
    wc -l
```

### Ajouter Une Alerte sur Nouvelle Clé Importée

```bash
#!/bin/bash
# Script d'audit authorized_keys avec historique

AUTHKEYS="$HOME/.ssh/authorized_keys"
BACKUP_DIR="$HOME/.ssh/authorized_keys_backup"
mkdir -p "$BACKUP_DIR"

# Copier l'état actuel avec timestamp
cp "$AUTHKEYS" "$BACKUP_DIR/authorized_keys.$(date +%Y%m%d_%H%M%S)"

# Comparer avec dernière sauvegarde
LAST_BACKUP=$(ls -t "$BACKUP_DIR"/authorized_keys.* 2>/dev/null | head -n 2 | tail -n 1)

if [ -n "$LAST_BACKUP" ]; then
    if ! diff -q "$LAST_BACKUP" "$AUTHKEYS" > /dev/null; then
        echo "⚠️  ALERTE : authorized_keys modifié"
        echo "Changements :"
        diff "$LAST_BACKUP" "$AUTHKEYS"
    fi
fi
```

### SSH Hardening - Paramètres Avancés

```
# /etc/ssh/sshd_config - Configuration ultra-sécurisée

# 1. Clés d'hôte uniquement ED25519
HostKey /etc/ssh/ssh_host_ed25519_key

# 2. Authentification
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin no
PermitEmptyPasswords no

# 3. Chiffrement fort
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com

# 4. Timeouts
LoginGraceTime 15
ClientAliveInterval 300
ClientAliveCountMax 2

# 5. Limites
MaxAuthTries 2
MaxSessions 5
MaxStartups 10:30:60

# 6. Restriction utilisateurs
AllowUsers user1 user2 user3
DenyUsers root daemon bin

# 7. Logging avancé
LogLevel VERBOSE
SyslogFacility AUTH

# 8. Sécurité supplémentaire
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PermitUserEnvironment no
```

---

## 📊 Checklists Spécialisées

### Checklist Migration Complète (Ancien SSH → Nouveau SSH par Clé)

- [ ] Générer nouvelle paire ED25519
- [ ] Tester la connexion par clé sur serveur de test
- [ ] Importer la nouvelle clé sur ALL serveurs production
- [ ] Configurer sshd_config avec paramètres ANSSI
- [ ] Tester la connexion sur 5+ serveurs
- [ ] Vérifier les logs (`journalctl -u ssh`)
- [ ] Planifier date de suppression des mots de passe
- [ ] Former l'équipe sur ssh-add et SSH agent
- [ ] Archiver les anciennes clés
- [ ] Documenter les nouveaux processus

### Checklist Sécurité SSH Périodique (Mensuel)

- [ ] Vérifier permissions de ~/.ssh/ et fichiers
- [ ] Auditer authorized_keys (nombre de clés, commentaires)
- [ ] Chercher des tentatives échouées anormales (`tail /var/log/auth.log`)
- [ ] Vérifier la version d'OpenSSH (`ssh -V`)
- [ ] Tester que PasswordAuthentication est bien `no`
- [ ] S'assurer que PermitRootLogin est `no`
- [ ] Archiver les clés inutilisées depuis 6 mois
- [ ] Renouveler les clés si rotation annuelle nécessaire

---

## 💡 Tips & Tricks Avancés

### Générer QR Code SSH pour Mobile

```bash
# Créer un QR code représentant la clé publique (rarement utile)
# Plutôt utiliser : https://docs.github.com/en/authentication/connecting-to-github-with-ssh

# Pour copier clé publique sur clipboard
cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard
# Ou sur macOS :
cat ~/.ssh/id_ed25519.pub | pbcopy
```

### Batch Operations sur Plusieurs Serveurs

```bash
#!/bin/bash
# Exécuter commande sur X serveurs

SERVERS=("server1.com" "server2.com" "server3.com")
COMMAND="uptime && whoami"

for server in "${SERVERS[@]}"; do
    echo "=== $server ==="
    ssh "$server" "$COMMAND"
done
```

### Déboguer SSH Détection d'Hôte

```bash
# Verbose maximum
ssh -vvv utilisateur@serveur

# Vérifier les clés d'hôte acceptées
ssh-keyscan -t ed25519 serveur.exemple.com

# Consulter known_hosts
cat ~/.ssh/known_hosts | grep serveur.exemple.com

# Supprimer une entrée known_hosts
ssh-keygen -R serveur.exemple.com
```

### Performance SSH

```bash
# Mesurer le temps de connexion
time ssh utilisateur@serveur exit

# Utiliser multiplexing pour réutiliser connexions
# Ajouter à ~/.ssh/config :
Host *
    ControlMaster auto
    ControlPath ~/.ssh/control-%h-%p-%r
    ControlPersist 300

# Puis les reconnexions réutilisent la socket existante
```

---

**Document pratique - Mis à jour le 16 novembre 2025**
**Pour questions supplémentaires : Consulter Guide Complet**
