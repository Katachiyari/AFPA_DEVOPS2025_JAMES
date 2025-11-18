# 🚀 Quick Reference - Aide-Mémoire Rapide

## ⚡ Exécution du Script (30 secondes)

```bash
# 1. Télécharger le script
sudo wget -O /tmp/fail2ban-install.sh https://votre-serveur/fail2ban-install.sh

# 2. Rendre exécutable
chmod +x /tmp/fail2ban-install.sh

# 3. Exécuter
sudo bash /tmp/fail2ban-install.sh

# 4. Suivre les messages d'installation
# Output :
# [INFO] Démarrage du script d'installation fail2ban
# [SUCCÈS] Script exécuté en tant que root
# ...
# [SUCCÈS] Installation et configuration de fail2ban terminées !
```

---

## 🔗 Tests Rapides (2 minutes)

```bash
# Test 1 : SSH répond sur 2545 ?
ssh -p 2545 user@votre-serveur

# Test 2 : Fail2ban actif ?
sudo fail2ban-client status

# Test 3 : Port 22 fermé ?
ssh user@votre-serveur  # Timeout attendu

# Test 4 : Syntaxe SSH OK ?
sudo sshd -t

# Test 5 : Syntaxe Fail2ban OK ?
sudo fail2ban-client -t
```

---

## 📋 Commandes Essentielles

### Status et Monitoring

| Commande | Résultat |
|----------|----------|
| `sudo fail2ban-client status` | Status global |
| `sudo fail2ban-client status sshd` | Status jail SSH |
| `sudo tail -f /var/log/fail2ban.log` | Logs en temps réel |
| `sudo iptables -S \| grep f2b` | Règles iptables |
| `sudo netstat -tlnp \| grep 2545` | Port d'écoute SSH |

### Gestion des IPs

| Commande | Action |
|----------|--------|
| `sudo fail2ban-client set sshd unbanip 203.0.113.50` | Débannir une IP |
| `sudo fail2ban-client status sshd \| grep "Banned IP"` | Lister les IPs bannies |
| `sudo sed -i 's/ignoreip.*/ignoreip = 127.0.0.1\/8 ::1 203.0.113.50/' /etc/fail2ban/jail.local` | Whitelister une IP |

### Redémarrage

| Commande | Action |
|----------|--------|
| `sudo systemctl restart ssh` | Redémarrer SSH |
| `sudo systemctl restart fail2ban` | Redémarrer fail2ban |
| `sudo systemctl reload ssh` | Recharger SSH (safe) |

---

## 📁 Fichiers Importants

```
/etc/ssh/sshd_config                    ← Configuration SSH
/etc/ssh/sshd_config.backup-*           ← Sauvegarde SSH
/etc/fail2ban/jail.local                ← Config générale fail2ban
/etc/fail2ban/jail.d/sshd.local         ← Config SSH fail2ban
/etc/fail2ban/jail.d/recidive.local     ← Config récidivistes

/var/log/auth.log                       ← Logs SSH
/var/log/fail2ban.log                   ← Logs fail2ban
```

---

## ⚙️ Modifications Courantes Post-Installation

### 1. Changer le port SSH

```bash
# Éditer
sudo nano /etc/ssh/sshd_config

# Trouver et changer :
# Port 2545  →  Port 2022

# Appliquer
sudo systemctl restart ssh
```

### 2. Changer le nombre de tentatives avant ban

```bash
# Éditer
sudo nano /etc/fail2ban/jail.d/sshd.local

# Changer :
# maxretry = 3  →  maxretry = 5  (moins strict)
# maxretry = 3  →  maxretry = 2  (plus strict)

# Appliquer
sudo systemctl restart fail2ban
```

### 3. Augmenter la durée du ban

```bash
# Éditer
sudo nano /etc/fail2ban/jail.d/sshd.local

# Changer :
# bantime = 3600  →  bantime = 86400  (24 heures)

# Appliquer
sudo systemctl restart fail2ban
```

### 4. Whitelister une IP

```bash
# Éditer
sudo nano /etc/fail2ban/jail.local

# Changer la ligne [DEFAULT] :
# ignoreip = 127.0.0.1/8 ::1  
# ignoreip = 127.0.0.1/8 ::1 203.0.113.50  (ajouter votre IP)

# Appliquer
sudo systemctl restart fail2ban
```

### 5. Débannir une IP manuellement

```bash
# Débannir immédiatement
sudo fail2ban-client set sshd unbanip 203.0.113.50

# Ou arrêter fail2ban temporairement
sudo systemctl stop fail2ban
```

---

## 🔐 Vérifications de Sécurité

```bash
# Vérifier que le password auth est bien désactivé
sudo grep "PasswordAuthentication no" /etc/ssh/sshd_config

# Vérifier que la clé publique auth est bien forcée
sudo grep "PubkeyAuthentication yes" /etc/ssh/sshd_config

# Vérifier que le port a changé
sudo grep "^Port" /etc/ssh/sshd_config

# Vérifier les ciphers ANSSI
sudo grep "^Ciphers" /etc/ssh/sshd_config

# Vérifier les MACs ANSSI
sudo grep "^MACs" /etc/ssh/sshd_config
```

