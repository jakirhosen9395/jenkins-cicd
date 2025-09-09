#!/bin/bash
# ==============================================================================
# SonarQube Server Setup Script
# Installs and configures SonarQube, PostgreSQL, Java, and Nginx reverse proxy
# ==============================================================================

#------------------------------------------------------------------------------
# 0. Environment Variables
#------------------------------------------------------------------------------
export SQ_VER="2025.1.3.110580"
export SQ_USER="sonar"
export SQ_GROUP="sonar"
export SQ_HOME="/opt/sonarqube"
export SQ_ZIP="sonarqube-developer-${SQ_VER}.zip"
export DB_NAME="sonarqube"
export DB_USER="sonar"
export DB_PASS="ChangeMe_SonarDB_#2025"
export SQ_URL="https://binaries.sonarsource.com/CommercialDistribution/sonarqube-developer/${SQ_ZIP}"


#------------------------------------------------------------------------------
# 1. OS Prerequisites
#------------------------------------------------------------------------------
# vm.max_map_count set (for Elasticsearch)
echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-sonarqube.conf >/dev/null
sudo sysctl --system

# limits (nofile/nproc) for sonar user only
sudo tee /etc/security/limits.d/99-sonarqube.conf >/dev/null <<'EOF'
sonar   soft   nofile  65536
sonar   hard   nofile  65536
sonar   soft   nproc   4096
sonar   hard   nproc   4096
EOF


#------------------------------------------------------------------------------
# 2. Install Java 17
#------------------------------------------------------------------------------
sudo apt-get update -y
sudo apt-get install -y openjdk-17-jdk unzip
java -version


#------------------------------------------------------------------------------
# 3. Install and Configure PostgreSQL Database
#------------------------------------------------------------------------------
sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable --now postgresql

sudo -u postgres psql
CREATE USER sonar WITH ENCRYPTED PASSWORD 'ChangeMe_SonarDB_#2025';
CREATE DATABASE sonarqube OWNER sonar;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;
exit;

#------------------------------------------------------------------------------
# 4. Download and Install SonarQube
#------------------------------------------------------------------------------
sudo groupadd --force sonar
id -u sonar >/dev/null 2>&1 || sudo useradd -r -s /bin/false -g sonar -d /opt/sonarqube sonar

cd /tmp
curl -fL -o sonarqube-developer-2025.1.3.110580.zip \
    https://binaries.sonarsource.com/CommercialDistribution/sonarqube-developer/sonarqube-developer-2025.1.3.110580.zip

sudo unzip -q sonarqube-developer-2025.1.3.110580.zip -d /opt/
sudo rm -rf /opt/sonarqube
sudo mv /opt/sonarqube-developer-2025.1.3.110580 /opt/sonarqube
sudo chown -R sonar:sonar /opt/sonarqube
sudo chmod -R 755 /opt/sonarqube


#------------------------------------------------------------------------------
# 5. SonarQube Configuration
#------------------------------------------------------------------------------
# 5.1 Configure sonar.properties
sudo tee /opt/sonarqube/conf/sonar.properties >/dev/null <<'EOF'
# Database
sonar.jdbc.username=sonar
sonar.jdbc.password=ChangeMe_SonarDB_#2025
sonar.jdbc.url=jdbc:postgresql://127.0.0.1/sonarqube

# Web
sonar.web.host=0.0.0.0
sonar.web.port=9000

# Search (Elasticsearch)
sonar.search.javaOpts=-Xms1G -Xmx1G -XX:+HeapDumpOnOutOfMemoryError

# Logs
sonar.log.level=INFO
sonar.path.logs=logs
EOF
sudo chown sonar:sonar /opt/sonarqube/conf/sonar.properties

# 5.2 Create systemd service file
sudo tee /etc/systemd/system/sonarqube.service >/dev/null <<'EOF'
[Unit]
Description=SonarQube service
After=network.target syslog.target
Wants=network.target

[Service]
Type=forking
User=sonar
Group=sonar
WorkingDirectory=/opt/sonarqube
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
Restart=on-failure
LimitNOFILE=65536
LimitNPROC=4096
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now sonarqube
sudo systemctl status --no-pager -l sonarqube


#------------------------------------------------------------------------------
# 6. (Optional) Install and Configure Nginx Reverse Proxy
#------------------------------------------------------------------------------
sudo apt-get install -y nginx
sudo rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default

sudo tee /etc/nginx/sites-available/sonarqube >/dev/null <<'EOF'
server {
        listen 80;
        server_name sonarqube.example.com;

        access_log /var/log/nginx/sonar.access.log;
        error_log  /var/log/nginx/sonar.error.log;

        location / {
                proxy_set_header Host              $host;
                proxy_set_header X-Real-IP         $remote_addr;
                proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto http;
                proxy_pass http://127.0.0.1:9000;
                proxy_read_timeout 300;
        }
}
EOF

sudo ln -sf /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
sudo nginx -t && sudo systemctl enable --now nginx
sudo ufw allow 80/tcp || true

#------------------------------------------------------------------------------
# 7. Access SonarQube
#------------------------------------------------------------------------------
# URL: 
http://192.168.56.52:9000/
# Default Password: 
admin
# New Password:
Sonarqube!123


#------------------------------------------------------------------------------
# 8. jenkins plugings and tools management
#------------------------------------------------------------------------------
# login to jenkins -> settings -> plugins -> manage plugins -> available
# install below plugins
# 1. sonarQube Scanner
# settings -> tools -> sonarQube Scanner -> SonarQube Scanner installations
# name: sonar7.2
# Install from Maven Central version: 7.2.0.5079
# Apply and save
# settings -> configure system -> SonarQube servers
# check the box: environment variables
# add SonarQube
# name: SonarQube-Server
# server URL: http://192.168.56.52:80 / private ip for cloud server
#------------------------------------------------------------------------------
# 9. SonarQube Server Token Generation for Jenkins Authentication
#------------------------------------------------------------------------------
# To authenticate Jenkins with SonarQube, you need a server token:
# 1. Log into the SonarQube web interface.
# 2. Click on your account icon (usually labeled "A" for admin) in the top right.
# 3. Select "My Account" -> "Security".
# 4. Under "Generate Tokens", enter a name (e.g., "Jenkins").
# 5. Select token type as "User Token".
# 6. Click "Generate".
# 7. Copy the token immediately; it will only be shown once.
#    If you lose it, you must generate a new token.
# 8. Use this token in Jenkins when configuring SonarQube server authentication.
#------------------------------------------------------------------------------
# 10. Storing the Token in Jenkins
#------------------------------------------------------------------------------
# 1. In Jenkins, navigate to "Manage Jenkins" -> "Credentials".
# 2. Click "(global)" -> "Add Credentials".
# 3. Select "Secret Text" as the Kind.
# 4. Paste the SonarQube token into the "Secret" field.
# 5. Set an ID (e.g., "sonartoken") and provide a description.
# 6. Click "OK" to save.
# 7. In "Configure System" -> "SonarQube-servers", select this credential from the dropdown for authentication.