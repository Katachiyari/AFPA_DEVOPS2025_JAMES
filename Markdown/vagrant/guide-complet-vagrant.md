# 📚 Guide Complet Vagrant - De Zéro à Héros

> **Guide complet pour maîtriser Vagrant - L'outil de gestion d'environnements de développement virtuels**

---

## 📋 Table des Matières

1. [Introduction à Vagrant](#introduction)
2. [Concepts Fondamentaux](#concepts)
3. [Installation](#installation)
4. [Votre Premier Environnement](#premier-environnement)
5. [Le Vagrantfile](#vagrantfile)
6. [Les Boxes](#boxes)
7. [Réseau](#reseau)
8. [Dossiers Synchronisés](#dossiers)
9. [Provisioning](#provisioning)
10. [Multi-Machine](#multi-machine)
11. [Commandes CLI](#cli)
12. [Snapshots](#snapshots)
13. [Plugins](#plugins)
14. [Variables d'Environnement](#variables)
15. [Exercices Pratiques](#exercices)

---

## 🎯 Introduction à Vagrant {#introduction}

### Qu'est-ce que Vagrant ?

**Vagrant** est un utilitaire en ligne de commande développé par **HashiCorp** qui permet de gérer le cycle de vie complet des machines virtuelles. Il isole les dépendances et leur configuration dans un environnement unique, jetable et cohérent.

### 🎪 Pourquoi utiliser Vagrant ?

#### **Avantages principaux**

🔹 **Reproductibilité** : Créez des environnements identiques sur n'importe quelle machine  
🔹 **Portabilité** : Fonctionne sur Linux, macOS et Windows  
🔹 **Isolation** : Séparez vos projets sans conflits de dépendances  
🔹 **Automatisation** : Provisionnez automatiquement vos environnements  
🔹 **Collaboration** : Partagez des configurations via Git

#### **Cas d'usage**

- Développement d'applications web
- Test de configurations serveur
- Modélisation d'architectures distribuées
- Formation et démonstrations
- CI/CD pipelines

### 🏗️ Architecture de Vagrant

```
┌─────────────────────────────────────────┐
│         Votre Machine (Host)            │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │         Vagrant CLI               │ │
│  └────────────┬──────────────────────┘ │
│               │                         │
│  ┌────────────▼──────────────────────┐ │
│  │         Vagrantfile               │ │
│  │    (Configuration Ruby)           │ │
│  └────────────┬──────────────────────┘ │
│               │                         │
│  ┌────────────▼──────────────────────┐ │
│  │         Provider                  │ │
│  │  (VirtualBox/VMware/Docker)       │ │
│  └────────────┬──────────────────────┘ │
│               │                         │
│  ┌────────────▼──────────────────────┐ │
│  │      Machine Virtuelle (Guest)    │ │
│  │      (Ubuntu, CentOS, etc.)       │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

---

## 🧩 Concepts Fondamentaux {#concepts}

### 📦 Les Boxes

**Définition** : Une box est un package contenant une image de système d'exploitation pré-configurée.

**Pourquoi ?** : Au lieu d'installer manuellement un OS, vous téléchargez une box prête à l'emploi.

**Exemple** : `hashicorp/bionic64` est une box Ubuntu 18.04 64 bits officielle.

### 🔧 Les Providers

**Définition** : Un provider est le logiciel de virtualisation qui exécute réellement vos VMs.

**Providers supportés** :
- **VirtualBox** (gratuit, par défaut)
- **VMware** (payant, plus performant)
- **Hyper-V** (Windows)
- **Docker** (conteneurs)
- **Parallels** (macOS)

**Pourquoi ?** : Vagrant abstrait les différences entre providers, votre Vagrantfile fonctionne partout.

### ⚙️ Les Provisioners

**Définition** : Les provisioners automatisent l'installation de logiciels et la configuration.

**Types disponibles** :
- **Shell** (scripts bash/PowerShell)
- **Ansible** (gestion de configuration)
- **Puppet** (infrastructure as code)
- **Chef** (automation)
- **Docker** (conteneurs)

**Pourquoi ?** : Pour éviter de configurer manuellement chaque VM après son démarrage.

### 📄 Le Vagrantfile

**Définition** : Fichier de configuration écrit en Ruby décrivant votre environnement.

**Pourquoi ?** : C'est le cœur de Vagrant, il définit :
- Quelle box utiliser
- Comment configurer le réseau
- Quels dossiers partager
- Comment provisionner la VM

**Important** : Le Vagrantfile doit être versionné avec Git pour permettre à toute l'équipe d'avoir le même environnement.

---

## 💻 Installation {#installation}

### Prérequis

Avant d'installer Vagrant, vous devez avoir un **provider** installé.

#### Installation de VirtualBox (recommandé pour débuter)

**Linux (Debian/Ubuntu)** :
```bash
# Ajouter le dépôt Oracle
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib"

# Installer VirtualBox
sudo apt update
sudo apt install virtualbox-7.0
```

**macOS** :
```bash
# Avec Homebrew
brew install --cask virtualbox
```

**Windows** :
- Téléchargez depuis : https://www.virtualbox.org/wiki/Downloads
- Exécutez l'installeur
- **Important** : Désactivez Hyper-V si actif

### Installation de Vagrant

#### **Linux (Debian/Ubuntu)**

```bash
# Télécharger la dernière version (remplacez X.X.X par la version actuelle)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt install vagrant
```

#### **macOS**

```bash
# Avec Homebrew (recommandé)
brew install vagrant
```

#### **Windows**

1. Téléchargez l'installeur depuis : https://developer.hashicorp.com/vagrant/downloads
2. Exécutez le fichier `.msi`
3. Redémarrez votre machine (important pour PATH)

### Vérification de l'installation

```bash
# Vérifier la version de Vagrant
vagrant --version
# Sortie attendue : Vagrant 2.4.x

# Vérifier que VirtualBox est détecté
vagrant version

# Activer l'autocomplétion (bash/zsh)
vagrant autocomplete install --bash --zsh
```

### 🔧 Gestion des Hyperviseurs Multiples

#### **Problème Linux : KVM et VirtualBox**

**Pourquoi ?** : Seul un hyperviseur peut utiliser VT-x à la fois.

**Solution** :
```bash
# Identifier l'hyperviseur actif
lsmod | grep kvm

# Désactiver KVM temporairement
sudo modprobe -r kvm_intel
sudo modprobe -r kvm

# Désactiver KVM de façon permanente
echo 'blacklist kvm-intel' | sudo tee -a /etc/modprobe.d/blacklist.conf
sudo update-initramfs -u
```

#### **Problème Windows : Hyper-V et VirtualBox**

**Pourquoi ?** : Hyper-V empêche VirtualBox de fonctionner.

**Solution Windows 10** :
```powershell
# Désactiver Hyper-V (PowerShell en Administrateur)
Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
```

**Solution Windows 11** :
```powershell
# PowerShell en Administrateur
bcdedit /set hypervisorlaunchtype off
```

**Redémarrez votre machine** après ces modifications.

---

## 🚀 Votre Premier Environnement {#premier-environnement}

### Étape 1 : Créer un Répertoire de Projet

```bash
# Créer un dossier pour votre projet
mkdir ~/mon-premier-vagrant
cd ~/mon-premier-vagrant
```

**Pourquoi ?** : Chaque projet Vagrant doit avoir son propre répertoire avec son Vagrantfile.

### Étape 2 : Initialiser Vagrant

```bash
# Initialiser avec la box Ubuntu 18.04 officielle
vagrant init hashicorp/bionic64
```

**Ce qui se passe** :
- Vagrant crée un fichier `Vagrantfile` dans le répertoire actuel
- Ce fichier configure l'utilisation de la box `hashicorp/bionic64`

**Contenu du Vagrantfile généré** :
```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp/bionic64"
end
```

**Pourquoi "2" ?** : C'est la version de l'API de configuration Vagrant (v2 est la version actuelle).

### Étape 3 : Démarrer la Machine Virtuelle

```bash
vagrant up
```

**Ce qui se passe** (étape par étape) :

1. **Téléchargement de la box** (première fois uniquement)
   ```
   ==> default: Box 'hashicorp/bionic64' could not be found...
   ==> default: Adding box 'hashicorp/bionic64'...
   ==> default: Successfully added box 'hashicorp/bionic64'
   ```

2. **Import de la box dans VirtualBox**
   ```
   ==> default: Importing base box 'hashicorp/bionic64'...
   ```

3. **Configuration de la VM**
   - Allocation de la RAM
   - Configuration du réseau (NAT par défaut)
   - Configuration des dossiers partagés

4. **Démarrage de la VM**
   ```
   ==> default: Booting VM...
   ==> default: Waiting for machine to boot...
   ```

5. **Configuration SSH**
   ```
   ==> default: Machine booted and ready!
   ```

**Temps estimé** : 2-5 minutes (dépend de votre connexion pour le téléchargement).

### Étape 4 : Se Connecter à la VM

```bash
vagrant ssh
```

**Ce qui se passe** :
- Vagrant utilise SSH pour se connecter à la VM
- Vous obtenez un shell interactif dans la VM
- L'utilisateur par défaut est `vagrant` avec les droits sudo

**Vous êtes maintenant dans votre VM !**

```bash
# Vérifier le système
vagrant@bionic64:~$ cat /etc/os-release
# NAME="Ubuntu"
# VERSION="18.04.6 LTS (Bionic Beaver)"

# Vérifier les ressources
vagrant@bionic64:~$ free -h
vagrant@bionic64:~$ df -h

# Tester la connexion internet
vagrant@bionic64:~$ ping -c 3 google.com
```

### Étape 5 : Quitter et Gérer la VM

```bash
# Quitter la VM (dans le shell SSH)
exit

# Depuis votre machine hôte, voir le statut
vagrant status
# Sortie : default                   running (virtualbox)
```

### Étape 6 : Arrêter la VM

```bash
# Arrêt propre (comme un shutdown)
vagrant halt
```

**Pourquoi ?** : 
- Libère les ressources (RAM, CPU)
- La VM est conservée, vous pouvez la redémarrer avec `vagrant up`

### Étape 7 : Redémarrer la VM

```bash
# Redémarrer la VM existante
vagrant up

# Se reconnecter
vagrant ssh
```

**Différence** : Cette fois, pas de téléchargement ni d'import, c'est quasi instantané !

### Étape 8 : Détruire la VM

```bash
# Supprimer complètement la VM
vagrant destroy

# Confirmation demandée
# default: Are you sure you want to destroy the 'default' VM? [y/N] y
```

**Pourquoi ?** :
- Supprime tous les disques virtuels
- Libère l'espace disque
- La box reste téléchargée (pas besoin de re-télécharger)
- Le Vagrantfile reste intact

**Vous pouvez recréer l'environnement avec `vagrant up` à tout moment !**

---

## 📝 Le Vagrantfile {#vagrantfile}

### Structure de Base

Le Vagrantfile est écrit en **Ruby**, mais vous n'avez pas besoin de connaître Ruby en profondeur.

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

# "2" est la version de configuration
Vagrant.configure("2") do |config|
  
  # Configuration de base
  config.vm.box = "hashicorp/bionic64"
  
  # Autres configurations...
  
end
```

**Pourquoi Ruby ?** : Pour bénéficier de la flexibilité d'un langage de programmation (conditions, boucles, variables).

### Recherche du Vagrantfile

Lorsque vous exécutez une commande `vagrant`, Vagrant cherche le Vagrantfile en remontant l'arborescence :

```
/home/user/projets/mon-app/backend/
  ↓ Pas de Vagrantfile ici
/home/user/projets/mon-app/
  ✓ Vagrantfile trouvé ! Vagrant l'utilise
```

**Pourquoi ?** : Vous pouvez lancer `vagrant` depuis n'importe quel sous-répertoire de votre projet.

### Configuration de la Box

```ruby
Vagrant.configure("2") do |config|
  # Nom de la box
  config.vm.box = "ubuntu/focal64"
  
  # Version spécifique (optionnel)
  config.vm.box_version = "20230215.0.0"
  
  # URL personnalisée (optionnel)
  config.vm.box_url = "https://example.com/custom.box"
  
  # Vérifier les mises à jour (par défaut : true)
  config.vm.box_check_update = true
end
```

**Pourquoi spécifier une version ?** : Pour garantir que toute l'équipe utilise exactement la même box.

### Configuration du Hostname

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  # Définir le hostname de la VM
  config.vm.hostname = "dev-server"
end
```

**Résultat** : Dans la VM, `hostname` affichera `dev-server`.

**Pourquoi ?** : Utile pour identifier facilement la VM, notamment dans les logs.

### Configuration du Provider (VirtualBox)

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  config.vm.provider "virtualbox" do |vb|
    # Nom de la VM dans VirtualBox
    vb.name = "mon-serveur-dev"
    
    # Activer l'interface graphique (par défaut : false)
    vb.gui = false
    
    # Allouer 2 Go de RAM
    vb.memory = "2048"
    
    # Allouer 2 CPU
    vb.cpus = 2
    
    # Personnalisations avancées VirtualBox
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
  end
end
```

**Pourquoi personnaliser ?** :
- **RAM** : Applications gourmandes (bases de données, etc.)
- **CPU** : Compilation, tests parallèles
- **natdnshostresolver1** : Résout des problèmes DNS
- **ioapic** : Nécessaire pour plus de 1 CPU

### Variables et Conditions

```ruby
# Définir des variables
RAM = ENV['VM_RAM'] || "1024"
CPU = ENV['VM_CPU'] || "1"
ENVIRONMENT = ENV['ENV'] || "development"

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  config.vm.provider "virtualbox" do |vb|
    vb.memory = RAM
    vb.cpus = CPU
  end
  
  # Provisionner seulement en développement
  if ENVIRONMENT == "development"
    config.vm.provision "shell", inline: "echo 'Mode développement'"
  end
end
```

**Utilisation** :
```bash
# Démarrer avec 4 Go de RAM
VM_RAM=4096 vagrant up

# Démarrer en production
ENV=production vagrant up
```

**Pourquoi ?** : Adapter la configuration sans modifier le Vagrantfile.

### Ordre de Chargement et Fusion

Vagrant charge les Vagrantfiles dans cet ordre et **fusionne** les configurations :

1. **Vagrantfile packagé avec la box** (rarement utilisé)
2. **`~/.vagrant.d/Vagrantfile`** (configuration globale utilisateur)
3. **Vagrantfile du projet** (celui dans votre répertoire)

**Pourquoi ?** : Définir des paramètres globaux (proxy, configuration réseau) qui s'appliquent à tous vos projets.

**Exemple de Vagrantfile global** (`~/.vagrant.d/Vagrantfile`) :
```ruby
Vagrant.configure("2") do |config|
  # Proxy d'entreprise
  if Vagrant.has_plugin?("vagrant-proxyconf")
    config.proxy.http = "http://proxy.company.com:8080"
    config.proxy.https = "http://proxy.company.com:8080"
    config.proxy.no_proxy = "localhost,127.0.0.1"
  end
end
```

---

## 📦 Les Boxes {#boxes}

### Qu'est-ce qu'une Box ?

Une **box** est un package contenant :
- Une image disque d'un système d'exploitation
- Des métadonnées (version, provider)
- Optionnellement un Vagrantfile pré-configuré

**Format** : Fichier `.box` (archive TAR compressée).

### Découvrir des Boxes

#### Vagrant Cloud (Catalogue Public)

🌐 **URL** : https://app.vagrantup.com/boxes/search

**Boxes officielles recommandées** :

| Box | Description | Providers |
|-----|-------------|-----------|
| `hashicorp/bionic64` | Ubuntu 18.04 (officielle HashiCorp) | VirtualBox, VMware, Hyper-V |
| `bento/ubuntu-22.04` | Ubuntu 22.04 (projet Bento) | VirtualBox, VMware, Parallels |
| `bento/debian-11` | Debian 11 | VirtualBox, VMware |
| `bento/centos-8` | CentOS 8 | VirtualBox, VMware |
| `generic/alpine312` | Alpine Linux 3.12 | VirtualBox, VMware, Libvirt |

**⚠️ Important** : Les namespaces ne sont PAS officiels ! `ubuntu/focal64` n'est PAS maintenu par Canonical.

### Gérer les Boxes

#### Ajouter une Box

```bash
# Ajouter une box depuis le catalogue
vagrant box add bento/ubuntu-22.04

# Ajouter une version spécifique
vagrant box add bento/ubuntu-22.04 --box-version 202401.31.0

# Ajouter pour un provider spécifique
vagrant box add bento/ubuntu-22.04 --provider virtualbox
```

**Ce qui se passe** :
1. Vagrant télécharge la box depuis Vagrant Cloud
2. La box est stockée dans `~/.vagrant.d/boxes/`
3. Elle est maintenant disponible pour tous vos projets

#### Lister les Boxes Installées

```bash
vagrant box list
```

**Exemple de sortie** :
```
bento/ubuntu-22.04    (virtualbox, 202401.31.0)
hashicorp/bionic64    (virtualbox, 1.0.282)
generic/alpine312     (virtualbox, 4.1.12)
```

#### Mettre à Jour une Box

```bash
# Vérifier les mises à jour
vagrant box outdated

# Mettre à jour toutes les boxes
vagrant box update

# Mettre à jour une box spécifique
vagrant box update --box bento/ubuntu-22.04
```

**⚠️ Important** : 
- Cela télécharge une nouvelle version
- Les VMs existantes continuent d'utiliser l'ancienne version
- Pour utiliser la nouvelle version : `vagrant destroy` puis `vagrant up`

#### Supprimer les Anciennes Versions

```bash
# Voir quelles versions seraient supprimées
vagrant box prune --dry-run

# Supprimer les anciennes versions
vagrant box prune

# Garder uniquement les boxes actuellement utilisées
vagrant box prune --keep-active-boxes
```

**Pourquoi ?** : Les boxes prennent beaucoup d'espace disque (plusieurs Go).

#### Supprimer une Box

```bash
# Supprimer une box spécifique
vagrant box remove bento/ubuntu-22.04

# Supprimer une version spécifique
vagrant box remove bento/ubuntu-22.04 --box-version 202401.31.0

# Supprimer toutes les versions
vagrant box remove bento/ubuntu-22.04 --all
```

#### Empaqueter une Box Personnalisée

```bash
# Depuis une VM existante
vagrant package --output ma-box-custom.box

# Ajouter cette box localement
vagrant box add ma-box-custom ma-box-custom.box
```

**Cas d'usage** : Partager une configuration pré-installée avec votre équipe.

### Utiliser une Box Locale

```ruby
Vagrant.configure("2") do |config|
  # Utiliser un fichier .box local
  config.vm.box = "ma-box-custom"
  config.vm.box_url = "file:///path/to/ma-box-custom.box"
end
```

---

## 🌐 Réseau {#reseau}

### Types de Configuration Réseau

Vagrant propose 3 modes de réseau principaux :

#### 1. Port Forwarding (Redirection de Ports)

**Concept** : Rediriger un port de votre machine hôte vers la VM.

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  # Rediriger le port 8080 de l'hôte vers le port 80 de la VM
  config.vm.network "forwarded_port", guest: 80, host: 8080
  
  # Plusieurs redirections
  config.vm.network "forwarded_port", guest: 3306, host: 3306  # MySQL
  config.vm.network "forwarded_port", guest: 5432, host: 5432  # PostgreSQL
end
```

**Résultat** : 
- Depuis votre navigateur : `http://localhost:8080` → accède au serveur web de la VM
- Connexion à MySQL : `mysql -h 127.0.0.1 -P 3306` → se connecte à MySQL dans la VM

**Pourquoi l'utiliser ?** :
- ✅ Simple et rapide
- ✅ Pas de configuration réseau supplémentaire
- ❌ Ne permet pas la communication entre VMs

**Options avancées** :
```ruby
config.vm.network "forwarded_port", 
  guest: 80, 
  host: 8080,
  protocol: "tcp",              # tcp ou udp
  auto_correct: true,           # Change automatiquement le port si occupé
  host_ip: "127.0.0.1"         # N'écouter que sur localhost
```

#### 2. Private Network (Réseau Privé)

**Concept** : Créer un réseau privé entre votre hôte et la VM (ou entre VMs).

##### **DHCP (Attribution Automatique)** :
```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  # IP attribuée automatiquement
  config.vm.network "private_network", type: "dhcp"
end
```

##### **IP Statique (Recommandé)** :
```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  # IP statique sur le réseau privé
  config.vm.network "private_network", ip: "192.168.56.10"
end
```

**Résultat** :
- Depuis votre hôte : `http://192.168.56.10` → accède à la VM
- Les VMs sur le même réseau privé peuvent se parler

**Pourquoi l'utiliser ?** :
- ✅ Communication entre VMs
- ✅ Pas besoin de redirection de ports
- ✅ Idéal pour architecture multi-machines
- ❌ La VM n'est pas accessible depuis l'extérieur de votre machine

**Cas d'usage** : Simuler une architecture serveur web + base de données.

#### 3. Public Network (Réseau Pont/Bridge)

**Concept** : La VM obtient une IP sur votre réseau local (comme une machine physique).

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  # Demander quelle interface utiliser
  config.vm.network "public_network"
  
  # Ou spécifier l'interface
  config.vm.network "public_network", bridge: "en0: Wi-Fi (Wireless)"
end
```

**Résultat** :
- La VM obtient une IP type `192.168.1.50` sur votre réseau local
- Accessible depuis n'importe quelle machine du réseau local

**Pourquoi l'utiliser ?** :
- ✅ Tester depuis d'autres machines (mobile, autre PC)
- ✅ Simuler un vrai serveur sur le réseau
- ❌ Exposition sur le réseau local (sécurité)

### Exemple Complet : Architecture Multi-Tiers

```ruby
Vagrant.configure("2") do |config|
  # Serveur Web
  config.vm.define "web" do |web|
    web.vm.box = "ubuntu/focal64"
    web.vm.hostname = "web-server"
    web.vm.network "private_network", ip: "192.168.56.10"
    web.vm.network "forwarded_port", guest: 80, host: 8080
  end
  
  # Serveur Base de Données
  config.vm.define "db" do |db|
    db.vm.box = "ubuntu/focal64"
    db.vm.hostname = "db-server"
    db.vm.network "private_network", ip: "192.168.56.11"
    db.vm.network "forwarded_port", guest: 5432, host: 5432
  end
end
```

**Résultat** :
- Le serveur web (`192.168.56.10`) peut contacter la DB (`192.168.56.11`)
- Depuis votre hôte : `http://localhost:8080` → serveur web
- Depuis votre hôte : `psql -h localhost -p 5432` → base de données

---

## 📁 Dossiers Synchronisés {#dossiers}

### Concept

Les **dossiers synchronisés** (synced folders) permettent de partager des fichiers entre votre machine hôte et la VM.

**Pourquoi ?** :
- Éditer du code sur votre machine avec votre IDE préféré
- Le code est immédiatement disponible dans la VM
- Les modifications sont bidirectionnelles

### Configuration Par Défaut

```ruby
# Configuration implicite
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  # Le dossier du projet est automatiquement monté dans /vagrant
end
```

**Résultat** :
- Dossier hôte : `~/mon-projet/`
- Dossier VM : `/vagrant/`

**Vérification dans la VM** :
```bash
vagrant ssh
cd /vagrant
ls  # Vous voyez les fichiers de votre projet !
```

### Synchronisation Personnalisée

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  # Synchroniser un dossier spécifique
  # Format : dossier_hôte, dossier_vm
  config.vm.synced_folder "./app", "/var/www/html"
  
  # Synchroniser plusieurs dossiers
  config.vm.synced_folder "./config", "/etc/myapp"
  config.vm.synced_folder "./data", "/opt/data"
end
```

### Types de Synchronisation

#### 1. VirtualBox Shared Folders (Par Défaut)

```ruby
config.vm.synced_folder "./app", "/var/www/html"
```

**Caractéristiques** :
- ✅ Fonctionne partout
- ✅ Aucune configuration supplémentaire
- ❌ Performances moyennes
- ❌ Problèmes avec les symlinks

#### 2. NFS (Network File System)

**Recommandé pour Linux/macOS**

```ruby
config.vm.synced_folder "./app", "/var/www/html", 
  type: "nfs",
  nfs_version: 4,
  nfs_udp: false
```

**Avantages** :
- ✅ Très performant
- ✅ Supporte les symlinks
- ❌ Nécessite des privilèges sudo lors du `vagrant up`
- ❌ Ne fonctionne qu'avec private_network

**Configuration réseau nécessaire** :
```ruby
config.vm.network "private_network", ip: "192.168.56.10"
config.vm.synced_folder "./app", "/var/www/html", type: "nfs"
```

#### 3. SMB (Windows)

```ruby
config.vm.synced_folder "./app", "/var/www/html",
  type: "smb",
  smb_username: "votre_user",
  smb_password: "votre_password"
```

**Pourquoi ?** : NFS n'est pas disponible nativement sur Windows.

#### 4. RSync (Synchronisation Unidirectionnelle)

```ruby
config.vm.synced_folder "./app", "/var/www/html",
  type: "rsync",
  rsync__exclude: [".git/", "node_modules/"],
  rsync__args: ["--verbose", "--archive", "--delete", "-z"]
```

**Caractéristiques** :
- ✅ Très performant
- ❌ Unidirectionnel (hôte → VM uniquement)
- ❌ Nécessite `rsync` installé sur l'hôte

**Synchronisation manuelle** :
```bash
# Synchroniser manuellement après modifications
vagrant rsync

# Synchronisation automatique en arrière-plan
vagrant rsync-auto
```

### Options Avancées

```ruby
Vagrant.configure("2") do |config|
  config.vm.synced_folder "./app", "/var/www/html",
    owner: "www-data",            # Propriétaire des fichiers dans la VM
    group: "www-data",            # Groupe des fichiers dans la VM
    mount_options: ["dmode=775", "fmode=664"],  # Permissions
    disabled: false,              # Désactiver la synchronisation
    create: true                  # Créer le dossier s'il n'existe pas
end
```

### Désactiver la Synchronisation Par Défaut

```ruby
Vagrant.configure("2") do |config|
  # Désactiver le montage automatique de /vagrant
  config.vm.synced_folder ".", "/vagrant", disabled: true
end
```

**Pourquoi ?** : Dans certains cas (production, tests), vous ne voulez pas de synchronisation.

---

## ⚙️ Provisioning {#provisioning}

### Qu'est-ce que le Provisioning ?

Le **provisioning** permet d'automatiser la configuration de votre VM : installer des logiciels, copier des fichiers, lancer des scripts.

**Pourquoi ?** :
- Éviter la configuration manuelle après chaque `vagrant up`
- Garantir un environnement identique pour toute l'équipe
- Automatiser complètement le déploiement

### Quand le Provisioning s'Exécute

Le provisioning s'exécute dans ces situations :

1. **Premier `vagrant up`** (création de la VM)
2. **`vagrant provision`** (provisionner une VM en cours d'exécution)
3. **`vagrant reload --provision`** (redémarrer et provisionner)

**Forcer le provisioning** :
```bash
vagrant up --provision
```

**Empêcher le provisioning** :
```bash
vagrant up --no-provision
```

### Provisioner Shell (Scripts Bash)

Le provisioner le plus simple : exécuter des commandes shell.

#### **Commandes Inline**

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  # Une seule commande
  config.vm.provision "shell", inline: "apt-get update"
end
```

#### **Script Multi-lignes (Heredoc)**

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  config.vm.provision "shell", inline: <<-SHELL
    # Mettre à jour les paquets
    apt-get update
    
    # Installer Apache
    apt-get install -y apache2
    
    # Démarrer Apache
    systemctl start apache2
    systemctl enable apache2
    
    # Créer une page HTML
    echo "<h1>Hello from Vagrant!</h1>" > /var/www/html/index.html
  SHELL
end
```

**Pourquoi `<<-SHELL` ?** : C'est un "heredoc" Ruby permettant d'écrire du texte multi-lignes.

#### **Script Externe**

**Créer le script** (`scripts/setup.sh`) :
```bash
#!/bin/bash

echo "🚀 Installation de l'environnement de développement..."

# Mettre à jour
apt-get update

# Installer les outils
apt-get install -y git curl vim nginx

# Configuration NGINX
cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80;
    root /var/www/html;
    index index.php index.html;
}
EOF

systemctl restart nginx

echo "✅ Installation terminée !"
```

**Référencer le script dans le Vagrantfile** :
```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  config.vm.provision "shell", path: "scripts/setup.sh"
end
```

**Pourquoi ?** :
- ✅ Scripts réutilisables
- ✅ Meilleure organisation
- ✅ Versionnable avec Git

#### **Script avec Arguments**

```ruby
Vagrant.configure("2") do |config|
  config.vm.provision "shell" do |s|
    s.inline = "echo 'Bonjour $1, environnement $2'"
    s.args = ["James", "development"]
  end
end
```

**Ou avec un tableau** :
```ruby
config.vm.provision "shell" do |s|
  s.path = "scripts/setup.sh"
  s.args = ["--env=development", "--db=postgresql"]
end
```

#### **Script avec Privilèges**

```ruby
# Script exécuté en tant que root (par défaut)
config.vm.provision "shell", inline: "apt-get update", privileged: true

# Script exécuté en tant qu'utilisateur vagrant
config.vm.provision "shell", inline: "echo 'Hello'", privileged: false
```

#### **Script avec Variables d'Environnement**

```ruby
config.vm.provision "shell" do |s|
  s.inline = "echo $DB_HOST:$DB_PORT"
  s.env = {
    "DB_HOST" => "192.168.56.11",
    "DB_PORT" => "5432"
  }
end
```

### Provisioning Avancé

#### **Ansible**

```ruby
config.vm.provision "ansible" do |ansible|
  ansible.playbook = "playbook.yml"
  ansible.inventory_path = "inventory"
  ansible.limit = "all"
end
```

#### **Puppet**

```ruby
config.vm.provision "puppet" do |puppet|
  puppet.manifests_path = "manifests"
  puppet.manifest_file = "default.pp"
end
```

#### **Chef**

```ruby
config.vm.provision "chef_solo" do |chef|
  chef.cookbooks_path = "cookbooks"
  chef.add_recipe "apache"
end
```

### Exemple Complet : Stack LAMP

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.network "forwarded_port", guest: 80, host: 8080
  
  config.vm.provision "shell", inline: <<-SHELL
    # Mettre à jour
    apt-get update
    
    # Installer Apache
    apt-get install -y apache2
    
    # Installer MySQL
    debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
    debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
    apt-get install -y mysql-server
    
    # Installer PHP
    apt-get install -y php libapache2-mod-php php-mysql
    
    # Créer un fichier de test PHP
    cat > /var/www/html/info.php <<EOF
<?php
phpinfo();
?>
EOF
    
    # Redémarrer Apache
    systemctl restart apache2
    
    echo "✅ Stack LAMP installée !"
    echo "📝 Visitez http://localhost:8080/info.php"
  SHELL
end
```

**Utilisation** :
```bash
vagrant up
# Ouvrir http://localhost:8080/info.php dans votre navigateur
```

---

## 🖥️ Multi-Machine {#multi-machine}

### Pourquoi Multi-Machine ?

Les environnements multi-machines permettent de :
- Modéliser une architecture réelle (web + DB + cache)
- Tester des systèmes distribués
- Simuler un cluster
- Tester des pannes et partitions réseau

### Définir Plusieurs Machines

```ruby
Vagrant.configure("2") do |config|
  
  # Machine 1 : Serveur Web
  config.vm.define "web" do |web|
    web.vm.box = "ubuntu/focal64"
    web.vm.hostname = "web-server"
    web.vm.network "private_network", ip: "192.168.56.10"
  end
  
  # Machine 2 : Base de Données
  config.vm.define "db" do |db|
    db.vm.box = "ubuntu/focal64"
    db.vm.hostname = "db-server"
    db.vm.network "private_network", ip: "192.168.56.11"
  end
  
end
```

### Contrôler les Machines

```bash
# Démarrer toutes les machines
vagrant up

# Démarrer une machine spécifique
vagrant up web
vagrant up db

# SSH vers une machine spécifique
vagrant ssh web
vagrant ssh db

# Voir le statut de toutes les machines
vagrant status

# Arrêter une machine
vagrant halt web

# Détruire une machine
vagrant destroy db
```

### Configuration Partagée

```ruby
Vagrant.configure("2") do |config|
  
  # Configuration commune à toutes les machines
  config.vm.box = "ubuntu/focal64"
  config.vm.provision "shell", inline: "apt-get update"
  
  config.vm.define "web" do |web|
    web.vm.hostname = "web-server"
    web.vm.network "private_network", ip: "192.168.56.10"
    
    # Provisioning spécifique au web
    web.vm.provision "shell", inline: "apt-get install -y nginx"
  end
  
  config.vm.define "db" do |db|
    db.vm.hostname = "db-server"
    db.vm.network "private_network", ip: "192.168.56.11"
    
    # Provisioning spécifique à la DB
    db.vm.provision "shell", inline: "apt-get install -y postgresql"
  end
  
end
```

**Ordre d'exécution du provisioning** :
1. Provisioning commun (`apt-get update`)
2. Provisioning spécifique (`nginx` ou `postgresql`)

### Machine Primaire

```ruby
config.vm.define "web", primary: true do |web|
  web.vm.box = "ubuntu/focal64"
end

config.vm.define "db" do |db|
  db.vm.box = "ubuntu/focal64"
end
```

**Effet** :
```bash
# Sans nom de machine, agit sur la machine primaire
vagrant ssh  # Se connecte à "web"
```

### Autostart

```ruby
config.vm.define "web" do |web|
  web.vm.box = "ubuntu/focal64"
end

config.vm.define "db" do |db|
  db.vm.box = "ubuntu/focal64"
end

config.vm.define "monitoring", autostart: false do |mon|
  mon.vm.box = "ubuntu/focal64"
end
```

**Résultat** :
```bash
vagrant up  # Démarre "web" et "db", PAS "monitoring"

vagrant up monitoring  # Démarrer manuellement monitoring
```

### Exemple Complet : Architecture 3-Tiers

```ruby
Vagrant.configure("2") do |config|
  
  # Configuration commune
  config.vm.box = "ubuntu/focal64"
  
  # Load Balancer
  config.vm.define "lb" do |lb|
    lb.vm.hostname = "loadbalancer"
    lb.vm.network "private_network", ip: "192.168.56.10"
    lb.vm.network "forwarded_port", guest: 80, host: 8080
    
    lb.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y nginx
      
      cat > /etc/nginx/conf.d/load-balancer.conf <<EOF
upstream backend {
    server 192.168.56.11;
    server 192.168.56.12;
}

server {
    listen 80;
    location / {
        proxy_pass http://backend;
    }
}
EOF
      systemctl restart nginx
    SHELL
  end
  
  # Serveur Web 1
  config.vm.define "web1" do |web|
    web.vm.hostname = "web1"
    web.vm.network "private_network", ip: "192.168.56.11"
    web.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y apache2
      echo "<h1>Web Server 1</h1>" > /var/www/html/index.html
      systemctl restart apache2
    SHELL
  end
  
  # Serveur Web 2
  config.vm.define "web2" do |web|
    web.vm.hostname = "web2"
    web.vm.network "private_network", ip: "192.168.56.12"
    web.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y apache2
      echo "<h1>Web Server 2</h1>" > /var/www/html/index.html
      systemctl restart apache2
    SHELL
  end
  
  # Base de Données
  config.vm.define "db" do |db|
    db.vm.hostname = "database"
    db.vm.network "private_network", ip: "192.168.56.20"
    
    db.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
    end
    
    db.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y postgresql postgresql-contrib
      
      # Permettre les connexions distantes
      sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf
      echo "host all all 192.168.56.0/24 md5" >> /etc/postgresql/*/main/pg_hba.conf
      
      systemctl restart postgresql
    SHELL
  end
  
end
```

**Utilisation** :
```bash
vagrant up
# Ouvrez http://localhost:8080 et rafraîchissez pour voir le load balancing
```

---

## 🎮 Commandes CLI {#cli}

### Commandes Essentielles

#### `vagrant init`

**Initialiser un nouveau projet Vagrant**

```bash
# Créer un Vagrantfile vide
vagrant init

# Créer un Vagrantfile avec une box
vagrant init ubuntu/focal64

# Créer un Vagrantfile minimal (sans commentaires)
vagrant init -m ubuntu/focal64

# Forcer l'écrasement d'un Vagrantfile existant
vagrant init -f ubuntu/focal64
```

#### `vagrant up`

**Créer et démarrer la machine virtuelle**

```bash
# Démarrer la VM
vagrant up

# Démarrer avec un provider spécifique
vagrant up --provider=vmware_desktop

# Démarrer sans provisionner
vagrant up --no-provision

# Démarrer et forcer le provisioning
vagrant up --provision
```

#### `vagrant ssh`

**Se connecter en SSH à la VM**

```bash
# Connexion SSH
vagrant ssh

# Connexion à une machine spécifique (multi-machine)
vagrant ssh web

# Exécuter une commande unique
vagrant ssh -c "ls -la /var/www"

# Mode plain (sans authentification automatique)
vagrant ssh -p
```

#### `vagrant halt`

**Arrêter proprement la VM**

```bash
# Arrêt propre
vagrant halt

# Arrêt forcé (comme couper l'alimentation)
vagrant halt --force

# Arrêter une machine spécifique
vagrant halt web
```

#### `vagrant reload`

**Redémarrer la VM (équivaut à halt + up)**

```bash
# Redémarrer
vagrant reload

# Redémarrer et provisionner
vagrant reload --provision
```

#### `vagrant suspend`

**Suspendre la VM (mise en veille)**

```bash
vagrant suspend
```

**Pourquoi ?** :
- ✅ Sauvegarde l'état exact de la VM
- ✅ Reprise instantanée
- ❌ Consomme de l'espace disque (RAM sauvegardée)

#### `vagrant resume`

**Reprendre une VM suspendue**

```bash
vagrant resume
```

#### `vagrant status`

**Voir l'état des VMs**

```bash
# État local
vagrant status

# État global (toutes les VMs sur la machine)
vagrant global-status

# Nettoyer le cache du global-status
vagrant global-status --prune
```

**Exemple de sortie** :
```
Current machine states:

web                       running (virtualbox)
db                        poweroff (virtualbox)
```

#### `vagrant destroy`

**Détruire complètement la VM**

```bash
# Avec confirmation
vagrant destroy

# Sans confirmation
vagrant destroy -f

# Détruire une machine spécifique
vagrant destroy web
```

#### `vagrant provision`

**Provisionner une VM en cours d'exécution**

```bash
# Provisionner
vagrant provision

# Provisionner avec des provisioners spécifiques
vagrant provision --provision-with shell,ansible
```

---

## 📸 Snapshots {#snapshots}

### Qu'est-ce qu'un Snapshot ?

Un **snapshot** est un instantané de l'état complet d'une VM à un moment donné.

**Pourquoi ?** :
- Sauvegarder avant des modifications risquées
- Tester différentes configurations
- Revenir rapidement en arrière

### Commandes Snapshot

#### Créer un Snapshot

```bash
# Avec un nom
vagrant snapshot save backup-avant-upgrade

# Avec push (pile de snapshots)
vagrant snapshot push
```

#### Lister les Snapshots

```bash
vagrant snapshot list
```

**Exemple de sortie** :
```
backup-avant-upgrade
test-config
```

#### Restaurer un Snapshot

```bash
# Restaurer un snapshot nommé
vagrant snapshot restore backup-avant-upgrade

# Restaurer le dernier push
vagrant snapshot pop

# Restaurer sans démarrer la VM
vagrant snapshot restore backup-avant-upgrade --no-start

# Restaurer sans provisionner
vagrant snapshot restore backup-avant-upgrade --no-provision
```

#### Supprimer un Snapshot

```bash
# Supprimer un snapshot spécifique
vagrant snapshot delete backup-avant-upgrade
```

### Exemple d'Utilisation

```bash
# 1. Créer un snapshot initial
vagrant snapshot save base-install

# 2. Faire des modifications
vagrant ssh -c "apt-get install -y nginx"

# 3. Tester
curl http://localhost:8080

# 4. Problème ? Restaurer !
vagrant snapshot restore base-install

# 5. Tout fonctionne ? Créer un nouveau snapshot
vagrant snapshot save with-nginx
```

### Workflow de Développement avec Snapshots

```bash
# Configuration de base
vagrant up
vagrant snapshot save clean-install

# Développement feature 1
# ... modifications ...
vagrant snapshot save feature-1-complete

# Développement feature 2
# ... modifications ...
vagrant snapshot save feature-2-complete

# Retour à un état précédent
vagrant snapshot restore feature-1-complete

# Supprimer les snapshots inutiles
vagrant snapshot delete feature-2-complete
```

---

## 🔌 Plugins {#plugins}

### Qu'est-ce qu'un Plugin ?

Les **plugins** étendent les fonctionnalités de Vagrant.

### Gérer les Plugins

#### Installer un Plugin

```bash
# Installer un plugin
vagrant plugin install vagrant-vbguest

# Installer une version spécifique
vagrant plugin install vagrant-vbguest --plugin-version 0.30.0
```

#### Lister les Plugins

```bash
vagrant plugin list
```

#### Mettre à Jour les Plugins

```bash
# Mettre à jour tous les plugins
vagrant plugin update

# Mettre à jour un plugin spécifique
vagrant plugin update vagrant-vbguest
```

#### Désinstaller un Plugin

```bash
vagrant plugin uninstall vagrant-vbguest
```

### Plugins Utiles

#### **vagrant-vbguest**

**Fonction** : Met automatiquement à jour les VirtualBox Guest Additions.

```bash
vagrant plugin install vagrant-vbguest
```

**Pourquoi ?** : Résout les problèmes de dossiers partagés et améliore les performances.

#### **vagrant-hostmanager**

**Fonction** : Gère automatiquement le fichier `/etc/hosts`.

```bash
vagrant plugin install vagrant-hostmanager
```

**Configuration** :
```ruby
Vagrant.configure("2") do |config|
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  
  config.vm.define "web" do |web|
    web.vm.hostname = "dev.local"
    web.vm.network "private_network", ip: "192.168.56.10"
  end
end
```

**Résultat** : Vous pouvez accéder à `http://dev.local` au lieu de `http://192.168.56.10`.

#### **vagrant-proxyconf**

**Fonction** : Configure automatiquement les proxies.

```bash
vagrant plugin install vagrant-proxyconf
```

**Configuration** :
```ruby
if Vagrant.has_plugin?("vagrant-proxyconf")
  config.proxy.http = "http://proxy.company.com:8080"
  config.proxy.https = "http://proxy.company.com:8080"
  config.proxy.no_proxy = "localhost,127.0.0.1"
end
```

#### **vagrant-disksize**

**Fonction** : Redimensionner le disque de la VM.

```bash
vagrant plugin install vagrant-disksize
```

**Configuration** :
```ruby
config.vm.box = "ubuntu/focal64"
config.disksize.size = '50GB'
```

---

## 🌍 Variables d'Environnement {#variables}

### Variables Importantes

#### `VAGRANT_HOME`

**Change l'emplacement des boxes et configurations globales**

```bash
# Par défaut : ~/.vagrant.d
export VAGRANT_HOME=/mnt/storage/vagrant
```

#### `VAGRANT_LOG`

**Active les logs de débogage**

```bash
# Niveaux : debug, info, warn, error
export VAGRANT_LOG=info
vagrant up

# Mode debug (très verbeux)
VAGRANT_LOG=debug vagrant up
```

#### `VAGRANT_CWD`

**Change le répertoire de travail**

```bash
# Lancer vagrant depuis un autre répertoire
VAGRANT_CWD=/path/to/project vagrant up
```

#### `VAGRANT_DEFAULT_PROVIDER`

**Définir le provider par défaut**

```bash
export VAGRANT_DEFAULT_PROVIDER=vmware_desktop
```

#### `VAGRANT_NO_PARALLEL`

**Désactiver le démarrage parallèle**

```bash
VAGRANT_NO_PARALLEL=1 vagrant up
```

---

## 🎓 Exercices Pratiques {#exercices}

### Exercice 1 : Premier Environnement

**Objectif** : Créer et manipuler une VM basique.

**Étapes** :
1. Créer un dossier `exercice1`
2. Initialiser Vagrant avec Ubuntu 20.04
3. Démarrer la VM
4. Se connecter en SSH
5. Vérifier la version d'Ubuntu
6. Créer un fichier texte dans `/vagrant`
7. Vérifier qu'il apparaît sur votre machine hôte
8. Arrêter la VM
9. Redémarrer la VM
10. Détruire la VM

**Solution** :
```bash
mkdir exercice1 && cd exercice1
vagrant init ubuntu/focal64
vagrant up
vagrant ssh
cat /etc/os-release
echo "Test" > /vagrant/test.txt
exit
cat test.txt  # Sur l'hôte
vagrant halt
vagrant up
vagrant destroy -f
```

### Exercice 2 : Configuration Réseau

**Objectif** : Configurer le réseau et accéder à un serveur web.

**Consignes** :
1. Créer un Vagrantfile avec Ubuntu 20.04
2. Rediriger le port 80 → 8080
3. Provisionner pour installer Apache
4. Créer une page HTML personnalisée
5. Accéder à `http://localhost:8080`

**Solution** :
```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.network "forwarded_port", guest: 80, host: 8080
  
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y apache2
    echo "<h1>Mon Serveur Apache</h1>" > /var/www/html/index.html
  SHELL
end
```

### Exercice 3 : Multi-Machine

**Objectif** : Créer une architecture web + DB.

**Consignes** :
1. Créer 2 VMs : `web` et `db`
2. Le serveur web doit avoir Nginx
3. Le serveur DB doit avoir PostgreSQL
4. Les deux doivent être sur un réseau privé
5. Le serveur web doit pouvoir ping le serveur DB

**Solution** :
```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  config.vm.define "web" do |web|
    web.vm.hostname = "web"
    web.vm.network "private_network", ip: "192.168.56.10"
    web.vm.provision "shell", inline: "apt-get update && apt-get install -y nginx"
  end
  
  config.vm.define "db" do |db|
    db.vm.hostname = "db"
    db.vm.network "private_network", ip: "192.168.56.11"
    db.vm.provision "shell", inline: "apt-get update && apt-get install -y postgresql"
  end
end
```

**Test** :
```bash
vagrant up
vagrant ssh web
ping -c 3 192.168.56.11
```

### Exercice 4 : Snapshots

**Objectif** : Utiliser les snapshots pour tester des configurations.

**Consignes** :
1. Créer une VM avec Ubuntu 20.04
2. Créer un snapshot `base`
3. Installer Nginx
4. Créer un snapshot `with-nginx`
5. Installer MySQL
6. Restaurer le snapshot `with-nginx`
7. Vérifier que MySQL n'est plus installé

**Solution** :
```bash
vagrant up
vagrant snapshot save base
vagrant ssh -c "sudo apt-get update && sudo apt-get install -y nginx"
vagrant snapshot save with-nginx
vagrant ssh -c "sudo apt-get install -y mysql-server"
vagrant snapshot restore with-nginx
vagrant ssh -c "which mysql"  # Ne doit rien retourner
```

### Exercice 5 : Projet Complet

**Objectif** : Créer un environnement de développement complet.

**Exigences** :
- Stack LEMP (Linux, Nginx, MySQL, PHP)
- Dossier de projet synchronisé
- Réseau privé + port forwarding
- Script de provisioning externe
- Documentation dans un README

**À vous de jouer !**

---

## 📚 Ressources Supplémentaires

- 📖 **Documentation officielle** : https://developer.hashicorp.com/vagrant
- 🎥 **Tutoriels** : https://developer.hashicorp.com/vagrant/tutorials
- 💬 **Forum communautaire** : https://discuss.hashicorp.com/c/vagrant
- 🐙 **GitHub** : https://github.com/hashicorp/vagrant
- 📦 **Vagrant Cloud** : https://app.vagrantup.com

---

**🎉 Félicitations ! Vous maîtrisez maintenant Vagrant !**