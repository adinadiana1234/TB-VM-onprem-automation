#!/bin/bash

LOG_FILE="/var/log/install_thingsboard.log"
exec > >(tee -i $LOG_FILE)
exec 2>&1

echo "Starting install_thingsboard.sh script."

# Define variables
PGPASS_FILE=~/.pgpass
POSTGRES_PASSWORD="${postgres_password}"
DB_NAME='thingsboard'
PG_HOST='127.0.0.1'
PG_PORT='5432'
PG_USER='postgres'
THINGSBOARD_CONF="/etc/thingsboard/conf/thingsboard.conf"
TB_QUEUE_TYPE="kafka"
TB_KAFKA_SERVERS="localhost:9092"

echo "Configuring PostgreSQL password."

# Function to create and set permissions for .pgpass file
create_pgpass_file() {
    echo "$PG_HOST:$PG_PORT:*:$PG_USER:$POSTGRES_PASSWORD" > "$PGPASS_FILE"
    chmod 600 "$PGPASS_FILE"
    echo ".pgpass file created and permissions set."
}

if [ $? -ne 0 ]; then
  echo "Failed to configure PostgreSQL password"
  exit 1
fi

# Function to check if command succeeded
check_command_status() {
    if [ $? -eq 0 ]; then
        echo "$1"
    else
        echo "Failed to $1"
        exit 1
    fi
}

# Prerequisites
sudo yum install -y nano wget
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm


## Install Java 11 (OpenJDK)
sudo yum install -y java-11-openjdk

# ThingsBoard service installation
wget https://github.com/thingsboard/thingsboard/releases/download/v3.6.4/thingsboard-3.6.4.rpm
sudo rpm -Uvh thingsboard-3.6.4.rpm

# PostgreSQL installation and configuration
#sudo yum update -y
sudo yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo dnf -qy module disable postgresql
sudo dnf -y install postgresql15 postgresql15-server
sudo /usr/pgsql-15/bin/postgresql-15-setup initdb
sudo systemctl start postgresql-15
sudo systemctl enable --now postgresql-15
sudo -i -u postgres psql -c "ALTER USER $PG_USER PASSWORD '$POSTGRES_PASSWORD';"
create_pgpass_file
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
check_command_status "Database '$DB_NAME' has been created successfully."

# Configure ThingsBoard database
sudo bash -c "cat >> $THINGSBOARD_CONF <<EOL
# DB Configuration
export DATABASE_TS_TYPE=sql
export SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/thingsboard
export SPRING_DATASOURCE_USERNAME=postgres
export SPRING_DATASOURCE_PASSWORD=$POSTGRES_PASSWORD
# Specify partitioning size for timestamp key-value storage. Allowed values: DAYS, MONTHS, YEARS, INDEFINITE.
export SQL_POSTGRES_TS_KV_PARTITIONING=MONTHS
EOL"
check_command_status "Update ThingsBoard configuration with database information."

# Choose ThingsBoard queue service (Install Kafka)
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install Docker Compose (if not included in docker-compose-plugin)
echo "Installing docker-compose."
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Configure kafka
mkdir kafka-install
cd kafka-install
cat << EOF > docker-compose.yml
version: '3'
services:
  zookeeper:
    image: wurstmeister/zookeeper
    container_name: zookeeper
    ports:
      - "2181:2181"
  kafka:
    image: wurstmeister/kafka
    container_name: kafka
    ports:
      - "9092:9092"
    environment:
      KAFKA_ADVERTISED_HOST_NAME: localhost
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
EOF

check_command_status "Create docker-compose.yml file"
sudo systemctl enable docker
sudo systemctl start docker

# Create the systemd service file for Docker Compose
echo "Creating systemd service file for Docker Compose..."
sudo bash -c 'cat <<EOL > /etc/systemd/system/docker-compose.service
[Unit]
Description=Docker Compose Application Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/kafka-install
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down

[Install]
WantedBy=multi-user.target
EOL'

# Reload systemd to read the new service file
echo "Reloading systemd."
sudo systemctl daemon-reload

# Enable the Docker Compose service to start on boot
echo "Enabling Docker Compose service."
sudo systemctl enable docker-compose

# Start the Docker Compose service
echo "Starting Docker Compose service."
sudo systemctl start docker-compose

# Check the status of the Docker Compose service
echo "Checking the status of Docker Compose service."
sudo systemctl status docker-compose

echo "Docker Compose service setup complete."

check_command_status "Start Docker service"
sleep 30
sudo docker-compose up -d

echo "docker compose1"
check_command_status "Execute Docker Compose up command"

# Append the lines to the end of the thingsboard.conf file
echo "Appending Kafka lines to thingsboard.conf file."
sudo bash -c "cat >> $THINGSBOARD_CONF <<EOL
export TB_QUEUE_TYPE=$TB_QUEUE_TYPE
export TB_KAFKA_SERVERS=$TB_KAFKA_SERVERS
EOL"

# Run installation script
echo "Running install script to load demo data: users, devices, assets, rules, widgets."
cd /usr/share/thingsboard/bin/install
sudo ./install.sh --loadDemo

# Configure firewall and start ThingsBoard service ##
echo "Configuring firewall to have port 8080 accessible."
sudo systemctl stop firewalld
sudo firewall-offline-cmd --zone=public --add-port=8080/tcp
sudo systemctl start firewalld

sudo service thingsboard start

echo "Installation complete. Please allow up to 90 seconds for the Web UI to start."