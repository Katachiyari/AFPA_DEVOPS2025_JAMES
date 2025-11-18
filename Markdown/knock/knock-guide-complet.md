# 🚪 Guide Complet : Port Knocking avec Knock

## 🎯 Qu'est-ce que le Port Knocking ?

**Port Knocking** = "Frapper à la porte" du serveur avec une séquence secrète

### Concept Simple

```
Avant Port Knocking :
┌──────────────────────────────────────┐
│  SSH sur port 2545 : TOUJOURS OUVERT │
│  ↓ Attaquants peuvent le scanner     │
│  ↓ Visible au premier coup d'œil     │
└──────────────────────────────────────┘

Avec Port Knocking :
┌──────────────────────────────────────────────────┐
│  SSH sur port 2545 : TOUJOURS FERMÉ              │
│  ↓ Pour l'ouvrir, frapper les ports :            │
│    Coup 1 : Port 7000                            │
│    Coup 2 : Port 8000                            │
│    Coup 3 : Port 9000                            │
│  ↓ Seule votre IP peut se connecter              │
│  ↓ Le port se referme automatiquement            │
└──────────────────────────────────────────────────┘
```

### Comment ça marche Techniquement

```
Étape 1 : Vous envoyer les coups
Your Machine → knock server.com 7000 8000 9000
                       ↓
              Serveur reçoit les paquets
              knockd les détecte
                       ↓
Étape 2 : knockd vérifie la séquence
         7000 ✓ → 8000 ✓ → 9000 ✓
         Séquence correcte !
                       ↓
Étape 3 : knockd exécute une commande iptables
         iptables -I INPUT 1 -s YOUR_IP -p tcp --dport 2545 -j ACCEPT
         "Ouvrir le port 2545 SEULEMENT pour cette IP"
                       ↓
Étape 4 : Vous pouvez vous connecter à SSH
         ssh -p 2545 user@server.com
         Fonctionne ! ✓
                       ↓
Étape 5 : Après 30 secondes (timeout)
         iptables -D INPUT -s YOUR_IP -p tcp --dport 2545 -j ACCEPT
         "Fermer le port 2545 pour cette IP"
         Port se referme automatiquement
```

---

## ⚡ Utilisation Rapide (10 minutes)

### Sur le SERVEUR

```bash
# 1. Télécharger/créer le script
sudo nano /opt/scripts/knock-install.sh
# Coller le contenu du script [53]

# 2. Rendre exécutable
sudo chmod +x /opt/scripts/knock-install.sh

# 3. Exécuter
sudo bash /opt/scripts/knock-install.sh

# 4. Attendre la fin (2-3 minutes)
# Le script va :
#   - Installer knockd
#   - Configurer la séquence
#   - Démarrer le service
#   - Bloquer SSH par iptables
```

### Sur votre MACHINE CLIENT

```bash
# 1. Installer le client knock
sudo apt-get install knockd -y

# 2. Frapper à la porte (ouvrir SSH)
knock server.com 7000 8000 9000

# 3. Vous connecter à SSH (rapidement !)
ssh -p 2545 user@server.com

# 4. Vous avez 30 secondes pour vous connecter
# Après, le port se referme automatiquement
```

---

## 🔑 Concepts Clés

### Séquence de Coups (Knock Sequence)

La "séquence" est votre mot de passe pour accéder à SSH.

```bash
# Format standard :
7000,8000,9000

# Format avec protocole explicite :
7000:tcp,8000:tcp,9000:tcp

# Exemple avec UDP (rare) :
7000:tcp,8000:udp,9000:tcp

# Importance :
- C'est votre "clé secrète"
- Ne partagez pas cette séquence
- Changez-la du défaut (7000,8000,9000)
- Utilisez des numéros aléatoires
- JAMAIS des ports communs (22, 80, 443)
```

### Délais Importants

