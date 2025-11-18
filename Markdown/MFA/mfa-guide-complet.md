# 🔐 Guide Complet : MFA (2FA) pour SSH avec Google Authenticator

## 🎯 Qu'est-ce que le MFA ?

**MFA** = Multi-Factor Authentication = **Authentification à Plusieurs Facteurs**

### Les 3 Facteurs d'Authentification

```
Facteur 1 : "Quelque chose que vous AVEZ"
  → Clé SSH privée (sur votre ordinateur)

Facteur 2 : "Quelque chose que vous CONNAISSEZ"  
  → Mot de passe (mais ici on utilise la clé)

Facteur 3 : "Quelque chose que vous ÊTES" (optionnel)
  → Biométrie (empreinte digitale, visage)

Avec MFA SSH :
  ✅ Clé SSH (facteur 1)
  ✅ Code temporaire Google Authenticator (facteur 2)
  = Authentification 2FA très sécurisée
```

---

## 🚀 Installation Rapide (5 minutes)

### Sur le SERVEUR

```bash
# 1. Créer le script
sudo nano /opt/scripts/mfa-install.sh
# → Coller le contenu de mfa-install.sh [59]

# 2. Rendre exécutable
sudo chmod +x /opt/scripts/mfa-install.sh

# 3. Exécuter
sudo bash /opt/scripts/mfa-install.sh

# 4. Attendre la fin (1-2 minutes)
```

### Résultat attendu

```
[✓ SUCCÈS] Installation de MFA terminée !
[✓ SUCCÈS] SSH est actif et en cours d'exécution
```

---

## 📱 Configuration MFA pour Chaque Utilisateur

### Étape 1 : Initialiser MFA

```bash
# Sur le serveur (connecté en SSH)
google-authenticator

# Le programme va poser des questions :
# Do you want authentication tokens to be time-based (y/n) y
# → Répondre : y (Time-based)
```

### Étape 2 : Sauvegarder les Informations

Le programme va afficher :

```
 █████████████████████████████████████████████
█                                             █
█  [QR CODE - SCANNEZ-LE AVEC GOOGLE AUTH]   █
█                                             █
█████████████████████████████████████████████

Your new secret key is: JBSWY3DPEBLW64TMMQ======
Your verification code is: 123456
Your emergency scratch codes are:
  12345678
  87654321
  ...
```

**⚠ TRÈS IMPORTANT :**
1. **Scannez le QR code** avec Google Authenticator sur votre téléphone
2. **Sauvegardez la clé secrète** : `JBSWY3DPEBLW64TMMQ======`
3. **Sauvegardez les codes de secours** (dans 1Password, Bitwarden, etc.)

### Étape 3 : Confirmer

```bash
# Le programme demande :
# Do you want me to update your ~/.google_authenticator file (y/n) y
# → Répondre : y

# Do you want to disallow multiple uses of the same authentication
# token? (y/n) y
# → Répondre : y (plus sécurisé)

# Do you want to rate-limit logins, max 3 login attempts every 30s (y/n) y
# → Répondre : y (protection brute-force)

# C'est tout !
```

---

## 🧪 Test de MFA

### Avant de Tester

**⚠️ IMPORTANT : Gardez SSH ouvert dans une autre session !**

```bash
# Terminal 1 : Votre session actuelle (ne fermez pas)
# Terminal 2 : Utilisez-le pour tester MFA
```

### Test sur une Autre Machine

```bash
# 1. Frapper à la porte
knock <IP_SERVEUR> 7457 5234 8545

# 2. Se connecter
ssh -p 2545 user@<IP_SERVEUR>

# 3. Vous verrez :
# Verification code: _
# → Entrer le code à 6 chiffres de Google Authenticator

# 4. Ensuite :
# Password: _
# → ATTENTION : Vous n'avez pas de password !
# → Appuyez sur ENTER (ou tapez quelque chose puis ENTER)
# → Vous devez être connecté avec votre clé SSH

# ✓ Connexion réussie !
```

---

## 🔑 Concepts Clés de MFA

### TOTP (Time-based One-Time Password)

```
Comment ça marche :

1. Serveur + Téléphone = même clé secrète
2. Chacun génère un code à 6 chiffres
3. Codes changent toutes les 30 secondes
4. Vous entrez le code du téléphone
5. Serveur compare avec son code
6. Si identique → Authentification réussie ✓
```

### Codes de Secours

```
Pourquoi les codes de secours ?

Si vous perdez votre téléphone :
  → Google Authenticator n'est plus accessible
  → Codes de secours permettent toujours l'accès
  → Vous avez le temps de reconfigurer MFA

C'est une protection importante !
```

---

## 🛠️ Comprendre la Configuration

### Fichier de Configuration SSH

```bash
# /etc/ssh/sshd_config

KbdInteractiveAuthentication yes
# → Permet les défis/réponses (nécessaire pour MFA)

ChallengeResponseAuthentication yes
# → Active les réponses aux défis (pour MFA)

PubkeyAuthentication yes
# → Clés SSH toujours actives

PasswordAuthentication no
# → Pas de password (sécurité)
```

### Configuration PAM

```bash
# /etc/pam.d/sshd

auth required pam_google_authenticator.so nullok
# → MFA Google Authenticator
# → nullok = optional si pas configuré (transition graduelle)
```

---

## 📊 Workflow Complet avec Toutes les Couches

