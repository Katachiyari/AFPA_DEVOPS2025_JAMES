# 📚 Résumé des Modifications Apportées par le Script

## 🔄 Flux du Script en Images

### Avant l'exécution du script
```
┌─────────────────────────────────────┐
│  SSH sur port 22 (risqué)          │
│  - Authentification password actif  │
│  - Pas de protection brute-force   │
│  - Cryptographie par défaut         │
└─────────────────────────────────────┘
```

### Après l'exécution du script
```
┌────────────────────────────────────────────┐
│  SSH sur port 2545 (sécurisé)             │
│  - Authentification par clé uniquement     │
│  - Protection fail2ban active             │
│  - Cryptographie ANSSI (AES-CTR, SHA512)  │
│  - Récidivistes bannis 7 jours            │
└────────────────────────────────────────────┘
```

---

## 📝 Fichiers Créés/Modifiés

### 1. `/etc/ssh/sshd_config` (MODIFIÉ)
**Avant** :
```bash
# Port 22                          # Commenté
# PasswordAuthentication yes        # Commenté
# PubkeyAuthentication yes         # Commenté
# PermitRootLogin yes              # Commenté
```

**Après** :
```bash
Port 2545                          # Changé
PasswordAuthentication no          # Forcé
PubkeyAuthentication yes          # Forcé
PermitRootLogin prohibit-password  # Strict
MaxAuthTries 3                     # Limité
LoginGraceTime 30                  # Réduit
Ciphers aes256-ctr,aes192-ctr,...  # ANSSI
MACs hmac-sha2-512-etm,...         # ANSSI
```

### 2. `/etc/fail2ban/jail.local` (CRÉÉ)
```ini
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1        # Localhost uniquement
bantime = 3600                     # 1 heure
findtime = 600                     # 10 minutes
maxretry = 3                       # 3 tentatives
backend = systemd                  # Plus efficace
```

### 3. `/etc/fail2ban/jail.d/sshd.local` (CRÉÉ)
```ini
[sshd]
enabled = true                     # Actif
port = 2545                        # Surveille le port 2545
filter = sshd                      # Filtre SSH
maxretry = 3                       # 3 tentatives
bantime = 3600                     # 1 heure de ban
```

### 4. `/etc/fail2ban/jail.d/recidive.local` (CRÉÉ)
```ini
[recidive]
enabled = true                     # Actif
maxretry = 2                       # 2 bans détectés
bantime = 604800                   # 7 jours !
findtime = 86400                   # Dans une journée
```

---

## 🔐 Modifications SSH Détaillées

### Changement de Port
| Aspect | Avant | Après | Impact |
|--------|-------|-------|--------|
| **Port d'écoute** | 22 | 2545 | ✅ Limite les scans automatiques |
| **Visibilité** | Port standard | Port alternatif | ✅ Sécurité par l'obscurité |

### Authentification
| Aspect | Avant | Après | Impact |
|--------|-------|-------|--------|
| **Auth password** | Activée | ❌ Désactivée | ✅ Élimine brute-force sur password |
| **Auth clé publique** | Activée | ✅ Forcée | ✅ Plus sécurisé que password |
| **Clés vides** | Possibles | ❌ Interdites | ✅ Force une passphrase |
| **Root with password** | Possibilité | ❌ Impossible | ✅ Doublement sécurisé |

### Cryptographie (ANSSI)
| Aspect | Avant | Après | Impact |
|--------|-------|-------|--------|
| **Ciphers** | Défaut | aes256-ctr, aes192-ctr, aes128-ctr | ✅ Pas de CBC (vulnérable) |
| **MACs** | Défaut | hmac-sha2-512-etm | ✅ Robustesse maximale |
| **KexAlgorithms** | Défaut | curve25519-sha256 | ✅ Moderne et sûr |

### Limitations d'Attaque
| Paramètre | Avant | Après | Signification |
|-----------|-------|-------|---------------|
| **MaxAuthTries** | 6 | 3 | ✅ Moins de tentatives tolérées |
| **LoginGraceTime** | 120s | 30s | ✅ Timeout rapide |

---

## 🛡️ Protections Fail2Ban

### Architecture des Jails

```
┌─────────────────────────────────────────────────┐
│           FAIL2BAN (Moniteur Principal)         │
│                                                  │
│  ┌──────────────────┐   ┌──────────────────┐  │
│  │  JAIL : SSHD     │   │  JAIL : RECIDIVE │  │
│  ├──────────────────┤   ├──────────────────┤  │
│  │ Surveille port   │   │ Surveille les    │  │
│  │ 2545 (SSH)       │   │ récidivistes     │  │
│  │                  │   │                  │  │
│  │ 3 tentatives → 1h│   │ 2 bans → 7 jours│  │
│  │    BAN           │   │      BAN         │  │
│  └──────────────────┘   └──────────────────┘  │
│         │                        │             │
│         └────────────┬───────────┘             │
│                      │                         │
│              iptables -A INPUT                │
│              [ban IP addresses]               │
│                                                │
└─────────────────────────────────────────────────┘
```

### Flux de Bannissement

```
1️⃣  Attaquant tente SSH sur port 2545
          ↓
2️⃣  Fail2ban surveille /var/log/auth.log
          ↓
3️⃣  SSH échoue (bad password ou autre)
          ↓
4️⃣  Jail SSHD compte : Tentative 1/3
          ↓
5️⃣  Après 3ème tentative échouée...
          ↓
6️⃣  iptables crée une règle DROP pour l'IP
          ↓
7️⃣  iptables : Jail RECIDIVE compte
          ↓
8️⃣  Si 2ème ban en 24h → BAN 7 JOURS sur ALL PORTS
```

