# ⚡ Guide d'Installation Rapide Vagrant

> **Démarrez avec Vagrant en moins de 10 minutes !**

---

## 📥 Installation

### Étape 1 : Installer VirtualBox

#### **🐧 Linux (Debian/Ubuntu)**
```bash
sudo apt update
sudo apt install virtualbox
```

#### **🍎 macOS**
```bash
brew install --cask virtualbox
```

#### **🪟 Windows**
- Téléchargez : https://www.virtualbox.org/wiki/Downloads
- Désactivez Hyper-V si nécessaire :
```powershell
# PowerShell Administrateur
Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
# Redémarrez votre PC
```

---

### Étape 2 : Installer Vagrant

#### **🐧 Linux (Debian/Ubuntu)**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vagrant
```

#### **🍎 macOS**
```bash
brew install vagrant
```

#### **🪟 Windows**
- Téléchargez : https://developer.hashicorp.com/vagrant/downloads
- Installez le fichier `.msi`
- **Redémarrez votre machine**

---

### Étape 3 : Vérifier l'Installation

```bash
vagrant --version
# Sortie attendue : Vagrant 2.4.x
```

---

## 🚀 Démarrage Rapide (5 minutes)

### 1. Créer un Projet

```bash
mkdir mon-projet-vagrant
cd mon-projet-vagrant
```

### 2. Initialiser Vagrant

```bash
vagrant init ubuntu/focal64
```

**✅ Résultat** : Un fichier `Vagrantfile` est créé.

### 3. Démarrer la VM

```bash
vagrant up
```

**⏱️ Temps** : 2-5 minutes (téléchargement inclus la première fois).

### 4. Se Connecter

```bash
vagrant ssh
```

**🎉 Vous êtes dans votre VM Ubuntu !**

### 5. Tester

```bash
# Dans la VM
cat /etc/os-release
echo "Hello Vagrant" > /vagrant/test.txt
exit

# Sur votre machine hôte
cat test.txt  # Affiche "Hello Vagrant"
```

### 6. Gérer la VM

```bash
# Arrêter
vagrant halt

# Redémarrer
vagrant up

# Détruire
vagrant destroy -f
```

---

## 📝 Votre Premier Vagrantfile Personnalisé

Créez un fichier `Vagrantfile` avec ce contenu :

```ruby
Vagrant.configure("2") do |config|
  # Box Ubuntu 20.04
  config.vm.box = "ubuntu/focal64"
  
  # Nom de la machine
  config.vm.hostname = "dev-box"
  
  # Redirection de ports
  config.vm.network "forwarded_port", guest: 80, host: 8080
  
  # Réseau privé
  config.vm.network "private_network", ip: "192.168.56.10"
  
  # Configuration VirtualBox
  config.vm.provider "virtualbox" do |vb|
    vb.name = "Ma-VM-Dev"
    vb.memory = "2048"
    vb.cpus = 2
  end
  
  # Installation automatique de logiciels
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y nginx git curl
    echo "<h1>Hello from Vagrant!</h1>" > /var/www/html/index.html
    systemctl restart nginx
  SHELL
end
```

**Lancer** :
```bash
vagrant up
```

**Accéder** : Ouvrez http://localhost:8080 dans votre navigateur !

---

## 🎯 Commandes Essentielles

### Cycle de Vie

```bash
# Démarrer/Créer
vagrant up

# Se connecter
vagrant ssh

# Voir le statut
vagrant status

# Redémarrer
vagrant reload

# Arrêter
vagrant halt

# Suspendre (mise en veille)
vagrant suspend

# Reprendre
vagrant resume

# Détruire
vagrant destroy
```

### Provisioning

```bash
# Re-provisionner
vagrant provision

# Démarrer sans provisionner
vagrant up --no-provision

# Redémarrer et provisionner
vagrant reload --provision
```

### Boxes

```bash
# Lister les boxes
vagrant box list

# Ajouter une box
vagrant box add ubuntu/focal64

# Mettre à jour une box
vagrant box update

# Supprimer une box
vagrant box remove ubuntu/focal64
```

### Snapshots

```bash
# Créer un snapshot
vagrant snapshot save mon-snapshot

# Lister les snapshots
vagrant snapshot list

# Restaurer un snapshot
vagrant snapshot restore mon-snapshot

