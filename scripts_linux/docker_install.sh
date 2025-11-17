#!/bin/bash

set -e

# Détection de la distribution
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO=$ID
  VERSION=$VERSION_ID
else
  echo "Impossible de détecter la distribution Linux."
  exit 1
fi

echo "Distribution détectée : $DISTRO $VERSION"

install_docker_debian_ubuntu() {
  echo "Installation Docker pour Debian/Ubuntu..."
  sudo apt update
  sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

  # Ajout clé GPG officielle Docker
  curl -fsSL https://download.docker.com/linux/${DISTRO}/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

  # Ajout dépôt stable Docker
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/${DISTRO} \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io

  sudo systemctl enable --now docker
}

install_docker_centos_fedora() {
  echo "Installation Docker pour CentOS/Fedora..."
  sudo dnf -y install dnf-plugins-core
  sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  sudo dnf install -y docker-ce docker-ce-cli containerd.io
  sudo systemctl enable --now docker
}

install_docker_rocky_alma() {
  echo "Installation Docker pour RockyLinux/AlmaLinux..."
  sudo yum -y install yum-utils
  sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  sudo yum install -y docker-ce docker-ce-cli containerd.io
  sudo systemctl enable --now docker
}

case "$DISTRO" in
  debian|ubuntu)
    install_docker_debian_ubuntu
    ;;
  centos)
    install_docker_centos_fedora
    ;;
  fedora)
    install_docker_centos_fedora
    ;;
  rocky|almalinux)
    install_docker_rocky_alma
    ;;
  *)
    echo "Distribution $DISTRO non prise en charge par ce script."
    exit 1
    ;;
esac

echo "Installation Docker terminée."
docker --version
sudo docker run --rm hello-world
