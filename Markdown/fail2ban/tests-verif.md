# Commandes de Vérification et Tests Post-Installation

## 📋 Tests Immédiats (À faire après l'exécution du script)

### 1️⃣ Vérifier que le script s'est bien exécuté

```bash
# Vérifier le statut du service SSH
systemctl status ssh

# Affichage attendu : active (running)
```

### 2️⃣ Vérifier que SSH écoute sur le port 2545

```bash
# Vérifier les ports d'écoute
sudo netstat -tlnp | grep ssh
# Ou avec ss (plus moderne)
sudo ss -tlnp | grep ssh

# Affichage attendu :
# tcp  0  0 0.0.0.0:2545  0.0.0.0:*  LISTEN  1234/sshd
```

### 3️⃣ Vérifier que fail2ban est actif

```bash
# Status de fail2ban
sudo systemctl status fail2ban

# Affichage attendu : active (running)

# Status détaillé
sudo fail2ban-client status

# Affichage attendu :
# Status
# |- Number of jail: 3
# `- Jail list: recidive, sshd, ...
```

### 4️⃣ Vérifier que la jail SSH est en place

```bash
# Status de la jail SSH
sudo fail2ban-client status sshd

# Affichage attendu :
# Status for the jail: sshd
# |- Filter
# |  |- Currently failed: 0
# |  `- Total failed: 0
# `- Actions
#    |- Currently banned: 0
#    `- Total banned: 0
```

### 5️⃣ Vérifier les fichiers de configuration

```bash
# Vérifier la syntaxe SSH
sudo sshd -t
# Doit retourner sans erreur (pas d'affichage)

# Vérifier la syntaxe fail2ban
sudo fail2ban-client -t
# Affichage attendu : Configuration appears to be OK.
```

### 6️⃣ Vérifier les règles iptables créées

```bash
# Voir les chaînes créées par fail2ban
sudo iptables -S | grep f2b

# Affichage attendu :
# -N f2b-sshd
# -A INPUT -p tcp -m multiport --dports 2545 -j f2b-sshd
# -A f2b-sshd -j RETURN

# Pour voir en détail
sudo iptables -L f2b-sshd -n
```

### 7️⃣ Vérifier les fichiers de configuration créés

```bash
# Vérifier que jail.local a été créé
ls -la /etc/fail2ban/jail.local

# Vérifier que sshd.local a été créé
ls -la /etc/fail2ban/jail.d/sshd.local

# Vérifier que recidive.local a été créé
ls -la /etc/fail2ban/jail.d/recidive.local