| Paramètre | Valeur | Signification |
|-----------|--------|---------------|
| `seq_timeout` | 5 sec | Temps entre chaque coup de la séquence |
| `command_timeout` | 30 sec | Durée d'ouverture du port SSH |

```
Exemple :
- Vous frappez le port 7000
- Vous DEVEZ frapper le port 8000 dans les 5 secondes
- Si vous ne frappez pas → séquence réinitialisée
- Si vous frappez correctement → port 9000 dans les 5 secondes
- Tous les coups corrects → SSH ouvert pendant 30 secondes
- Après 30 sec → SSH se referme automatiquement
```

---

## 🛠️ Configuration Détaillée

### Fichier de Configuration : `/etc/knockd.conf`

```ini
[options]
# Paramètres globaux
logpath = /var/log/knockd.log
loglevel = 3
UseSyslog

[openSSH]
# Section pour OUVRIR le port SSH
sequence = 7000,8000,9000          # Séquence secrète
seq_timeout = 5                    # Délai entre les coups
command = /sbin/iptables -I INPUT 1 -s %IP% -p tcp --dport 2545 -j ACCEPT
# %IP% = remplacé par votre IP
# --dport 2545 = port SSH

tcpflags = syn

[closeSSH]
# Section OPTIONNELLE pour FERMER SSH
sequence = 9000,8000,7000         # Séquence inversée
seq_timeout = 5
command = /sbin/iptables -D INPUT -s %IP% -p tcp --dport 2545 -j ACCEPT
tcpflags = syn
```

### Fichier de Démarrage : `/etc/default/knockd`

```bash
# Démarrage automatique
START_KNOCKD=1

# Interface à surveiller
KNOCKD_OPTS="-i ens0"
```

---

## 🔒 Combinaison avec Fail2Ban

**Pour une sécurité MAXIMALE**, combinez knock + fail2ban :

```
Couche 1 : Port Knocking (knock)
  → SSH est invisible/fermé par défaut
  → Seule la bonne séquence l'ouvre
  → "Sécurité par l'obscurité"

Couche 2 : Protection Brute-Force (fail2ban)
  → Même après les coups, ssh est protégé
  → Si 3 mauvais mots de passe → ban pour 1 heure
  → Protection contre les attaques directes

Résultat :
  Attaquant 1 : Essaie SSH directement → port fermé ✗
  Attaquant 2 : Découvre la séquence, essaie 100 mots de passe → banni ✗
  Vous : Tapez la séquence, connectez avec votre clé → OK ✓
```

---

## 📋 Workflow Complet

### Initialisation (Une fois)

```bash
# 1. Sur le serveur
sudo bash /opt/scripts/knock-install.sh

# 2. Sur votre machine
sudo apt-get install knockd -y

# 3. Tester la séquence
knock <IP_SERVEUR> 7000 8000 9000

# 4. Vérifier
sudo fail2ban-client status sshd  # Sur le serveur
ssh -p 2545 user@server          # Depuis votre machine
```

### Utilisation Quotidienne

```bash
# À chaque fois que vous voulez accéder à SSH :

# 1. Frapper à la porte
knock <IP_SERVEUR> 7000 8000 9000

# 2. Vous connecter rapidement (< 30 sec)
ssh -p 2545 user@server

# 3. C'est tout !
# Le port se referme automatiquement après 30 secondes
```

---

## 🔍 Vérification et Monitoring

### Voir les Logs de Knock

```bash
# Sur le serveur :

# Logs en temps réel
sudo tail -f /var/log/knockd.log

# Logs récents
sudo cat /var/log/knockd.log

# Voir les coups reçus
sudo grep "decode" /var/log/knockd.log | tail -10

# Voir les actions exécutées
sudo grep "running" /var/log/knockd.log | tail -10
```

### Vérifier les Règles IPTables

```bash
# Voir les règles créées par knock
sudo iptables -L INPUT -n -v

# Voir seulement les règles d'acceptation
sudo iptables -L INPUT -n | grep ACCEPT

# Voir seulement le port 2545
sudo iptables -L INPUT -n | grep 2545
```

