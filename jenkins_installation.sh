#!/bin/bash

# ------------------------------------------------------------------------------
# Jenkins LTS Installation Script for Debian/Ubuntu
#
# This script automates the installation and initial configuration of Jenkins LTS
# on Debian/Ubuntu systems. It performs the following steps:
#   1. Installs Java 21 (required for Jenkins LTS >= 2.426.1)
#   2. Adds the Jenkins Debian stable repository and imports its signing key
#   3. Installs Jenkins LTS
#   4. Enables and checks the Jenkins service status
#   5. Displays the initial Jenkins admin password for first-time setup
#   6. Installs Docker and Docker Compose for CI/CD and deployment environments
#   7. Installs Go (golang-go) for build environments
#   8. Provides manual steps for installing SonarQube Scanner plugin and configuring SonarQube integration
#
# The script is idempotent and safe to run multiple times.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# 1) Install Java 21 (required for Jenkins LTS >= 2.426.1)
#    - Updates package lists
#    - Installs OpenJDK 21, CA certificates, curl, and gnupg
# ------------------------------------------------------------------------------

sudo apt-get update -y
sudo apt-get install -y openjdk-21-jdk ca-certificates curl gnupg

# ------------------------------------------------------------------------------
# 2) Add Jenkins Debian Stable Repository and Import Signing Key
#    - Creates keyring directory for Jenkins
#    - Downloads and saves Jenkins repository signing key
#    - Adds Jenkins repository to apt sources
# ------------------------------------------------------------------------------

sudo mkdir -p /usr/share/keyrings
sudo chmod 755 /usr/share/keyrings

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
  sudo tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | \
  sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null

# ------------------------------------------------------------------------------
# 3) Install Jenkins LTS
#    - Updates package lists
#    - Installs Jenkins LTS package
# ------------------------------------------------------------------------------

sudo apt-get update -y
sudo apt-get install -y jenkins

# ------------------------------------------------------------------------------
# 4) Enable Jenkins Service, Start It, and Show Its Status
#    - Enables Jenkins to start on boot
#    - Displays Jenkins service status
# ------------------------------------------------------------------------------

sudo systemctl daemon-reload
sudo systemctl start jenkins
sudo systemctl enable jenkins
sudo systemctl status jenkins

# ------------------------------------------------------------------------------
# 5) Display Jenkins Initial Admin Password for Setup
#    - Attempts to access Jenkins web interface (optional)
#    - Lists Jenkins home directory contents
#    - Displays the initial admin password required for first login
# ------------------------------------------------------------------------------

curl http://192.168.56.50:8080 || true
ls -l /var/lib/jenkins/
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# ------------------------------------------------------------------------------
# 6) Install Docker and Docker Compose (for Jenkins and Deployment Environments)
#    - Installs Docker using official convenience script
#    - Adds current user and Jenkins user to 'docker' group for Docker access
#    - Starts and enables Docker and containerd services
#    - Installs Docker Compose plugin
#    - Sets permissions for /opt/docker directory
#    - Restarts Docker and Jenkins services to apply group changes
# ------------------------------------------------------------------------------

sudo apt update
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

sudo groupadd docker || true
sudo usermod -aG docker "$USER"

sudo systemctl start containerd.service
sudo systemctl enable docker.service
sudo systemctl start containerd.service
sudo systemctl enable containerd.service

sudo apt-get update -y
sudo apt-get install -y docker-compose-plugin

sudo chown -R root:jenkins /opt/docker
sudo usermod -aG docker jenkins
sudo systemctl restart docker
sudo systemctl restart jenkins

# ------------------------------------------------------------------------------
# 7) Install Go (golang-go)
#    - Installs Go programming language for build environments
# ------------------------------------------------------------------------------

sudo apt update 
sudo apt insrtall -y git
sudo apt install -y golang-go

# ------------------------------------------------------------------------------



# 8) Jenkins Plugins: Install SonarQube Scanner for Jenkins (Manual Step)
#    - In Jenkins UI:
#      1. Go to: Manage Jenkins → Plugins → Available
#      2. Search for "Go, SonarQube Scanner, for Jenkins"
#      3. Click "Install without restart" (or restart Jenkins after install)
#      4. Verify installation in: Manage Jenkins → Installed plugins → check "SonarQube Scanner"
#    - Note: Required for pipeline steps like `withSonarQubeEnv{}`
# ------------------------------------------------------------------------------

# 8.1) Jenkins Tools: Add Go Tool (Manual Step)
#    - In Jenkins UI:
#      1. Go to: Manage Jenkins → Tools → Go installations → Add go
#      2. Name: go1.22.0 
#      3. Install automatically from 
#      4. Version: go 1.22.0 
#      5. Save the tool configuration

# ------------------------------------------------------------------------------
# 9) Jenkins Credentials: Add SonarQube Token (Manual Step)
#    - In Jenkins UI:
#      1. Go to: Manage Jenkins → Credentials → Global → Add Credentials
#      2. Kind: Secret text
#      3. Secret: sqp_d0f54b46dd18fe531f335c85a9377e050ac164ea (generated from SonarQube user account)
#      4. ID: sonar-token (used in pipeline via credentials('sonar-token'))
#      5. Description: SonarQube authentication token
#      6. Save the credential
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# 10) Jenkins System Configuration: Add SonarQube Server (Manual Step)
#    - In Jenkins UI:
#      1. Go to: Manage Jenkins → System → SonarQube servers → Add SonarQube
#      2. Name: SonarQube-Server (used in pipeline with withSonarQubeEnv('SonarQube-Server'))
#      3. Server URL: http(s)://<your-sonarqube-host>
#      4. Server authentication token: Select Jenkins credential ID (see step 9)
#      5. Enable injection of SonarQube server configuration as build environment
#      6. Save the configuration
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# 11) Jenkins Tools: Add SonarQube Scanner Tool (Manual Step)
#    - In Jenkins UI:
#      1. Go to: Manage Jenkins → Tools → SonarQube Scanner installations → Add SonarQube Scanner
#      2. Name: SonarQubeServer (used in pipeline as tool 'SonarQubeServer')
#      3. Install automatically from Maven Central
#      4. Version: SonarQube Scanner 7.2.0.5079
#      5. Save the tool configuration
# ------------------------------------------------------------------------------



export SONAR_SCANNER_VERSION=7.2.0.5079
export SONAR_SCANNER_HOME=$HOME/.sonar/sonar-scanner-$SONAR_SCANNER_VERSION-linux-x64
curl --create-dirs -sSLo $HOME/.sonar/sonar-scanner.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-$SONAR_SCANNER_VERSION-linux-x64.zip
unzip -o $HOME/.sonar/sonar-scanner.zip -d $HOME/.sonar/
export PATH=$SONAR_SCANNER_HOME/bin:$PATH


/usr/local/sonar/bin/sonar-scanner \
  -X \
  -Dsonar.projectKey=go-app-calculator \
  -Dsonar.sources=. \
  -Dsonar.host.url=http://192.168.56.52 \
  -Dsonar.login=sqp_d0f54b46dd18fe531f335c85a9377e050ac164ea \
  -Dsonar.go.coverage.reportPaths=coverage.out






