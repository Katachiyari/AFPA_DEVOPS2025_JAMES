# ⚡ Quick Reference : MFA en 10 Minutes

## 🚀 Installation Serveur (2 minutes)

```bash
# 1. Créer et exécuter le script
sudo nano /opt/scripts/mfa-install.sh
# Coller mfa-install.sh [59]

sudo chmod +x /opt/scripts/mfa-install.sh
sudo bash /opt/scripts/mfa-install.sh
```

## 📱 Configuration Utilisateur (5 minutes)

### Étape 1 : Se connecter au serveur

```bash
knock <IP> 7457 5234 8545
ssh -p 2545 user@<IP>
```

### Étape 2 : Initialiser MFA

```bash
google-authenticator
```

Répondre `y` à toutes les questions.

### Étape 3 : Sauvegarder les Codes

Le programme affiche :
- **QR Code** → Scannez avec Google Authenticator
- **Clé secrète** → Sauvegardez (Bitwarden, 1Password)
- **Codes de secours** → Sauvegardez aussi

### Étape 4 : Tester

Se déconnecter et se reconnecter :

```bash
knock <IP> 7457 5234 8545
ssh -p 2545 user@<IP>
# → Verification code: [entrer le code du téléphone]
# → Connecté ! ✓
```

---

## 🎯 Flux de Connexion Final

```
1. knock server 7457 5234 8545   ← Port knocking
2. ssh -p 2545 user@server        ← SSH
3. Entrer code MFA                ← Google Authenticator
4. Connecté ! ✓
```

---

## 📊 Résumé : 4 Couches de Sécurité

| Couche | Technologie | Raison |
|--------|---|---|
| 1 | Knock | SSH caché |
| 2 | SSH Clés | Pas de password |
| 3 | MFA | Code téléphone |
| 4 | Fail2Ban | Anti-brute-force |

= **Sécurité MAXIMALE** 🔐

---

## 🔧 Commandes Utiles

```bash
# Reconfigurer MFA
google-authenticator

# Voir si MFA configuré
ls -la ~/.google_authenticator

# Vérifier SSH
sudo systemctl status ssh

# Redémarrer SSH
sudo systemctl restart ssh
```

---

## ⚠️ Points Importants

- ✅ Sauvegarder la clé secrète
- ✅ Sauvegarder les codes de secours
- ✅ Tester avant de fermer SSH
- ❌ Ne pas partager la clé secrète
- ❌ Ne pas oublier les codes de secours

---

## 🎉 Vous Êtes Sécurisé !

Fail2Ban ✅
Knock ✅
SSH Clés ✅
MFA ✅

**Serveur super protégé !** 🚀