# Supprimer un snapshot
vagrant snapshot delete mon-snapshot
```

---

## 📦 Boxes Populaires

| Box | Description |
|-----|-------------|
| `ubuntu/focal64` | Ubuntu 20.04 LTS |
| `ubuntu/jammy64` | Ubuntu 22.04 LTS |
| `bento/debian-11` | Debian 11 |
| `bento/centos-8` | CentOS 8 |
| `generic/alpine312` | Alpine Linux 3.12 |
| `hashicorp/bionic64` | Ubuntu 18.04 (officielle) |

**🔍 Rechercher des boxes** : https://app.vagrantup.com/boxes/search

---

## 🌐 Configuration Réseau Rapide

### Port Forwarding
```ruby
config.vm.network "forwarded_port", guest: 80, host: 8080
```
**➡️ Accès** : http://localhost:8080

### Réseau Privé
```ruby
config.vm.network "private_network", ip: "192.168.56.10"
```
**➡️ Accès** : http://192.168.56.10

### Réseau Public (Bridge)
```ruby
config.vm.network "public_network"
```
**➡️ La VM obtient une IP sur votre réseau local**

---

## 🔧 Exemple : Stack LAMP

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.network "private_network", ip: "192.168.56.10"
  
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
  end
  
  config.vm.provision "shell", inline: <<-SHELL
    # Mise à jour
    apt-get update
    
    # Apache
    apt-get install -y apache2
    
    # MySQL
    debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
    debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
    apt-get install -y mysql-server
    
    # PHP
    apt-get install -y php libapache2-mod-php php-mysql
    
    # Test PHP
    echo "<?php phpinfo(); ?>" > /var/www/html/info.php
    
    systemctl restart apache2
    
    echo "✅ Stack LAMP installée !"
    echo "🌐 Web: http://localhost:8080"
    echo "📝 PHP Info: http://localhost:8080/info.php"
  SHELL
end
```

**Lancer** :
```bash
vagrant up
# Ouvrez http://localhost:8080/info.php
```

---

## 🎪 Multi-Machine Rapide

```ruby
Vagrant.configure("2") do |config|
  # Serveur Web
  config.vm.define "web" do |web|
    web.vm.box = "ubuntu/focal64"
    web.vm.hostname = "web"
    web.vm.network "private_network", ip: "192.168.56.10"
    web.vm.provision "shell", inline: "apt-get update && apt-get install -y nginx"
  end
  
  # Serveur DB
  config.vm.define "db" do |db|
    db.vm.box = "ubuntu/focal64"
    db.vm.hostname = "db"
    db.vm.network "private_network", ip: "192.168.56.11"
    db.vm.provision "shell", inline: "apt-get update && apt-get install -y postgresql"
  end
end
```

**Utilisation** :
```bash
# Démarrer tout
vagrant up

# Démarrer une machine
vagrant up web

# SSH vers une machine
vagrant ssh web
vagrant ssh db
```

---

## 🔌 Plugins Utiles

### Installation
```bash
# VirtualBox Guest Additions (auto-update)
vagrant plugin install vagrant-vbguest

# Gestion du fichier hosts
vagrant plugin install vagrant-hostmanager

# Support proxy
vagrant plugin install vagrant-proxyconf
```

### Lister les plugins
```bash
vagrant plugin list
```

---

## 🐛 Débogage Rapide

### Activer les logs
```bash
# Linux/macOS
VAGRANT_LOG=info vagrant up

# Windows PowerShell
$env:VAGRANT_LOG="info"
vagrant up
```

### Problèmes courants

#### **VM ne démarre pas**
```bash
# Vérifier VirtualBox
VBoxManage --version

# Vérifier les VMs actives
VBoxManage list runningvms

# Forcer l'arrêt si nécessaire
vagrant halt -f
```

#### **Port déjà utilisé**
```ruby
# Auto-correction dans le Vagrantfile
config.vm.network "forwarded_port", guest: 80, host: 8080, auto_correct: true
```

#### **Dossiers partagés ne fonctionnent pas**
```bash
# Réinstaller Guest Additions
vagrant plugin install vagrant-vbguest
vagrant vbguest --do install
vagrant reload
```

#### **SSH timeout**
```bash
# Vérifier la VM dans VirtualBox
VBoxManage showvminfo $(cat .vagrant/machines/default/virtualbox/id)

# Recréer la VM
vagrant destroy -f
vagrant up
```

---

## 📚 Ressources

- 📖 **Documentation** : https://developer.hashicorp.com/vagrant
- 📦 **Boxes** : https://app.vagrantup.com
- 💬 **Forum** : https://discuss.hashicorp.com/c/vagrant
- 🎥 **Tutoriels** : https://developer.hashicorp.com/vagrant/tutorials

---

## ✅ Checklist Démarrage

- [ ] VirtualBox installé
- [ ] Vagrant installé
- [ ] `vagrant --version` fonctionne
- [ ] Premier `vagrant up` réussi
- [ ] `vagrant ssh` fonctionne
- [ ] Dossier `/vagrant` accessible
- [ ] Port forwarding testé
- [ ] VM arrêtée et redémarrée avec succès

---

**🎉 Vous êtes prêt à utiliser Vagrant !**

**🚀 Prochaine étape** : Consultez le Guide Complet pour aller plus loin.