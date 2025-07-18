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
        echo "No API key file found. You can create one manually:"
        echo "1. Access Grafana at http://192.168.1.172:3000"
        echo "2. Log in with admin/admin"
        echo "3. Go to Configuration > API Keys"
        echo "4. Create a new key with Admin permissions"
        echo "5. Create a file at /home/dsmr/grafana_api_key.txt with content: API_KEY=your_key_here"
        echo "6. Run this script again"
        exit 1
    fi
else
    echo "Loading API key from /home/dsmr/grafana_api_key.txt"
    source /home/dsmr/grafana_api_key.txt
fi

# Verify API key was loaded
if [ -z "$API_KEY" ]; then
    echo "API key not found in the file. Please make sure the file contains: API_KEY=your_key_here"
    exit 1
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