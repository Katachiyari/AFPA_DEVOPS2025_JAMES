# 🎯 Solution 1 : CIDR Range - Guide Complet et Pratique

## ⚡ Utilisation Rapide (5 minutes)

### Exécution du Script Automatisé

```bash
# 1. Télécharger ou créer le script
sudo nano /opt/scripts/fail2ban-cidr-setup.sh
# Coller le contenu du script fail2ban-cidr-setup.sh

# 2. Rendre exécutable
sudo chmod +x /opt/scripts/fail2ban-cidr-setup.sh

# 3. Exécuter
sudo bash /opt/scripts/fail2ban-cidr-setup.sh

# 4. Le script va :
#    - Détecter votre IP actuelle
#    - Découvrir le range CIDR automatiquement
#    - Vous demander confirmation
#    - Configurer fail2ban
#    - Vérifier que tout fonctionne
```

---

## 📚 Comprendre la Solution 1 : CIDR Range

### Qu'est-ce qu'un CIDR Range ?

**CIDR** = Classless Inter-Domain Routing

C'est une manière compacte de représenter un groupe d'adresses IP.

#### Format
```
203.0.113.0/24

203.0.113.0  = Adresse de base
/24          = Masque de réseau (nombre de bits fixes)
```

#### Exemple Concret
```
203.0.113.0/24 représente :
- Première IP : 203.0.113.1
- Dernière IP : 203.0.113.254
- Total : 256 adresses IP

Tous ces serveurs sont dans le MÊME réseau ISP
```

### Pourquoi ça marche pour les IPs dynamiques ?

```
Cas typique avec un ISP :
┌─────────────────────────────────┐
│  ISP : Orange, Proximus, etc    │
│                                 │
│  Vous reçoit des IPs comme :   │
│  - 203.0.113.50 (aujourd'hui)  │
│  - 203.0.113.123 (demain)      │
│  - 203.0.113.87 (dans 3 jours) │
│                                 │
│  MAIS TOUJOURS dans le range :  │
│  203.0.113.0/24                │
└─────────────────────────────────┘

Solution :
Whitelister tout le range 203.0.113.0/24
→ Peu importe quelle IP vous utilisez, 
  vous êtes toujours whitelisté
```

---

## 🔍 Découvrir Votre Range CIDR (Manuel)

### Méthode 1 : Avec WHOIS

```bash
# 1. Découvrir votre IP actuelle
curl -s https://api.ipify.org
# Affichage : 203.0.113.50

# 2. Interroger whois
whois 203.0.113.50 | grep -i CIDR

# Affichage typique :
# CIDR: 203.0.113.0/24
# CIDR: 203.0.113.0/24
```

### Méthode 2 : Format inetnum

Si CIDR n'est pas affiché, chercher inetnum :

```bash
whois 203.0.113.50 | grep -i inetnum

# Affichage :
# inetnum: 203.0.113.0 - 203.0.113.255
# Cela signifie : 203.0.113.0/24
```

### Méthode 3 : Format route (IPv6)

Pour IPv6 :
```bash
whois 2a01:4b00::/32 | grep -i route

# Affichage :
# route: 2a01:4b00::/32
```

### Méthode 4 : Demander à votre ISP

Si les commandes ne marchent pas :
- Orange
- Proximus  
- Vodafone
- etc.

Contactez votre support technique et dites-leur :
> "Quel est le range CIDR/subnet des adresses IP que vous attribuez à ma connexion Internet ?"

---

## 🛠️ Configuration Manuelle

### Si vous préférez faire sans le script

#### Étape 1 : Découvrir votre range CIDR

```bash
# Votre IP actuelle
CURRENT_IP=$(curl -s https://api.ipify.org)
echo "Votre IP : $CURRENT_IP"

# Découvrir le range
whois $CURRENT_IP | grep -E "CIDR|inetnum"
```

#### Étape 2 : Éditer la configuration fail2ban

```bash
# Éditer le fichier
sudo nano /etc/fail2ban/jail.local

# Trouver la section [DEFAULT]
# Chercher la ligne : ignoreip = 127.0.0.1/8 ::1

# Remplacer par (exemple) :
# ignoreip = 127.0.0.1/8 ::1 203.0.113.0/24
```

**Exemple avant** :
```ini
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
bantime = 3600
```