```
Votre Ordinateur                    Serveur
     │                               │
     │ 1. knock 7457 5234 8545      │
     ├──────────────────────────────→│ knockd ouvre port 2545
     │                               │
     │ 2. ssh -p 2545 user@server   │
     ├──────────────────────────────→│ SSH reçoit connexion
     │                               │
     │ SSH vérifie :                │
     │   ✓ Clé SSH valide           │
     │   ✓ IP whitelist fail2ban    │
     │   ← Demande : Verification code:
     │                               │
     │ 3. Regarder Google Auth      │
     │    Code : 123456            │
     │ 123456 ─────────────────────→│ Vérifie le code
     │                               │
     │                          ✓ Code correct !
     │                               │
     │ Connecté ! ✓ ←───────────────│
     │                               │
```

---

## 🚨 Problèmes et Solutions

### Problème : "Verification code: invalid"

```bash
# Causes possibles :

# 1. Mauvais code entré
#    → Google Authenticator doit afficher le code exact

# 2. Désynchronisation horloge
#    → Vérifier que l'horloge du téléphone est correcte
#    → Régler l'heure sur le serveur

# 3. Code expiré (change toutes les 30 sec)
#    → Ne pas attendre trop longtemps après la génération

# 4. MFA non configuré pour cet utilisateur
#    → Vérifier ~/.google_authenticator existe
#    → Relancer : google-authenticator
```

### Problème : "Password: " (sans demande de code MFA)

```bash
# MFA n'est pas activé

# Vérifier que vous avez exécuté :
google-authenticator

# Et que le fichier existe :
ls -la ~/.google_authenticator

# Si vide ou pas trouvé :
# Reconfigurer MFA pour votre utilisateur
google-authenticator
```

### Problème : "Locked out" (impossible de se connecter)

```bash
# Vous avez perdu l'accès

# Solution 1 : Utiliser un code de secours
# Lors du prompt "Verification code: "
# Entrer un code de secours à la place

# Solution 2 : Accès root direct (si possible)
sudo su - user
nano ~/.google_authenticator
# Supprimer le contenu
# Reconfigurer avec : google-authenticator

# Solution 3 : Console physique du serveur
```

---

## 🔐 Bonnes Pratiques

### ✅ À FAIRE

| À FAIRE | Raison |
|---------|--------|
| Sauvegarder la clé secrète | Récupération si téléphone perdu |
| Sauvegarder les codes de secours | Accès d'urgence |
| Tester MFA avant de fermer SSH | Vérifier que ça fonctionne |
| Utiliser un téléphone sûr | Ne pas partager Google Auth |
| Vérifier la date/heure du téléphone | Nécessaire pour TOTP |
| Combiner avec fail2ban + knock | Couches multiples |

### ❌ À NE PAS FAIRE

| À NE PAS FAIRE | Raison |
|---|---|
| Partager votre clé secrète | Quelqu'un d'autre pourrait générer les codes |
| Perdre vos codes de secours | Accès bloqué si perte du téléphone |
| Désactiver fail2ban en même temps | Vous vous ouvrez aux brute-force |
| Oublier de tester avant de fermer SSH | Risque de lockout |
| Activer MFA sans avoir de secours | Sécurité trop fragile |

---

## 🎓 Architecture Finale Complète

### Couche 1 : Port Knocking (Knock)
```
SSH caché par défaut
Nécessite : knock <IP> 7457 5234 8545
```

### Couche 2 : Authentification SSH
```
Clé SSH obligatoire
Pas de password
```

### Couche 3 : MFA (Google Authenticator)
```
Code temporaire du téléphone
Change toutes les 30 secondes
```

### Couche 4 : Protection Brute-Force (Fail2Ban)
```
Max 3 tentatives
Ban 1 heure après
```

### Résultat
```
4 COUCHES DE SÉCURITÉ = SÉCURITÉ MAXIMALE 🔐🔐🔐🔐
```

---

## 📋 Commandes Utiles

```bash
# Initialiser MFA pour l'utilisateur actuel
google-authenticator

# Voir si MFA est configuré
ls -la ~/.google_authenticator

# Voir le statut de SSH
sudo systemctl status ssh

# Voir les logs SSH
sudo tail -f /var/log/auth.log | grep "Accepted\|Failed"

# Redémarrer SSH
sudo systemctl restart ssh

# Vérifier la syntaxe SSH
sudo sshd -t

# Voir la config SSH MFA
sudo grep -E "Kbd|Challenge" /etc/ssh/sshd_config

# Voir la config PAM MFA
sudo grep "google_authenticator" /etc/pam.d/sshd
```

---

## ✅ Checklist Complète

### Installation
- [ ] Script mfa-install.sh exécuté
- [ ] SSH redémarré correctement
- [ ] Pas d'erreurs de syntaxe

### Configuration Utilisateur
- [ ] google-authenticator exécuté
- [ ] QR code scanné dans Google Authenticator
- [ ] Clé secrète sauvegardée
- [ ] Codes de secours sauvegardés

### Tests
- [ ] Test de connexion réussi
- [ ] Code MFA accepté
- [ ] Codes de secours fonctionnent
- [ ] Fail2Ban + Knock + SSH + MFA toutes activés

### Sécurité
- [ ] Pas de password SSH (clés uniquement)
- [ ] MFA activé et fonctionnel
- [ ] Codes de secours en sécurité
- [ ] Accès root restreint

---

## 🚀 Résumé Final

**Vous avez maintenant :**
- ✅ Fail2Ban (protection brute-force)
- ✅ Knock (port knocking)
- ✅ SSH sur port 2545 (clés obligatoires)
- ✅ MFA (Google Authenticator 2FA)

**Sécurité maximale** pour votre serveur ! 🔐