---

## 📊 Paramètres de Fail2Ban Expliqués

### `ignoreip = 127.0.0.1/8 ::1`
```
Fail2ban ne bannira JAMAIS :
  ✓ 127.0.0.1/8     → localhost (boucle locale)
  ✓ ::1             → localhost IPv6

À modifier si vous avez plusieurs serveurs de confiance:
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 192.168.0.0/16
```

### `bantime = 3600`
```
Durée d'une interdiction (en secondes)
  3600 = 1 heure     ← Défaut (raisonnable)
  86400 = 24 heures  ← Sévère
  604800 = 7 jours   ← Pour les récidivistes
  -1 = Permanent (pas recommandé)

Formule : bantime = secondes = 60 × 60 × heures
```

### `findtime = 600`
```
Fenêtre de temps pour compter les tentatives (en secondes)
  600 = 10 minutes

Si 3 tentatives échouées dans les 10 dernières minutes
→ L'IP est bannie pour 3600 secondes (1h)
```

### `maxretry = 3`
```
Nombre de tentatives échouées avant bannissement
  3 = Strict (recommandation ANSSI pour SSH)
  5 = Modéré (moins de faux positifs)
  7 = Permissif

Exemple avec maxretry = 3 :
  - Tentative 1 échouée → Compté
  - Tentative 2 échouée → Compté  
  - Tentative 3 échouée → Compté
  - Tentative 4 → BAN !
```

---

## 🔍 Comprendre les Logs

### Format des Logs Fail2Ban

```bash
2025-11-16 14:23:45,123 fail2ban.filter [12345]: INFO    [sshd] Found 203.0.113.50
                        ↑ Timestamp    ↑ Composant  ↑ Jail  ↑ IP trouvée

2025-11-16 14:23:50,456 fail2ban.actions [12345]: NOTICE  [sshd] Ban 203.0.113.50
                                                 ↑ Action  ↑ Jail ↑ IP bannie
```

### Format des Logs SSH

```bash
Nov 16 14:23:45 serveur sshd[1234]: Failed password for user from 203.0.113.50 port 54321 ssh2
                                     ↑ Raison   ↑ Utilisateur  ↑ Source IP
```

---

## ⚙️ Cas d'Usage Courante

### Cas 1 : Augmenter la Sévérité

```bash
# Pour les serveurs très exposés

# Réduire les tentatives de 3 à 2
sudo sed -i 's/maxretry = 3/maxretry = 2/' /etc/fail2ban/jail.d/sshd.local

# Augmenter le ban à 24h au lieu de 1h
sudo sed -i 's/bantime = 3600/bantime = 86400/' /etc/fail2ban/jail.d/sshd.local

# Appliquer
sudo systemctl restart fail2ban
```

### Cas 2 : Whitelist des Partenaires

```bash
# Ajouter les IPs des partenaires de confiance

sudo nano /etc/fail2ban/jail.local

# Remplacer :
# ignoreip = 127.0.0.1/8 ::1

# Par :
# ignoreip = 127.0.0.1/8 ::1 203.0.113.50 198.51.100.0/24

sudo systemctl restart fail2ban
```

### Cas 3 : Notifications par Email

```bash
# Configurer pour recevoir des alertes

sudo nano /etc/fail2ban/jail.local

# Décommenter :
# destemail = admin@example.com
# sendername = Fail2Ban
# action = %(action_mw)s

sudo systemctl restart fail2ban
```

### Cas 4 : Débannir une IP

```bash
# Si vous avez bloqué quelqu'un par erreur

sudo fail2ban-client set sshd unbanip 203.0.113.50

# Vérifier
sudo fail2ban-client status sshd
```

---

## 📌 Points Clés à Retenir

### ✅ Points Forts de cette Configuration

1. **Authentification forte** : Clés publiques obligatoires (impossible de brute-force)
2. **Protection automatique** : Fail2ban bannit les attaquants en temps réel
3. **Récidivistes** : Les IP réitérées sont bannis 7 jours
4. **Cryptographie ANSSI** : Algorithmes robustes et modernes
5. **Port alternatif** : Port 2545 évite les scans automatiques sur 22
6. **Limites des tentatives** : MaxAuthTries limité à 3

### ⚠️ Ce que Vous DEVEZ Faire

1. **Vérifier la connexion SSH** : Test immédiat après
2. **Ajouter votre IP à la whitelist** : Sinon risque de ban accidentel
3. **Garder les clés privées sûres** : Passphrase robuste requise
4. **Monitorer les logs** : Observer `/var/log/fail2ban.log` régulièrement

### 🚫 Ce que Vous NE DEVEZ PAS Faire

1. **Utiliser le port 22** : Utiliser seulement le port 2545
2. **Réactiver le password auth** : Seulement en dernier recours
3. **Permettre root login direct** : Utiliser sudo au lieu de ça
4. **Oublier la whitelist** : Vous vous banniriez vous-même

---

## 🎯 Résumé Exécutif

**Avant le script** :
- Port 22 ouvert et attaquable
- Authentification par mot de passe possible
- Aucune protection brute-force

**Après le script** :
- Port 2545 (moins visible)
- Clés publiques obligatoires
- Fail2ban bannit après 3 tentatives
- Récidivistes bannis 7 jours
- Cryptographie ANSSI
- Sauvegardes automatiques

**Résultat** : Serveur SSH sécurisé et conforme aux recommandations ANSSI ✅

