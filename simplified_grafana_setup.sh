#!/bin/bash
# Simplified script to set up Grafana with DSMR Reader

set -e

echo "=== Simplified Grafana Setup ==="

# Check if Grafana is installed
if ! systemctl is-active --quiet grafana-server; then
    echo "Grafana server is not running. Please install Grafana first."
    exit 1
fi

# Get API key
echo "Enter your Grafana API key (or press Enter to create a new one):"
read -r API_KEY

if [ -z "$API_KEY" ]; then
    echo "Enter Grafana admin username (default: admin):"
    read -r admin_user
    admin_user=${admin_user:-admin}
    
    echo "Enter Grafana admin password:"
    read -rs admin_pass
    
    echo "Creating API key..."
    SERVER_IP=$(hostname -I | awk '{print $1}')
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="localhost"
    fi
    
    API_KEY=$(curl -s -X POST -H "Content-Type: application/json" -d '{"name":"dsmr-reader-key", "role": "Admin"}' http://$admin_user:$admin_pass@$SERVER_IP:3000/api/auth/keys | grep -o '"key":"[^"]*' | grep -o '[^"]*$')
    
    if [ -z "$API_KEY" ]; then
        echo "Failed to create API key automatically."
        echo "Please create an API key manually in Grafana (Configuration -> API Keys)"
        echo "Then run this script again with the API key."
        exit 1
    fi
    
    echo "API key created successfully."
fi

# Create data source
echo "Setting up PostgreSQL data source..."

# Get PostgreSQL credentials
echo "Enter PostgreSQL database name (default: dsmrreader):"
read -r db_name
db_name=${db_name:-dsmrreader}

echo "Enter PostgreSQL username (default: dsmrreader):"
read -r db_user
db_user=${db_user:-dsmrreader}

echo "Enter PostgreSQL password:"
read -rs db_pass

echo "Enter PostgreSQL host (default: localhost):"
read -r db_host
db_host=${db_host:-localhost}

echo "Enter PostgreSQL port (default: 5432):"
read -r db_port
db_port=${db_port:-5432}

# Create data source
echo "Creating PostgreSQL data source..."
curl -s -X POST -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d '{
  "name": "DSMR Reader",
  "type": "postgres",
  "url": "'$db_host':'$db_port'",
  "access": "proxy",
  "user": "'$db_user'",
  "database": "'$db_name'",
  "password": "'$db_pass'",
  "isDefault": true,
  "jsonData": {
    "sslmode": "disable",
    "postgresVersion": 1200,
    "timescaledb": false
  }
}' http://localhost:3000/api/datasources

# Create basic electricity dashboard
echo "Creating basic electricity dashboard..."
curl -s -X POST -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d '{
  "dashboard": {
    "id": null,
    "title": "Electricity Usage",
    "tags": ["dsmr", "electricity"],
    "timezone": "browser",
    "schemaVersion": 22,
    "version": 1,
    "refresh": "5s",
    "panels": [
      {
        "id": 1,
        "title": "Electricity Usage (kW)",
        "type": "graph",
        "datasource": "DSMR Reader",
        "gridPos": {
          "h": 9,
          "w": 24,
          "x": 0,
          "y": 0
        },
        "targets": [
          {
            "format": "time_series",
            "rawQuery": true,
            "rawSql": "SELECT read_at AS \"time\", currently_delivered AS \"Delivered\", currently_returned AS \"Returned\" FROM dsmr_consumption_electricityconsumption WHERE $__timeFilter(read_at) ORDER BY read_at ASC",
            "refId": "A"
          }
        ],
        "xaxis": {
          "mode": "time"
        },
        "yaxes": [
          {
            "format": "kwatt"
          },
          {
            "format": "short"
          }
        ]
      }
    ],
    "time": {
      "from": "now-24h",
      "to": "now"
    }
  },
  "overwrite": true,
  "folderId": 0
}' http://localhost:3000/api/dashboards/db

echo "Setup complete! You can now access your Grafana dashboard at http://localhost:3000"
echo "Default login is admin/admin if you haven't changed it yet."