**Exemple après** :
```ini
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 203.0.113.0/24
bantime = 3600
```

#### Étape 3 : Sauvegarder et vérifier

```bash
# Sauvegarder : CTRL+X, Y, ENTER

# Vérifier la syntaxe
sudo fail2ban-client -t
# Affichage attendu : Configuration appears to be OK.

# Redémarrer fail2ban
sudo systemctl restart fail2ban

# Vérifier
sudo fail2ban-client status sshd
```

---

## 📊 Ranges CIDR Courants par ISP (France/Belgique)

### Orange (France)
```
Exemples de ranges typiques :
- 80.10.0.0/16
- 90.0.0.0/8
- 109.0.0.0/8
- 213.200.0.0/12

Commande : whois $(curl -s https://api.ipify.org) | grep CIDR
```

### Proximus/Belgacom (Belgique)
```
Exemples :
- 195.238.0.0/16
- 84.196.0.0/14

Commande : whois $(curl -s https://api.ipify.org) | grep CIDR
```

### Vodafone (Multi-pays)
```
Exemples :
- 213.229.0.0/16
- 130.206.0.0/15

Commande : whois $(curl -s https://api.ipify.org) | grep CIDR
```

### Swisscom (Suisse)
```
Exemples :
- 212.61.0.0/16
- 62.2.0.0/16

Commande : whois $(curl -s https://api.ipify.org) | grep CIDR
```

---

## ⚖️ Avantages et Inconvénients Détaillés

### ✅ Avantages de la Solution 1

| Avantage | Détail |
|----------|--------|
| **Simple** | Juste ajouter un range à ignoreip |
| **Aucune maintenance** | Configuration unique, c'est tout |
| **Pas de dépendance externe** | Pas besoin de service DDNS ou domaine |
| **Automatique** | Une fois configuré, ça marche forever |
| **Gratuit** | Complètement gratuit |
| **Rapide** | Configuration en 2 minutes |

### ❌ Inconvénients de la Solution 1

| Inconvénient | Impact | Sévérité |
|--------------|--------|----------|
| **Range trop large** | Whitelist d'autres utilisateurs du même ISP | 🔴 Moyenne |
| **Limité à un ISP** | Si vous changez d'ISP, plus de whitelist | 🟡 Faible |
| **Pas vraiment IP fixe** | Vous pouvez être bloqué si vous changez d'IP en dehors du range | 🟡 Faible |
| **Fausse sécurité** | Donne accès à tous les utilisateurs du range | 🔴 Moyenne |

---

## 🎓 Quand Choisir la Solution 1 ?

### ✅ Choisir Solution 1 (CIDR) si...

```
☑ Votre IP change mais reste dans le même range ISP
☑ Vous êtes toujours chez le même ISP
☑ Vous ne voulez pas de complexité supplémentaire
☑ Vous travaillez depuis le même endroit (maison)
☑ Vous ne changez pas de région/pays
```

### ❌ Ne pas choisir Solution 1 si...

```
☑ Vous utilisez un VPN (votre IP de sortie peut changer de range)
☑ Vous vous connectez depuis plusieurs endroits différents
☑ Vous changez fréquemment d'ISP
☑ Vous voyagez dans des pays différents
☑ Vous avez besoin de plus de sécurité
→ Dans ces cas, utiliser Solution 2 (DNS Dynamique)
```

---

## 🔄 Tester et Vérifier

### Test 1 : Vérifier la configuration

```bash
# Voir la ligne ignoreip
grep "^ignoreip" /etc/fail2ban/jail.local

# Affichage attendu :
# ignoreip = 127.0.0.1/8 ::1 203.0.113.0/24
```

### Test 2 : Vérifier que vous n'êtes pas bloqué

```bash
# Voir les IPs actuellement bannies
sudo fail2ban-client status sshd

# Affichage attendu :
# Status for the jail: sshd
# |- Filter
# |  |- Currently failed: 0
# |  `- Total failed: 0
# `- Actions
#    |- Currently banned: 0    ← Devrait être 0 (vous n'êtes pas bloqué)
#    `- Total banned: 0
```

### Test 3 : Connexion SSH

```bash
# Essayer de vous connecter
ssh -p 2545 user@votre-serveur

