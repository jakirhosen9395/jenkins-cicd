#!/bin/bash
# ==============================================================================
# SonarQube Server Setup Script (Community Edition, no variables)
# Installs and configures SonarQube CE, PostgreSQL, Java, and Nginx reverse proxy
# Tested on Debian/Ubuntu
# ==============================================================================

set -euo pipefail  # Exit on error, unset variable, or failed pipeline

#------------------------------------------------------------------------------
# 1) OS Prerequisites
#------------------------------------------------------------------------------

# Increase the maximum number of virtual memory map areas for Elasticsearch.
# SonarQube requires vm.max_map_count >= 262144, otherwise it will fail bootstrap checks.
# This sets the value permanently in /etc/sysctl.conf.
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Reload sysctl settings to apply changes immediately, without reboot.
sudo sysctl -p

# Set file descriptor and process/thread limits for the 'sonar' user.
# This is required for SonarQube to handle enough files and processes.
# The configuration is placed in /etc/security/limits.d/99-sonarqube.conf.
sudo tee /etc/security/limits.d/99-sonarqube.conf >/dev/null <<'EOF'
sonar   soft   nofile  65536   
sonar   hard   nofile  65536   
sonar   soft   nproc   4096    
sonar   hard   nproc   4096    
EOF

#------------------------------------------------------------------------------
# 2) Install Java 17 and tools
#------------------------------------------------------------------------------

# Update package lists
sudo apt-get update -y

# Install OpenJDK 17, unzip, curl, and CA certificates
sudo apt-get install -y openjdk-17-jdk unzip curl ca-certificates

# Verify Java installation
java -version

#------------------------------------------------------------------------------
# 3) Install and Configure PostgreSQL
#------------------------------------------------------------------------------

# Install PostgreSQL and its contrib package
sudo apt-get install -y postgresql postgresql-contrib

# Enable PostgreSQL to start on boot
sudo systemctl enable postgresql

# Switch to the postgres user and configure SonarQube database and user
# The following commands create a new role and database for SonarQube
sudo -u postgres psql 
CREATE ROLE sonar WITH LOGIN ENCRYPTED PASSWORD 'ChangeMe_SonarDB_#2025';
CREATE DATABASE sonarqube OWNER sonar;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;
\q

#------------------------------------------------------------------------------
# 4) Create user/group and install SonarQube Community Edition
#------------------------------------------------------------------------------

# Create 'sonar' group if it doesn't exist
sudo groupadd --force sonar

# Create 'sonar' user with no login shell and home directory at /opt/sonarqube
sudo useradd -r -s /bin/false -g sonar -d /opt/sonarqube sonar

# Display 'sonar' user info for verification
id sonar

# Download SonarQube CE zip archive to /tmp
cd /tmp
curl -fL -o sonarqube-25.9.0.112764.zip \
        https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-25.9.0.112764.zip

# Unzip SonarQube to /opt
sudo unzip -q sonarqube-25.9.0.112764.zip -d /opt/

# Remove any previous installation
sudo rm -rf /opt/sonarqube

# Move SonarQube files to /opt/sonarqube
sudo mv /opt/sonarqube-25.9.0.112764 /opt/sonarqube

# Set permissions for SonarQube directory
sudo chown -R sonar:sonar /opt/sonarqube
sudo chmod -R 755 /opt/sonarqube

#------------------------------------------------------------------------------
# 5) Configure SonarQube
#------------------------------------------------------------------------------

# Create SonarQube configuration file with database and server settings
sudo tee /opt/sonarqube/conf/sonar.properties >/dev/null <<'EOF'
# Database connection settings
sonar.jdbc.username=sonar
sonar.jdbc.password=ChangeMe_SonarDB_#2025
sonar.jdbc.url=jdbc:postgresql://127.0.0.1/sonarqube

# Web server settings
sonar.web.host=0.0.0.0
sonar.web.port=9000

# Elasticsearch JVM options
sonar.search.javaOpts=-Xms1G -Xmx1G -XX:+HeapDumpOnOutOfMemoryError

# Logging settings
sonar.log.level=INFO
sonar.path.logs=logs
EOF

# Set ownership of the configuration file to 'sonar' user
sudo chown sonar:sonar /opt/sonarqube/conf/sonar.properties

# Create systemd unit file for SonarQube service
sudo tee /etc/systemd/system/sonarqube.service >/dev/null <<'EOF'
[Unit]
Description=SonarQube service (Community Edition)
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

# Reload systemd to recognize the new service
sudo systemctl daemon-reload

# Enable SonarQube service
sudo systemctl enable sonarqube

# Start SonarQube service
sudo systemctl start sonarqube

# Show SonarQube service status
sudo systemctl status sonarqube 

#------------------------------------------------------------------------------
# 6) Optional: Nginx reverse proxy on :80 -> :9000
#------------------------------------------------------------------------------

# Install Nginx web server
sudo apt-get install -y nginx

# Remove default Nginx site configuration
sudo rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default

# Create Nginx site configuration for SonarQube reverse proxy
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

# Enable the SonarQube site
sudo ln -sf /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube

# Test Nginx configuration
sudo nginx -t

# Enable Nginx service
sudo systemctl enable nginx

# Restart Nginx service
sudo systemctl restart nginx

# Show Nginx service status
sudo systemctl status nginx

# Allow HTTP traffic through firewall (ignore error if ufw is not installed)
sudo ufw allow 80/tcp || true
sudo ufw enable
sudo ufw status verbose

#------------------------------------------------------------------------------
# 7) Access Information
#------------------------------------------------------------------------------

# Print SonarQube UI URL and default credentials
echo "UI:  http://192.168.56.52:9000/"
echo "Default login: admin / admin"
echo "Change password to: Sonarqube!123"
