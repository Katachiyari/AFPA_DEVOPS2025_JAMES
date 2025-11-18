# 🚀 Démarrage Rapide : Knock en 10 Minutes

## ⚡ Étape 1 : Installation (5 minutes)

### Sur le SERVEUR

```bash
# 1. Créer le script
sudo nano /opt/scripts/knock-install.sh
# → Coller le contenu du script [knock-install.sh]
# → Sauvegarder : CTRL+X, Y, ENTER

# 2. Rendre exécutable
sudo chmod +x /opt/scripts/knock-install.sh

# 3. Exécuter
sudo bash /opt/scripts/knock-install.sh

# 4. Le script s'occupe de tout automatiquement
# Attendre 2-3 minutes
```

### Sur votre MACHINE

```bash
# 1. Installer le client knock
sudo apt-get install knockd -y

# C'est tout pour le client !
```

---

## ⚡ Étape 2 : Utilisation (5 minutes)

### À chaque connexion

```bash
# 1. Frapper à la porte
knock <IP_SERVEUR> 7000 8000 9000

# 2. Vous connecter immédiatement
ssh -p 2545 user@<IP_SERVEUR>

# 3. Entrer votre mot de passe ou clé SSH
# C'est tout !

# Note : Vous avez 30 secondes après les coups
# pour vous connecter, sinon le port se referme
```

---

## 📊 Résumé du Flux

```
Votre Machine                          Serveur
     │                                   │
     │──── knock 7000 8000 9000 ─────→  │ knockd reçoit les coups
     │                                   │
     │                              iptables change :
     │                              Ouvre port 2545 pour vous
     │                                   │
     │←──────── SSH Ouvert ─────────────│
     │                                   │
     │──── ssh -p 2545 ─────────────→  │
     │                                   │
     │←──────── Password prompt ────────│
     │                                   │
     │──── Mot de passe ou clé ──────→  │
     │                                   │
     │←──────── Connecté ! ───────────│
     │                                   │
     │           [Vous travaillez]       │
     │                                   │
     │           [30 secondes = timeout] │
     │                                   │
     │                              iptables change :
     │                              Referme le port 2545
     │                                   │
```

---

## 🎯 Points Clés à Retenir

### Séquence Secrète

```bash
# Par défaut (à CHANGER) :
7000,8000,9000

# Changer la séquence :
# Éditer /etc/knockd.conf sur le serveur
# Puis redémarrer : sudo systemctl restart knockd
```

### Délais

```bash
seq_timeout = 5          # Temps ENTRE les coups
                         # Vous avez 5 sec entre chaque coup

command_timeout = 30     # SSH reste ouvert 30 secondes
                         # Vous devez vous connecter rapidement
```

### Commandes Essentielles

| Action | Commande |
|--------|----------|
| **Frapper** | `knock server.com 7000 8000 9000` |
| **Connecter** | `ssh -p 2545 user@server.com` |
| **Voir les logs** | `sudo tail -f /var/log/knockd.log` |
| **Redémarrer knock** | `sudo systemctl restart knockd` |
| **Vérifier iptables** | `sudo iptables -L INPUT -n` |

---

## 🧪 Tests Basiques

### Test 1 : SSH Fermé

```bash
# De votre machine
ssh -p 2545 user@server

# Affichage attendu :
# Connection refused
# ✓ Correct ! Le port est fermé
```

### Test 2 : Frapper

```bash
# De votre machine
knock server 7000 8000 9000

# Pas de message = c'est normal
# Sur le serveur, vérifier :
sudo tail -f /var/log/knockd.log
# Vous devriez voir les coups reçus
```

### Test 3 : SSH Ouvert

```bash
# De votre machine (immédiatement après les coups)
ssh -p 2545 user@server

# Affichage attendu :
# user@server's password: (ou clé SSH)
# ✓ Ça marche !
```

---

## ⚠️ Problèmes Courants et Solutions

### SSH toujours refusé après les coups

```bash
# Vérifier que knockd tourne
sudo systemctl status knockd

# Vérifier que les coups ont été reçus
sudo tail /var/log/knockd.log

# Vérifier la règle iptables
sudo iptables -L INPUT -n | grep 2545

# Redémarrer tout
sudo systemctl restart knockd
sudo systemctl restart ssh
```

### Oublié la séquence

```bash
# Voir la séquence configurée
sudo grep "sequence" /etc/knockd.conf | head -1

# Par défaut : 7000,8000,9000
```

### Vous avez oublié 1 coup

```bash
# Refaire la séquence complète :
knock server 7000 8000 9000

# (Vous devez refaire TOUS les coups dans l'ordre)
```

---

## 💡 Astuces

### Copier-Coller la Commande

```bash
# Créer une fonction pour simplifier
echo "alias knock_open='knock server.com 7000 8000 9000'" >> ~/.bashrc
source ~/.bashrc

# Ensuite, juste taper :
knock_open
ssh -p 2545 user@server
```

### Script Automatisé

```bash
#!/bin/bash
# auto-knock.sh

KNOCK_SEQUENCE="7000 8000 9000"
SERVER="server.com"
USER="user"
PORT="2545"

# Frapper
knock $SERVER $KNOCK_SEQUENCE

# Attendre un peu
sleep 1

# Se connecter
ssh -p $PORT $USER@$SERVER
```

### Avec un Alias SSH

```bash
# Ajouter dans ~/.ssh/config
Host myserver
    HostName server.com
    User user
    Port 2545
    
# Puis utiliser :
# ssh myserver (mais vous devez frapper avant !)
```

---

## ✅ Checklist de Vérification

Après installation, vérifier que :

- [ ] knockd est actif sur le serveur : `sudo systemctl status knockd`
- [ ] SSH répond après les coups : `knock server 7000 8000 9000` puis `ssh ...`
- [ ] SSH est fermé sans les coups : `ssh ...` → Connection refused
- [ ] Les logs de knock existent : `sudo cat /var/log/knockd.log`
- [ ] iptables a la bonne règle : `sudo iptables -L INPUT -n | grep 2545`

---

## 🔐 Sécurité

### Important à Faire

- ✅ Changer la séquence par défaut (7000,8000,9000)
- ✅ Utiliser des numéros aléatoires
- ✅ Ne pas utiliser les ports communs (22, 80, 443)
- ✅ Combiner avec fail2ban
- ✅ Garder la séquence secrète

### Ne pas Faire

- ❌ Laisser la séquence par défaut
- ❌ Partager votre séquence
- ❌ Utiliser des ports faciles à deviner
- ❌ Compter SEULEMENT sur knock (utiliser fail2ban aussi)
- ❌ Oublier de monitorer les logs

---

## 📞 Aide Rapide

```bash
# Voir la configuration
sudo cat /etc/knockd.conf

# Voir les logs en temps réel
sudo tail -f /var/log/knockd.log

# Redémarrer knockd
sudo systemctl restart knockd

# Voir l'interface configurée
sudo grep "KNOCKD_OPTS" /etc/default/knockd

# Voir toutes les règles iptables
sudo iptables -L -n -v

# Redémarrer iptables
sudo netfilter-persistent reload

# Statut complet du système
sudo systemctl status knockd
sudo systemctl status ssh
sudo systemctl status fail2ban
```

---

## 🎯 Résumé en Deux Commandes

```bash
# Étape 1 (une fois) :
sudo bash /opt/scripts/knock-install.sh

# Étape 2 (à chaque fois) :
knock server 7000 8000 9000 && ssh -p 2545 user@server
```

C'est tout ! Vous avez maintenant une couche de sécurité supplémentaire sur votre SSH ! 🎉