### Statut du Service

```bash
# Vérifier que knockd tourne
sudo systemctl status knockd

# Voir les logs système
sudo journalctl -u knockd -n 20

# Redémarrer knockd
sudo systemctl restart knockd
```

---

## 🧪 Tests Pratiques

### Test 1 : Vérifier que SSH est Fermé

```bash
# De votre machine locale
ssh -p 2545 user@server

# Affichage attendu :
# ssh: connect to host server port 2545: Connection refused
# OU Connection timed out
# C'est normal ! Le port est fermé.
```

### Test 2 : Frapper la Porte

```bash
# De votre machine locale
knock server 7000 8000 9000

# Output :
# (rien, c'est normal)

# Attendre 1 seconde
sleep 1

# Vérifier sur le serveur
sudo tail -f /var/log/knockd.log
# Vous devriez voir les coups reçus
```

### Test 3 : Se Connecter Après les Coups

```bash
# De votre machine locale

# Frapper
knock server 7000 8000 9000

# Immédiatement se connecter (< 30 sec)
ssh -p 2545 user@server

# Affichage attendu :
# user@server's password: (ou demande de clé)
# Fonctionne ! ✓
```

### Test 4 : Le Port se Referme

```bash
# De votre machine locale

# Frapper
knock server 7000 8000 9000

# Attendre 31 secondes (plus que le timeout)
sleep 31

# Essayer de se connecter
ssh -p 2545 user@server

# Affichage attendu :
# Connection refused
# Le port est refermé !
```

---

## 🚨 Troubleshooting

### Problème : "Connection refused" même après les coups

```bash
# Causes possibles :

# 1. knockd n'a pas démarré
sudo systemctl status knockd

# 2. La séquence envoyée ne correspond pas
knock server 7000 8000 9000  # Vérifier la séquence

# 3. Interface réseau mal configurée
sudo grep "KNOCKD_OPTS" /etc/default/knockd

# 4. Vérifier les logs
sudo tail -f /var/log/knockd.log

# 5. Redémarrer knockd
sudo systemctl restart knockd
```

### Problème : "Knocked" mais SSH toujours refusé

```bash
# Causes possibles :

# 1. SSH n'est pas en écoute sur le port 2545
sudo netstat -tlnp | grep 2545

# 2. iptables a un DROP avant la règle knock
sudo iptables -L INPUT -n -v

# 3. SSH n'a pas redémarré après fail2ban
sudo systemctl restart ssh

# 4. Vérifier la syntaxe de la règle iptables
sudo iptables -L INPUT -n | grep 2545
```

### Problème : knockd refuse de démarrer

```bash
# Vérifier les erreurs
sudo systemctl status knockd

# Voir les logs détaillés
sudo journalctl -u knockd -n 50

# Vérifier la syntaxe knockd.conf
sudo knockd -c /etc/knockd.conf -d -v

# Vérifier l'interface réseau
ip link show

# Corriger dans /etc/default/knockd
sudo nano /etc/default/knockd
# KNOCKD_OPTS="-i ens0"  (adapter le nom de l'interface)
```

---

## 🔐 Bonnes Pratiques de Sécurité

### ✅ À FAIRE

| À FAIRE | Raison |
|---------|--------|
| Changer la séquence par défaut | La séquence par défaut est connue |
| Utiliser des ports aléatoires | Moins prédictible |
| Ne jamais utiliser des ports communs | 22, 80, 443 sont trop visibles |
| Combiner avec fail2ban | Couches multiples de sécurité |
| Garder la séquence secrète | C'est votre "mot de passe" |
| Tester régulièrement | Assurer que ça marche |
| Monitorer les logs | Détecter les tentatives |

### ❌ À NE PAS FAIRE