# Vérifier les sauvegardes
ls -la /etc/fail2ban/*.backup*
ls -la /etc/ssh/sshd_config.backup*
```

---

## 🔗 Tests de Connexion

### Depuis une autre machine

```bash
# Test 1 : Vérifier que SSH répond sur le port 2545
ssh -p 2545 -v user@votre-serveur

# Test 2 : Vérifier l'authentification par clé
ssh -p 2545 -i ~/.ssh/id_rsa user@votre-serveur

# Test 3 : Vérifier que le port 22 ne répond plus
ssh user@votre-serveur  # Devrait timeout ou connection refused
```

---

## 🧪 Test Fonctionnel de Fail2Ban

### Générer un ban volontaire (SANS vous bannir pour de bon !)

```bash
# Depuis une autre machine (pas votre IP de travail) :

# 1. Tenter 4 connexions échouées avec un mauvais password
for i in {1..4}; do
  echo "Tentative $i"
  ssh -p 2545 user@votre-serveur "wrong" 2>&1
  sleep 1
done

# 2. Attendre 5 secondes
sleep 5

# 3. Sur le serveur, vérifier que l'IP source est bannie
sudo fail2ban-client status sshd

# Affichage attendu :
# |- Currently banned: 1
# `- Banned IP list: 123.45.67.89
```

### ⚠️ Si vous êtes bloqué

```bash
# Sur le serveur, débannir votre IP
sudo fail2ban-client set sshd unbanip VOTRE_IP

# Exemple :
sudo fail2ban-client set sshd unbanip 203.0.113.50

# Vérifier que l'IP est débannie
sudo fail2ban-client status sshd
# "Banned IP list" ne doit plus contenir votre IP
```

---

## 📊 Monitoring et Logs

### Voir les logs en temps réel

```bash
# Logs de fail2ban (toutes les actions)
sudo tail -f /var/log/fail2ban.log

# Logs SSH (tentatives de connexion)
sudo tail -f /var/log/auth.log

# Affichage attendu pour fail2ban.log :
# 2025-11-16 10:15:30 fail2ban.filter [1234]: INFO    [sshd] Found 203.0.113.50
# 2025-11-16 10:15:35 fail2ban.actions [1234]: NOTICE  [sshd] Ban 203.0.113.50
```

### Voir tous les événements fail2ban

```bash
# Les 20 derniers événements
sudo tail -n 20 /var/log/fail2ban.log

# Chercher les bans
sudo grep "Ban " /var/log/fail2ban.log | tail -20

# Chercher les débans
sudo grep "Unban " /var/log/fail2ban.log | tail -20

# Chercher une IP spécifique
sudo grep "203.0.113.50" /var/log/fail2ban.log
```

---

## 🔧 Configuration : Vérifications Détaillées

### Vérifier la configuration SSH

```bash
# Voir le contenu de sshd_config
sudo cat /etc/ssh/sshd_config | grep -v "^#" | grep -v "^$"

# Vérifier les directives importantes :
echo "=== Port ==="
sudo grep "^Port" /etc/ssh/sshd_config

echo "=== PasswordAuthentication ==="
sudo grep "^PasswordAuthentication" /etc/ssh/sshd_config

echo "=== PubkeyAuthentication ==="
sudo grep "^PubkeyAuthentication" /etc/ssh/sshd_config

echo "=== MaxAuthTries ==="
sudo grep "^MaxAuthTries" /etc/ssh/sshd_config

echo "=== Ciphers ==="
sudo grep "^Ciphers" /etc/ssh/sshd_config

echo "=== MACs ==="
sudo grep "^MACs" /etc/ssh/sshd_config
```

### Vérifier la configuration fail2ban

```bash
# Voir la configuration générale
sudo cat /etc/fail2ban/jail.local | grep -v "^#" | grep -v "^$" | head -30

# Voir la configuration SSH
sudo cat /etc/fail2ban/jail.d/sshd.local | grep -v "^#" | grep -v "^$"

# Voir la configuration des récidivistes
sudo cat /etc/fail2ban/jail.d/recidive.local | grep -v "^#" | grep -v "^$"
```

---

## 🔐 Vérifications de Sécurité

### Vérifier l'authenticité des clés SSH

```bash
# Afficher la signature de la clé serveur SSH
sudo ssh-keygen -l -f /etc/ssh/ssh_host_rsa_key.pub

# Affichage attendu (fingerprint) :
# 2048 aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99 /etc/ssh/ssh_host_rsa_key.pub (RSA)
```

### Vérifier les permissions des fichiers

```bash
# Les permissions doivent être strictes
ls -la /etc/ssh/sshd_config
# Affichage attendu : -rw-r--r-- (600 ou 644)

ls -la /etc/ssh/ssh_host_rsa_key
# Affichage attendu : -rw------- (600)

ls -la /root/.ssh/authorized_keys
# Affichage attendu : -rw------- (600)
```

### Tester les algorithmes cryptographiques

```bash
# Voir quels ciphers sont acceptés
echo | openssl s_client -connect votre-serveur:2545 -cipher 'ALL' 2>/dev/null

# Ou avec ssh
ssh -p 2545 -Q cipher user@votre-serveur
```

---

## 🔄 Maintenance Courante

### Redémarrer SSH sans couper la connexion

```bash
# Méthode safe : reload (recharge la config sans killer les sessions)
sudo systemctl reload ssh

# Vérifier que SSH est toujours en cours d'exécution
systemctl status ssh
```

### Redémarrer fail2ban

```bash
# Redémarrer fail2ban (mais pas SSH)
sudo systemctl restart fail2ban

# Vérifier que fail2ban est revenu en ligne
sudo fail2ban-client status
```

### Vérifier la mise à jour des paquets

```bash
# Vérifier les mises à jour disponibles
apt list --upgradable | grep -E "fail2ban|openssh|iptables"

# Installer les mises à jour
sudo apt update && sudo apt upgrade -y
```

---

## ⚙️ Paramètres Modifiables Post-Installation

### Ajouter une IP à la whitelist

```bash
# Éditez le fichier
sudo nano /etc/fail2ban/jail.local

# Trouvez la ligne :
# ignoreip = 127.0.0.1/8 ::1

# Remplacez par :
# ignoreip = 127.0.0.1/8 ::1 203.0.113.50 203.0.113.51

# Appliquer les changements
sudo systemctl restart fail2ban
```

### Changer les paramètres de ban

```bash
# Éditer la configuration SSH
sudo nano /etc/fail2ban/jail.d/sshd.local

# Paramètres modifiables :
# bantime = 3600        → durée du ban (secondes)
# findtime = 600        → fenêtre de temps (secondes)
# maxretry = 3          → nombre de tentatives avant ban

# Exemples :
# bantime = 86400       # 24 heures au lieu de 1h
# maxretry = 5          # 5 tentatives au lieu de 3

# Appliquer les changements
sudo systemctl restart fail2ban
```

---

## 🆘 Diagnostic Avancé

### Déboguer les problèmes de connexion

```bash
# Vérifier que sshd démarre correctement
sudo sshd -D -d -p 2546 &
# Essayer de se connecter : ssh -p 2546 -v user@votre-serveur

# Voir les logs du kernel pour les modifications iptables
sudo journalctl -u fail2ban -n 50
sudo journalctl -u ssh -n 50

# Voir les détails de fail2ban
sudo fail2ban-client set sshd logpath /var/log/auth.log
sudo fail2ban-client status sshd verbose
```

### Restaurer une configuration antérieure

```bash
# Si quelque chose s'est mal passé, restaurer à partir des sauvegardes

# SSH
sudo cp /etc/ssh/sshd_config.backup-* /etc/ssh/sshd_config
sudo systemctl restart ssh

# Fail2ban
sudo cp /etc/fail2ban/jail.local.backup-* /etc/fail2ban/jail.local
sudo systemctl restart fail2ban
```

---

## 📈 Commandes de Monitoring Utiles

```bash
# Afficher toutes les IPs actuellement bannies
sudo fail2ban-client status | grep -A 100 "Jail list"

# Compter les bans par jour
sudo tail -n 1000 /var/log/fail2ban.log | grep "Ban " | cut -d' ' -f1 | sort | uniq -c

# Voir les IPs les plus souvent bannies
sudo tail -n 1000 /var/log/fail2ban.log | grep "Ban " | awk '{print $NF}' | sort | uniq -c | sort -rn

# Voir les tentatives SSH échouées
sudo tail -n 1000 /var/log/auth.log | grep "Failed password"

# Compter les tentatives par IP
sudo grep "Failed password" /var/log/auth.log | grep -oP '(\d+\.)+\d+' | sort | uniq -c | sort -rn
```

---

## ✅ Checklist de Validation Complète

```bash
# Exécutez cette checklist après l'installation

echo "=== Test 1 : SSH sur le port 2545 ==="
sudo netstat -tlnp | grep 2545 && echo "✓ SSH écoute sur 2545" || echo "✗ ERREUR"

echo "=== Test 2 : Fail2Ban actif ==="
systemctl is-active fail2ban > /dev/null && echo "✓ Fail2Ban actif" || echo "✗ ERREUR"

echo "=== Test 3 : Syntaxe SSH ==="
sudo sshd -t && echo "✓ SSH config OK" || echo "✗ ERREUR"

echo "=== Test 4 : Syntaxe Fail2Ban ==="
sudo fail2ban-client -t 2>&1 | grep -q "OK" && echo "✓ Fail2Ban config OK" || echo "✗ ERREUR"

echo "=== Test 5 : Jail SSH en place ==="
sudo fail2ban-client status sshd > /dev/null && echo "✓ Jail SSH active" || echo "✗ ERREUR"

echo "=== Test 6 : Règles iptables ==="
sudo iptables -S | grep -q "f2b-sshd" && echo "✓ Règles iptables OK" || echo "✗ ERREUR"

echo "=== Test 7 : Fichiers de config ==="
[ -f /etc/fail2ban/jail.d/sshd.local ] && echo "✓ Config SSH OK" || echo "✗ ERREUR"

echo ""
echo "Checklist complète !"
```

