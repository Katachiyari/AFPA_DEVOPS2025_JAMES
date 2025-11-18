# 🔧 Trucs, Astuces et Dépannage Vagrant

> **Solutions aux problèmes courants et optimisations pour Vagrant**

---

## 📋 Table des Matières

1. [Trucs et Astuces](#trucs-astuces)
2. [Optimisation des Performances](#performances)
3. [Dépannage](#depannage)
4. [Erreurs Courantes et Solutions](#erreurs)
5. [Bonnes Pratiques](#bonnes-pratiques)
6. [Scripts Utiles](#scripts)

---

## 💡 Trucs et Astuces {#trucs-astuces}

### Autocomplétion des Commandes

```bash
# Installer l'autocomplétion (bash/zsh)
vagrant autocomplete install --bash --zsh

# Recharger le shell
source ~/.bashrc  # ou ~/.zshrc
```

**✅ Résultat** : Appuyez sur `Tab` pour autocompléter les commandes Vagrant.

### Définir un Provider par Défaut

```bash
# Linux/macOS - Ajouter dans ~/.bashrc ou ~/.zshrc
export VAGRANT_DEFAULT_PROVIDER=virtualbox

# Windows PowerShell - Ajouter dans $PROFILE
$env:VAGRANT_DEFAULT_PROVIDER="virtualbox"
```

### Ignorer la Vérification des Mises à Jour de Box

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.box_check_update = false  # Désactive la vérification
end
```

**Pourquoi ?** : Accélère le démarrage en environnement de développement.

### Créer un Vagrantfile Minimal

```bash
vagrant init -m ubuntu/focal64
```

**Résultat** : Génère un Vagrantfile sans commentaires.

### Utiliser des Variables d'Environnement

```ruby
RAM = ENV['VM_RAM'] || "1024"
CPUS = ENV['VM_CPUS'] || "1"

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  config.vm.provider "virtualbox" do |vb|
    vb.memory = RAM
    vb.cpus = CPUS
  end
end
```

**Utilisation** :
```bash
VM_RAM=4096 VM_CPUS=2 vagrant up
```

### Exécuter des Commandes SSH sans Entrer dans la VM

```bash
# Commande unique
vagrant ssh -c "ps aux | grep nginx"

# Plusieurs commandes
vagrant ssh -c "cd /var/www && ls -la"

# Avec redirection
vagrant ssh -c "cat /var/log/syslog" > syslog.txt
```

### Copier des Fichiers vers/depuis la VM

**Avec le plugin vagrant-scp** :
```bash
# Installer le plugin
vagrant plugin install vagrant-scp

# Copier vers la VM
vagrant scp ./local-file.txt :/home/vagrant/

# Copier depuis la VM
vagrant scp :/home/vagrant/remote-file.txt ./
```

**Sans plugin (via SSH)** :
```bash
# Copier vers la VM
scp -P 2222 -i .vagrant/machines/default/virtualbox/private_key file.txt vagrant@localhost:/home/vagrant/

# Copier depuis la VM
scp -P 2222 -i .vagrant/machines/default/virtualbox/private_key vagrant@localhost:/home/vagrant/file.txt ./
```

### Partager Temporairement votre VM

```bash
# Nécessite un compte Vagrant Cloud (gratuit)
vagrant share
```

**Résultat** : Génère une URL publique temporaire pour accéder à votre VM.

### Lister Toutes les VMs Vagrant

```bash
# Vue d'ensemble de toutes les VMs
vagrant global-status

# Nettoyer le cache
vagrant global-status --prune
```

### Configurer un Proxy

```ruby
if Vagrant.has_plugin?("vagrant-proxyconf")
  config.proxy.http = "http://proxy.company.com:8080"
  config.proxy.https = "http://proxy.company.com:8080"
  config.proxy.no_proxy = "localhost,127.0.0.1,.example.com"
end
```

**Installation du plugin** :
```bash
vagrant plugin install vagrant-proxyconf
```

### Créer des Alias pour Vagrant

**Linux/macOS** (`~/.bashrc` ou `~/.zshrc`) :
```bash
alias vup='vagrant up'
alias vhalt='vagrant halt'
alias vssh='vagrant ssh'
alias vreload='vagrant reload'
alias vstatus='vagrant status'
alias vdestroy='vagrant destroy -f'
```

**Windows PowerShell** (`$PROFILE`) :
```powershell
function vup { vagrant up }
function vhalt { vagrant halt }
function vssh { vagrant ssh }
```

---

## ⚡ Optimisation des Performances {#performances}

### Allouer Plus de Ressources

```ruby
config.vm.provider "virtualbox" do |vb|
  # Augmenter la RAM (en Mo)
  vb.memory = "4096"
  
  # Augmenter les CPUs
  vb.cpus = 4
  
  # Activer I/O APIC (nécessaire pour multi-CPU)
  vb.customize ["modifyvm", :id, "--ioapic", "on"]
  
  # Allouer plus de VRAM (en Mo)
  vb.customize ["modifyvm", :id, "--vram", "128"]
end
```

### Utiliser NFS pour les Dossiers Partagés (Linux/macOS)

**Pourquoi ?** : NFS est beaucoup plus rapide que VirtualBox Shared Folders.

```ruby
config.vm.network "private_network", ip: "192.168.56.10"
config.vm.synced_folder "./app", "/var/www/html", 
  type: "nfs",
  nfs_version: 4,
  nfs_udp: false
```

**⚠️ Important** : Nécessite un réseau privé.

### Utiliser RSync (Unidirectionnel)

```ruby
config.vm.synced_folder "./app", "/var/www/html",
  type: "rsync",
  rsync__exclude: [".git/", "node_modules/", "vendor/"],
  rsync__args: ["--verbose", "--archive", "--delete", "-z", "--copy-links"]
```

**Synchronisation manuelle** :
```bash
vagrant rsync-auto  # Synchronisation automatique en arrière-plan
```

### Désactiver les Dossiers Partagés Inutiles

```ruby
# Désactiver le montage par défaut de /vagrant
config.vm.synced_folder ".", "/vagrant", disabled: true
```

**Pourquoi ?** : Gain de performances si vous n'en avez pas besoin.

### Réduire la Taille de la Box

**Après provisioning, nettoyer la VM** :
```bash
vagrant ssh -c "sudo apt-get clean && sudo apt-get autoclean"
vagrant ssh -c "sudo dd if=/dev/zero of=/EMPTY bs=1M || true"
vagrant ssh -c "sudo rm -f /EMPTY"
```

**Empaqueter la box** :
```bash
vagrant package --output optimized.box
```

### Utiliser des Boxes Minimales

| Box | Taille | Description |
|-----|--------|-------------|
| `generic/alpine312` | ~300 Mo | Alpine Linux (très léger) |
| `ubuntu/focal64` | ~500 Mo | Ubuntu 20.04 standard |
| `bento/ubuntu-22.04` | ~700 Mo | Ubuntu 22.04 optimisée |

### Activer le DNS Resolver

```ruby
config.vm.provider "virtualbox" do |vb|
  vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
end
```

**Pourquoi ?** : Résout les problèmes de résolution DNS lents.

---

## 🐛 Dépannage {#depannage}

### Activer les Logs de Débogage

```bash
# Linux/macOS
VAGRANT_LOG=debug vagrant up 2>&1 | tee vagrant-debug.log

# Windows PowerShell
$env:VAGRANT_LOG="debug"
vagrant up 2>&1 | Tee-Object -FilePath "vagrant-debug.log"
```

**Niveaux disponibles** : `debug`, `info`, `warn`, `error`

### Vérifier l'État de VirtualBox

```bash
# Lister les VMs en cours d'exécution
VBoxManage list runningvms

# Lister toutes les VMs
VBoxManage list vms

# Obtenir les détails d'une VM
VBoxManage showvminfo NOM_VM
```

### Forcer l'Arrêt d'une VM Bloquée

```bash
# Via Vagrant
vagrant halt -f

# Via VirtualBox
VBoxManage controlvm NOM_VM poweroff
```

### Recréer une VM Corrompue

```bash
# Détruire complètement
vagrant destroy -f

# Supprimer les fichiers cachés
rm -rf .vagrant/

# Recréer
vagrant up
```

### Réinstaller VirtualBox Guest Additions

```bash
# Installer le plugin
vagrant plugin install vagrant-vbguest

# Forcer la réinstallation
vagrant vbguest --do install

# Redémarrer la VM
vagrant reload
```

### Nettoyer le Cache de Vagrant

```bash
# Supprimer les boxes inutilisées
vagrant box prune

# Supprimer une box spécifique
vagrant box remove nom/box --all

# Nettoyer le cache global
rm -rf ~/.vagrant.d/tmp/*
```

### Tester la Connectivité Réseau

```bash
# Depuis l'hôte vers la VM
ping 192.168.56.10

# Depuis la VM vers l'extérieur
vagrant ssh -c "ping -c 3 8.8.8.8"

# Vérifier les interfaces réseau
vagrant ssh -c "ip addr show"
```

### Vérifier les Ports en Écoute

```bash
# Sur l'hôte (Linux/macOS)
sudo lsof -i :8080

# Sur l'hôte (Windows)
netstat -ano | findstr :8080

# Dans la VM
vagrant ssh -c "sudo netstat -tlnp | grep :80"
```

---

## ❌ Erreurs Courantes et Solutions {#erreurs}

### Erreur : "The box 'xxx' could not be found"

**Cause** : La box n'est pas téléchargée ou le nom est incorrect.

**Solution** :
```bash
# Vérifier le nom exact sur Vagrant Cloud
# https://app.vagrantup.com/boxes/search

# Ajouter manuellement la box
vagrant box add ubuntu/focal64

# Ou dans le Vagrantfile
vagrant up  # Télécharge automatiquement
```

### Erreur : "VT-x is being used by another hypervisor"

**Cause** : Conflit entre VirtualBox et un autre hyperviseur (KVM, Hyper-V).

**Solution Linux (désactiver KVM)** :
```bash
# Temporairement
sudo modprobe -r kvm_intel
sudo modprobe -r kvm

# Définitivement
echo 'blacklist kvm-intel' | sudo tee -a /etc/modprobe.d/blacklist.conf
sudo update-initramfs -u
sudo reboot
```

**Solution Windows (désactiver Hyper-V)** :
```powershell
# Windows 10
Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All

# Windows 11
bcdedit /set hypervisorlaunchtype off

# Redémarrer
```

### Erreur : "SSH authentication failed"

**Cause** : Problème avec les clés SSH.

**Solution** :
```bash
# Régénérer les clés
vagrant ssh-config
vagrant destroy -f
vagrant up

# Ou forcer la régénération
rm -rf .vagrant/machines/default/virtualbox/
vagrant up
```

### Erreur : "Port 2222 is already in use"

**Cause** : Une autre VM utilise déjà ce port.

**Solution 1 - Auto-correction** :
```ruby
config.vm.network "forwarded_port", guest: 22, host: 2222, auto_correct: true
```

**Solution 2 - Changer manuellement** :
```ruby
config.vm.network "forwarded_port", guest: 22, host: 2223, id: "ssh"
```

### Erreur : "Timed out while waiting for the machine to boot"

**Causes multiples** : RAM insuffisante, VT-x désactivé, timeout trop court.

**Solutions** :
```bash
# 1. Vérifier VT-x dans le BIOS (doit être activé)

# 2. Augmenter le timeout dans le Vagrantfile
config.vm.boot_timeout = 600  # 10 minutes

# 3. Vérifier la RAM disponible
free -h  # Linux
```

```ruby
config.vm.provider "virtualbox" do |vb|
  vb.memory = "2048"  # Augmenter la RAM
end
```

### Erreur : "Network 192.168.56.x is not available"

**Cause** : L'interface Host-Only n'existe pas dans VirtualBox.

**Solution** :
```bash
# Créer l'interface manuellement
VBoxManage hostonlyif create

# Configurer l'interface
VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1 --netmask 255.255.255.0
```

**Ou dans VirtualBox GUI** :
1. Ouvrir VirtualBox
2. Fichier → Préférences → Réseau
3. Onglet "Réseau hôte uniquement"
4. Cliquer sur "+" pour ajouter un réseau

### Erreur : "Shared folders mounting failed"

**Cause** : VirtualBox Guest Additions manquantes ou obsolètes.

**Solution** :
```bash
# Installer le plugin
vagrant plugin install vagrant-vbguest

# Réinstaller Guest Additions
vagrant vbguest --do install --no-cleanup

# Redémarrer
vagrant reload
```

### Erreur : "The guest machine entered an invalid state"

**Cause** : La VM a crashé ou est dans un état inconsistant.

**Solution** :
```bash
# Forcer l'arrêt
vagrant halt -f

# Vérifier dans VirtualBox
VBoxManage list vms

# Si nécessaire, supprimer manuellement
VBoxManage unregistervm NOM_VM --delete

# Recréer
vagrant up
```

### Erreur : "Vagrant cannot forward the specified ports"

**Cause** : Les ports sont déjà utilisés sur l'hôte.

**Solution** :
```bash
# Trouver le processus utilisant le port (Linux/macOS)
sudo lsof -i :8080

# Trouver le processus (Windows)
netstat -ano | findstr :8080

# Tuer le processus
kill -9 PID  # Linux/macOS
taskkill /PID PID /F  # Windows

# Ou changer le port dans le Vagrantfile
config.vm.network "forwarded_port", guest: 80, host: 8081
```

### Erreur : "There was an error while executing VBoxManage"

**Cause** : VirtualBox n'est pas correctement installé ou permissions manquantes.

**Solution** :
```bash
# Vérifier VirtualBox
VBoxManage --version

# Réinstaller VirtualBox si nécessaire
# Linux
sudo apt-get install --reinstall virtualbox

# Vérifier les permissions
sudo usermod -aG vboxusers $USER
# Déconnectez-vous et reconnectez-vous
```

### Erreur : "Vagrant was unable to mount VirtualBox shared folders"

**Cause** : Problème avec Guest Additions ou permissions.

**Solution** :
```bash
# Dans la VM
vagrant ssh
sudo apt-get update
sudo apt-get install -y virtualbox-guest-utils

# Ou avec le plugin
vagrant plugin install vagrant-vbguest
vagrant reload
```

---

## ✅ Bonnes Pratiques {#bonnes-pratiques}

### Versionner le Vagrantfile avec Git

```bash
# .gitignore
.vagrant/
*.log
.DS_Store
```

**✅ À versionner** :
- `Vagrantfile`
- Scripts de provisioning
- Fichiers de configuration

**❌ À ne PAS versionner** :
- `.vagrant/` (état local)
- Logs
- Fichiers temporaires

### Utiliser des Scripts de Provisioning Externes

**Structure recommandée** :
```
mon-projet/
├── Vagrantfile
├── scripts/
│   ├── bootstrap.sh
│   ├── install-nginx.sh
│   └── setup-db.sh
├── config/
│   └── nginx.conf
└── README.md
```

**Dans le Vagrantfile** :
```ruby
config.vm.provision "shell", path: "scripts/bootstrap.sh"
config.vm.provision "shell", path: "scripts/install-nginx.sh"
```

### Rendre les Scripts Idempotents

**❌ Mauvais** :
```bash
apt-get install -y nginx
```

**✅ Bon** :
```bash
if ! command -v nginx &> /dev/null; then
    apt-get update
    apt-get install -y nginx
fi
```

**Pourquoi ?** : Le script peut être exécuté plusieurs fois sans erreur.

### Documenter votre Vagrantfile

```ruby
# Configuration pour le serveur de développement
# RAM : 2 Go, CPU : 2, Réseau : 192.168.56.10
# Services : Nginx, PostgreSQL, Redis
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  # Configuration réseau
  config.vm.network "private_network", ip: "192.168.56.10"
  config.vm.network "forwarded_port", guest: 80, host: 8080
  
  # ... reste de la configuration
end
```

### Utiliser des Conditionnelles pour les Environnements

```ruby
ENVIRONMENT = ENV['VAGRANT_ENV'] || 'development'

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  if ENVIRONMENT == 'production'
    config.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
      vb.cpus = 4
    end
  else
    config.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
    end
  end
end
```

### Créer un README avec Instructions

**README.md** :
```markdown
# Mon Projet Vagrant

## Prérequis
- Vagrant 2.4+
- VirtualBox 7.0+

## Installation
```bash
git clone <repo>
cd <projet>
vagrant up
```

## Accès
- Web : http://localhost:8080
- SSH : `vagrant ssh`
- Base de données : localhost:5432

## Commandes utiles
- Démarrer : `vagrant up`
- Arrêter : `vagrant halt`
- Détruire : `vagrant destroy -f`
```

### Séparer les Provisioners par Rôle

```ruby
config.vm.provision "shell", name: "system-update", inline: "apt-get update"
config.vm.provision "shell", name: "install-nginx", path: "scripts/nginx.sh"
config.vm.provision "shell", name: "install-database", path: "scripts/database.sh"
config.vm.provision "shell", name: "app-setup", path: "scripts/app.sh"
```

**Exécuter un provisioner spécifique** :
```bash
vagrant provision --provision-with install-nginx
```

### Utiliser des Snapshots Régulièrement

```bash
# Après chaque étape importante
vagrant snapshot save base-install
vagrant snapshot save with-web-server
vagrant snapshot save with-database
```

---

## 📜 Scripts Utiles {#scripts}

### Script de Démarrage Automatique

**start.sh** :
```bash
#!/bin/bash

echo "🚀 Démarrage de l'environnement Vagrant..."

# Vérifier si Vagrant est installé
if ! command -v vagrant &> /dev/null; then
    echo "❌ Vagrant n'est pas installé"
    exit 1
fi

# Vérifier si VirtualBox est installé
if ! command -v VBoxManage &> /dev/null; then
    echo "❌ VirtualBox n'est pas installé"
    exit 1
fi

# Démarrer la VM
vagrant up

# Afficher le statut
vagrant status

echo "✅ Environnement prêt !"
echo "📝 Accéder à la VM : vagrant ssh"
```

### Script de Nettoyage

**clean.sh** :
```bash
#!/bin/bash

echo "🧹 Nettoyage de l'environnement Vagrant..."

# Détruire la VM
vagrant destroy -f

# Supprimer les fichiers temporaires
rm -rf .vagrant/
rm -f *.log

# Optionnel : Supprimer la box
# vagrant box remove ubuntu/focal64

echo "✅ Nettoyage terminé !"
```

### Script de Sauvegarde

**backup.sh** :
```bash
#!/bin/bash

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_$TIMESTAMP"

echo "💾 Création du snapshot : $BACKUP_NAME"

vagrant snapshot save "$BACKUP_NAME"

echo "✅ Snapshot créé avec succès !"
vagrant snapshot list
```

### Script de Vérification

**check.sh** :
```bash
#!/bin/bash

echo "🔍 Vérification de l'environnement..."

# Vérifier Vagrant
if command -v vagrant &> /dev/null; then
    echo "✅ Vagrant : $(vagrant --version)"
else
    echo "❌ Vagrant non installé"
fi

# Vérifier VirtualBox
if command -v VBoxManage &> /dev/null; then
    echo "✅ VirtualBox : $(VBoxManage --version)"
else
    echo "❌ VirtualBox non installé"
fi

# Vérifier le statut de la VM
if [ -f Vagrantfile ]; then
    echo ""
    echo "📊 Statut de la VM :"
    vagrant status
else
    echo "⚠️  Aucun Vagrantfile trouvé"
fi

# Lister les boxes
echo ""
echo "📦 Boxes installées :"
vagrant box list
```

---

## 🎓 Ressources Supplémentaires

- 📖 **Documentation officielle** : https://developer.hashicorp.com/vagrant
- 💬 **Forum** : https://discuss.hashicorp.com/c/vagrant
- 🐙 **GitHub Issues** : https://github.com/hashicorp/vagrant/issues
- 📦 **Vagrant Cloud** : https://app.vagrantup.com
- 🎥 **Tutoriels** : https://developer.hashicorp.com/vagrant/tutorials

---

**🎉 Vous avez maintenant toutes les clés pour résoudre les problèmes Vagrant !**