# Doit fonctionner immédiatement
```

### Test 4 : Vérifier votre IP dans le range

```bash
# Votre IP actuelle
CURRENT_IP=$(curl -s https://api.ipify.org)
echo "Votre IP : $CURRENT_IP"

# Première partie de votre IP (ex: 203.0.113)
echo $CURRENT_IP | cut -d. -f1-3

# Vérifier que c'est le même que le CIDR (ex: 203.0.113.0/24)
# Si c'est pareil → Vous êtes dans le bon range ✓
```

---

## 🚨 Troubleshooting

### Problème : "CIDR Range pas trouvé"

```bash
# Le script n'a pas trouvé le range automatiquement

# Solution 1 : Utiliser /24 par défaut
# Exemple si votre IP est 203.0.113.50
# Utiliser : 203.0.113.0/24

# Solution 2 : Utiliser whois manuellement
whois $(curl -s https://api.ipify.org)

# Solution 3 : Contacter votre ISP
# "Quel est mon range CIDR/subnet ?"
```

### Problème : "Je suis bloqué même avec le CIDR"

```bash
# Possible causes :

# 1. Votre IP n'est pas dans le range
CURRENT_IP=$(curl -s https://api.ipify.org)
echo $CURRENT_IP
# Comparer avec le CIDR configuré

# 2. Fail2ban n'a pas redémarré correctement
sudo systemctl restart fail2ban

# 3. Le fichier de config a une erreur de syntaxe
sudo fail2ban-client -t

# 4. Vous êtes bloqué pour une autre raison
sudo fail2ban-client status sshd | grep "Banned IP"
```

### Problème : "Changer l'ISP = je ne peux plus me connecter"

```bash
# Si vous changez d'ISP/région, découvrir votre nouveau range :

# 1. Découvrir votre nouvelle IP
curl -s https://api.ipify.org

# 2. Découvrir le nouveau range
whois $(curl -s https://api.ipify.org) | grep CIDR

# 3. Mettre à jour la configuration
sudo nano /etc/fail2ban/jail.local

# 4. Remplacer l'ancien range par le nouveau

# 5. Redémarrer
sudo systemctl restart fail2ban
```

---

## 📋 Checklist d'Implémentation

### Avant
- [ ] Avoir accès SSH au serveur
- [ ] Fail2ban déjà installé et configuré
- [ ] Accès root/sudo

### Pendant
- [ ] Découvrir mon IP actuelle : `curl -s https://api.ipify.org`
- [ ] Découvrir mon range CIDR : `whois [IP] | grep CIDR`
- [ ] Noter le range CIDR
- [ ] Faire une sauvegarde du fichier jail.local
- [ ] Éditer la configuration
- [ ] Vérifier la syntaxe
- [ ] Redémarrer fail2ban

### Après
- [ ] Tester la connexion SSH
- [ ] Vérifier que je ne suis pas bloqué : `sudo fail2ban-client status sshd`
- [ ] Vérifier la ligne ignoreip : `grep "^ignoreip" /etc/fail2ban/jail.local`
- [ ] Voir les logs : `sudo tail -f /var/log/fail2ban.log`

---

## 🔧 Commandes Rapides de Référence

```bash
# Découvrir l'IP
curl -s https://api.ipify.org

# Découvrir le range CIDR
whois $(curl -s https://api.ipify.org) | grep -i CIDR

# Éditer fail2ban
sudo nano /etc/fail2ban/jail.local

# Vérifier la syntaxe
sudo fail2ban-client -t

# Redémarrer fail2ban
sudo systemctl restart fail2ban

# Voir la whitelist
grep "^ignoreip" /etc/fail2ban/jail.local

# Voir les IPs bannies
sudo fail2ban-client status sshd

# Voir les logs
sudo tail -f /var/log/fail2ban.log

# Débannir une IP
sudo fail2ban-client set sshd unbanip [IP]
```

---

## 📌 Résumé Exécutif

**Votre situation** : IP qui change mais toujours dans le même range ISP

**Solution** : Whitelister le range CIDR entier

**Temps d'implémentation** : 5-10 minutes

**Configuration finale** :
```bash
# /etc/fail2ban/jail.local
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 203.0.113.0/24  ← Votre range
```

**Résultat** :
- ✅ Jamais bloqué même si votre IP change
- ✅ Tant que vous restiez dans le même range ISP
- ✅ Zéro maintenance
- ✅ Complètement automatique

