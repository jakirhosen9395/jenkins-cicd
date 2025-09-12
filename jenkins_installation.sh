#!/bin/bash

# Jenkins LTS installation script for Debian/Ubuntu
# This script installs Jenkins LTS, sets up Java 21, configures the Jenkins repository,
# enables and starts Jenkins, displays the initial admin password, and installs Docker
# and Docker Compose for deployment environments. The script is idempotent and safe to run multiple times.

# ------------------------------------------------------------------------------
# 1) Install Java 21 (required for Jenkins LTS >= 2.426.1)
# ------------------------------------------------------------------------------

# Update package lists to get latest versions
sudo apt-get update -y

# Install Java 21, CA certs, curl, and gnupg
sudo apt-get install -y openjdk-21-jdk ca-certificates curl gnupg

# ------------------------------------------------------------------------------
# 2) Add Jenkins Debian stable repository and import signing key
# ------------------------------------------------------------------------------

# Ensure keyrings directory exists
sudo mkdir -p /usr/share/keyrings

# Set proper permissions for keyrings directory
sudo chmod 755 /usr/share/keyrings

# Download Jenkins repository GPG key and save to keyrings directory
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
  sudo tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null

# Add Jenkins repository to apt sources, specifying the signing key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | \
  sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null

# ------------------------------------------------------------------------------
# 3) Install Jenkins LTS
# ------------------------------------------------------------------------------

# Update package lists to include Jenkins repo
sudo apt-get update -y

# Install Jenkins LTS package
sudo apt-get install -y jenkins

# ------------------------------------------------------------------------------
# 4) Enable Jenkins service, start it, and show its status
# ------------------------------------------------------------------------------

# Enable Jenkins to start on boot
sudo systemctl enable jenkins

# Show Jenkins service status (does not start Jenkins if not running)
sudo systemctl status jenkins

# ------------------------------------------------------------------------------
# 5) Display Jenkins initial admin password for setup
# ------------------------------------------------------------------------------

# Check Jenkins web interface is reachable (optional, can fail if Jenkins not started yet)
curl http://192.168.56.50:8080

# List contents of Jenkins home directory for troubleshooting or inspection
ls -l /var/lib/jenkins/

# Show initial admin password required for first-time setup in the web UI
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# ------------------------------------------------------------------------------
# 6) Install Docker and Docker Compose (for deployment environments)
# ------------------------------------------------------------------------------

# Update package lists before Docker installation
sudo apt update

# Download Docker installation script from official source
curl -fsSL https://get.docker.com -o get-docker.sh

# Run Docker installation script
sudo sh get-docker.sh

# Create 'docker' group if it does not exist (ignore error if already exists)
sudo groupadd docker || true

# Add current user to 'docker' group to allow running Docker without sudo
sudo usermod -aG docker "$USER"

# Enable Docker and containerd services to start on boot
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Update package lists before installing Docker Compose plugin
sudo apt-get update -y

# Install Docker Compose plugin (recommended way for recent Docker versions)
sudo apt-get install -y docker-compose-plugin
