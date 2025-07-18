#!/bin/bash
# Script to create Grafana dashboards for DSMR Reader

# Exit on error
set -e

echo "=== Creating Grafana Dashboards ==="

# Check if API key exists
if [ ! -f /home/dsmr/grafana_api_key.txt ]; then
    echo "API key file not found. Please run install_grafana.sh first."
    exit 1
fi

# Load API key
source /home/dsmr/grafana_api_key.txt

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