| À NE PAS FAIRE | Raison |
|---|---|
| Partager votre séquence | Quelqu'un pourrait ouvrir SSH |
| Utiliser une séquence facile | (1,2,3,4 ou 1000,2000,3000) |
| Désactiver iptables DROP | Retour au port ouvert |
| Ne pas tester la configuration | Vous pourriez être bloqué |
| Oublier le client knock | Vous ne pouvez pas frapper |
| Utiliser knock SEUL | Plus de sécurité avec fail2ban |

---

## 🎓 Concepts Avancés

### Timeout Variable

```bash
# Paramètres de timeout dans knockd.conf

[openSSH]
sequence = 7000,8000,9000
seq_timeout = 5           # Temps ENTRE les coups

# Exemple :
# 13:45:00 - Coup 1 (7000)
# 13:45:02 - Coup 2 (8000)  ← doit être dans 5 sec ✓
# 13:45:04 - Coup 3 (9000)  ← doit être dans 5 sec ✓
# SSH ouvert ✓
```

### Commandes Personnalisées

```bash
# Vous pouvez ajouter des actions personnalisées

[openSSH]
sequence = 7000,8000,9000
command = /sbin/iptables -I INPUT 1 -s %IP% -p tcp --dport 2545 -j ACCEPT

# Ajouter une notification :
start_command = /usr/bin/logger "SSH ouvert pour %IP%"

# Ou un email :
start_command = echo "SSH ouvert pour %IP%" | mail -s "Knock" admin@example.com
```

---

## 🔗 Intégration avec d'autres Services

### Combiner avec VPN

```bash
# Si vous utilisez un VPN :

# 1. VPN se connecte (change votre IP)
# 2. Envoyer les coups depuis le VPN
knock <server> 7000 8000 9000

# 3. SSH se connecte (votre IP VPN est whitelistée)
ssh -p 2545 user@server
```

### Combiner avec Bastion/Jump Host

```bash
# Si vous passez par un serveur intermédiaire :

# 1. Knock sur le serveur distant
knock <bastion> 7000 8000 9000

# 2. SSH au serveur destination via le bastion
ssh -J user@bastion user@destination -p 2545
```

---

## 📊 Comparaison : Avec vs Sans Knock

| Aspect | Sans Knock | Avec Knock |
|--------|-----------|-----------|
| Port SSH visible | ✓ Oui | ✗ Non (caché) |
| Scans de port détectent SSH | ✓ Oui | ✗ Non |
| Attaques directes possibles | ✓ Oui | ✗ Non (port fermé) |
| Sécurité par obscurité | ✗ Non | ✓ Oui |
| Combinable avec fail2ban | ✓ Oui | ✓ Oui (meilleur !) |
| Complexité | ✗ Simple | ✓ Modérée |

---

## 📌 Checklist Complète

### Installation
- [ ] Script knock exécuté
- [ ] knockd actif : `sudo systemctl status knockd`
- [ ] SSH bloqué par iptables
- [ ] Fichier knockd.conf configuré

### Client
- [ ] knockd installé : `sudo apt-get install knockd -y`
- [ ] Séquence testée : `knock <server> 7000 8000 9000`
- [ ] SSH fonctionnel après les coups

### Vérification
- [ ] SSH fermé par défaut : ✗ Connection refused
- [ ] SSH ouvert après coups : ✓ Password prompt
- [ ] Port se referme après timeout : ✗ Connection refused (après 30 sec)

### Sécurité
- [ ] Séquence changée du défaut (7000,8000,9000)
- [ ] Séquence sauvegardée quelque part (sécurisé)
- [ ] fail2ban combiné avec knock
- [ ] Logs monitorés : `sudo tail -f /var/log/knockd.log`

---

## 🚀 Prochaines Étapes

Une fois knock configuré, vous pouvez :
1. ✅ Combiner avec fail2ban (déjà fait)
2. Ajouter 2FA (authentification à 2 facteurs)
3. Utiliser des clés SSH robustes
4. Monitorer les logs avec SIEM
5. Automatiser les coups (scripts clients)

