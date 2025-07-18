#!/bin/bash
# Script to install Grafana and set up dashboards for DSMR Reader

# Exit on error
set -e

echo "=== Installing Grafana ==="

# Add Grafana APT repository
echo "Adding Grafana repository..."
sudo apt-get install -y apt-transport-https software-properties-common wget gnupg curl

# Try a direct approach for adding the repository key
echo "Adding Grafana repository key..."
# Download the key directly from Grafana website
curl -fsSL https://packages.grafana.com/gpg.key | sudo apt-key add -

echo "Adding Grafana repository to sources..."
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list > /dev/null

# Update package list and install Grafana
echo "Installing Grafana..."
sudo apt-get update
sudo apt-get install -y grafana

# Start Grafana service and enable it to start at boot
echo "Starting Grafana service..."
sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

# Wait for Grafana to start
echo "Waiting for Grafana to start..."
sleep 10

# Create API key for automated dashboard provisioning
echo "Setting up Grafana API key..."
API_KEY=$(curl -X POST -H "Content-Type: application/json" -d '{"name":"dsmr-reader-key", "role": "Admin"}' http://admin:admin@localhost:3000/api/auth/keys | grep -o '"key":"[^"]*' | grep -o '[^"]*$')

if [ -z "$API_KEY" ]; then
    echo "Failed to create API key. Please check Grafana is running and accessible."
    exit 1
fi

echo "API Key created: $API_KEY"
echo "API_KEY=$API_KEY" > /home/dsmr/grafana_api_key.txt

# Get PostgreSQL connection details from DSMR Reader
echo "Getting database connection details..."
DB_NAME=$(grep -A 5 "DATABASES" /home/dsmr/dsmr-reader/dsmrreader/settings.py | grep "NAME" | cut -d "'" -f 4)
DB_USER=$(grep -A 5 "DATABASES" /home/dsmr/dsmr-reader/dsmrreader/settings.py | grep "USER" | cut -d "'" -f 4)
DB_PASS=$(grep -A 5 "DATABASES" /home/dsmr/dsmr-reader/dsmrreader/settings.py | grep "PASSWORD" | cut -d "'" -f 4)
DB_HOST=$(grep -A 5 "DATABASES" /home/dsmr/dsmr-reader/dsmrreader/settings.py | grep "HOST" | cut -d "'" -f 4)
DB_PORT=$(grep -A 5 "DATABASES" /home/dsmr/dsmr-reader/dsmrreader/settings.py | grep "PORT" | cut -d "'" -f 4)

if [ -z "$DB_PORT" ]; then
    DB_PORT="5432"
fi

if [ -z "$DB_HOST" ]; then
    DB_HOST="localhost"
fi

# Create PostgreSQL data source
echo "Creating PostgreSQL data source..."
curl -X POST -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d '{
  "name": "DSMR Reader",
  "type": "postgres",
  "url": "'$DB_HOST':'$DB_PORT'",
  "access": "proxy",
  "basicAuth": false,
  "database": "'$DB_NAME'",
  "user": "'$DB_USER'",
  "password": "'$DB_PASS'",
  "jsonData": {
    "sslmode": "disable",
    "postgresVersion": 1200,
    "timescaledb": false
  }
}' http://localhost:3000/api/datasources

# Create dashboards directory
mkdir -p /home/dsmr/grafana-dashboards

echo "=== Grafana installation complete ==="
echo "Grafana is now installed and running at http://your-server-ip:3000"
echo "Default login credentials: admin/admin"
echo "PostgreSQL data source has been configured"
echo "Dashboard JSON files will be created in /home/dsmr/grafana-dashboards"
echo ""
echo "Next steps:"
echo "1. Run the create_grafana_dashboards.sh script to create dashboards"
echo "2. Access Grafana at http://your-server-ip:3000"
echo "3. Change the default admin password"