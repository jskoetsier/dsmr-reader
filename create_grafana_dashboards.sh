#!/bin/bash
# Script to create Grafana dashboards for DSMR Reader

# Exit on error
set -e

echo "=== Creating Grafana Dashboards ==="

# Check if API key exists
if [ ! -f /home/dsmr/grafana_api_key.txt ]; then
    echo "API key file not found at /home/dsmr/grafana_api_key.txt"
    echo "Checking current directory..."
    
    if [ -f ./grafana_api_key.txt ]; then
        echo "Found API key file in current directory. Using it."
        source ./grafana_api_key.txt
    else
        echo "No API key file found. Would you like to create one now? (y/n)"
        read -r create_key
        
        if [ "$create_key" = "y" ]; then
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
                echo "Failed to create API key. Would you like to enter it manually? (y/n)"
                read -r manual_key
                
                if [ "$manual_key" = "y" ]; then
                    echo "Enter your Grafana API key:"
                    read -r API_KEY
                else
                    echo "Exiting. Please create an API key manually and try again."
                    exit 1
                fi
            fi
            
            echo "API_KEY=$API_KEY" > /home/dsmr/grafana_api_key.txt
            echo "API_KEY=$API_KEY" > ./grafana_api_key.txt
            chmod 644 /home/dsmr/grafana_api_key.txt
            chmod 644 ./grafana_api_key.txt
            echo "API key saved to /home/dsmr/grafana_api_key.txt and ./grafana_api_key.txt"
        else
            echo "Exiting. Please create an API key manually and try again."
            exit 1
        fi
    fi
else
    echo "Loading API key from /home/dsmr/grafana_api_key.txt"
    source /home/dsmr/grafana_api_key.txt
fi

# Verify API key was loaded
if [ -z "$API_KEY" ]; then
    echo "API key not found in the file. Would you like to enter it manually? (y/n)"
    read -r manual_key
    
    if [ "$manual_key" = "y" ]; then
        echo "Enter your Grafana API key:"
        read -r API_KEY
        echo "API_KEY=$API_KEY" > /home/dsmr/grafana_api_key.txt
        echo "API_KEY=$API_KEY" > ./grafana_api_key.txt
        chmod 644 /home/dsmr/grafana_api_key.txt
        chmod 644 ./grafana_api_key.txt
    else
        echo "Exiting. Please make sure the file contains: API_KEY=your_key_here"
        exit 1
    fi
fi

echo "API key loaded successfully."

# Create dashboards directory if it doesn't exist
mkdir -p /home/dsmr/grafana-dashboards

# Function to create and import a dashboard
create_dashboard() {
    local name=$1
    local file=$2
    local dashboard_json=$3
    
    echo "Creating $name dashboard..."
    echo "$dashboard_json" > "$file"
    
    # Import dashboard to Grafana
    curl -X POST -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d "{
      \"dashboard\": $(cat $file),
      \"overwrite\": true,
      \"folderId\": 0
    }" http://localhost:3000/api/dashboards/db
    
    echo "$name dashboard created and imported."
}

# Dashboard file paths
ELECTRICITY_DASHBOARD_FILE="/home/dsmr/grafana-dashboards/electricity_usage.json"
PHASE_USAGE_DASHBOARD_FILE="/home/dsmr/grafana-dashboards/phase_usage.json"
PHASE_VOLTAGES_DASHBOARD_FILE="/home/dsmr/grafana-dashboards/phase_voltages.json"
PHASE_CURRENTS_DASHBOARD_FILE="/home/dsmr/grafana-dashboards/phase_currents.json"
GAS_DASHBOARD_FILE="/home/dsmr/grafana-dashboards/gas_consumption.json"