---

## 🆘 Problèmes Rapides

### "Connection refused" sur le port 2545

```bash
# SSH n'est pas sur le port 2545

# Vérifier :
sudo netstat -tlnp | grep ssh

# Si port 22 : SSH n'a pas redémarré
sudo systemctl restart ssh

# Si erreur syntax SSH :
sudo sshd -t
```

### "Permission denied (publickey)"

```bash
# Votre clé publique n'est pas sur le serveur

# Sur votre machine :
ssh-copy-id -p 2545 user@votre-serveur

# Ou manuellement :
cat ~/.ssh/id_rsa.pub | ssh -p 2545 user@votre-serveur \
  "mkdir -p .ssh && cat >> .ssh/authorized_keys"
```

### "Vous êtes banni"

```bash
# Vous avez trop de tentatives échouées

# Via console physique :
sudo fail2ban-client set sshd unbanip VOTRE_IP

# Ou arrêter fail2ban :
sudo systemctl stop fail2ban
```

### "Fail2ban ne démarre pas"

```bash
# Vérifier la syntaxe
sudo fail2ban-client -t

# Voir les erreurs
sudo journalctl -u fail2ban -n 20

# Forcer redémarrage
sudo systemctl restart fail2ban
```

---

## 📊 Monitoring Rapide

### Voir les IPs actuellement bannies

```bash
sudo fail2ban-client status sshd | grep "Banned IP"
```

### Voir les bans du jour

```bash
sudo grep "$(date +%Y-%m-%d)" /var/log/fail2ban.log | grep "Ban"
```

### Voir les IPs les plus souvent bannies

```bash
sudo grep "Ban " /var/log/fail2ban.log | \
  awk '{print $NF}' | sort | uniq -c | sort -rn | head -10
```

### Voir les tentatives SSH échouées

```bash
sudo tail -100 /var/log/auth.log | grep "Failed password"
```

---

## ✅ Checklist Après Installation

- [ ] SSH responsive sur le port 2545
- [ ] SSH ne répond plus sur le port 22
- [ ] Fail2ban actif : `sudo systemctl status fail2ban`
- [ ] Jail SSH en place : `sudo fail2ban-client status sshd`
- [ ] Pas d'erreur SSH : `sudo sshd -t`
- [ ] Pas d'erreur fail2ban : `sudo fail2ban-client -t`
- [ ] Vous n'êtes pas banni vous-même
- [ ] IP whitelist configurée (optionnel mais recommandé)

---

## 🎯 3 Étapes pour Être Opérationnel

### Étape 1 : Installer
```bash
sudo bash fail2ban-install.sh
```

### Étape 2 : Tester
```bash
ssh -p 2545 user@votre-serveur  # Doit fonctionner
sudo fail2ban-client status      # Doit être actif
```

### Étape 3 : Configurer (optionnel)
```bash
# Whitelist votre IP
sudo nano /etc/fail2ban/jail.local
# Modifier ignoreip avec votre IP publique
# Redémarrer fail2ban
sudo systemctl restart fail2ban
```

---

## 💾 Sauvegarde Rapide

```bash
# Avant de modifier
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup-$(date +%Y%m%d)
sudo cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.backup-$(date +%Y%m%d)

# Restore rapide
sudo cp /etc/ssh/sshd_config.backup-DATE /etc/ssh/sshd_config
sudo systemctl restart ssh
```

---

## 🔍 Debugging Rapide

```bash
# Voir TOUS les events de fail2ban
sudo tail -100 /var/log/fail2ban.log

# Voir TOUS les events SSH
sudo tail -100 /var/log/auth.log

# Tester SSH en debug
ssh -p 2545 -v user@votre-serveur

# Tester sshd en debug (port différent)
sudo sshd -D -d -p 2546 &

# Voir iptables détaillé
sudo iptables -L f2b-sshd -v -n
```

---

## 🎓 Ressources

| Ressource | URL |
|-----------|-----|
| ANSSI OpenSSH | https://cyber.gouv.fr |
| Fail2Ban | https://www.fail2ban.org/ |
| Ubuntu SSH | https://ubuntu.com/server/docs/service-openssh |

---

## ⏱️ Temps Estimés

| Tâche | Temps |
|-------|-------|
| Exécuter le script | 2-3 minutes |
| Tests basiques | 1 minute |
| Configuration avancée | 5-10 minutes |
| Debugging | Variable |

---

## 🚨 À FAIRE EN PRIORITÉ

1. ✅ Exécuter le script
2. ✅ Tester la connexion SSH sur port 2545
3. ✅ Vérifier que fail2ban est actif
4. ⚠️ **NE PAS FERMER VOTRE ACCÈS ACTUEL** si vous testez
5. ✅ Whitelister votre IP pour éviter un ban accidentel

