sudo apt-get update
sudo apt-get install openjdk-21-jdk -y

sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update
sudo apt-get install jenkins -y

systemctl status jenkins.service 
ls /var/lib/jenkins/
cat /var/lib/jenkins/secrets/initialAdminPassword




sudo apt update
curl -fsSL https://test.docker.com -o test-docker.sh
sudo sh test-docker.sh
sudo groupadd docker 
sudo usermod -aG docker "$USER"
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
sudo apt-get update -y
sudo apt-get install -y docker-compose-plugin
sudo docker compose version || true
