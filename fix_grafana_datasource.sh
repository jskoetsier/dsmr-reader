#!/bin/bash

echo "=== DSMR Reader Grafana Data Source Fix ==="
echo "This script will fix the Grafana data source configuration to ensure dashboards show data"

# Configuration
GRAFANA_URL="http://localhost:3000"
POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"
POSTGRES_DB="dsmrreader"
POSTGRES_USER="dsmrreader"
POSTGRES_PASSWORD="dsmrreader"  # Change this if your PostgreSQL password is different

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo "ERROR: curl is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "WARNING: jq is not installed. This script will work better with jq installed."
    echo "Installing jq..."
    sudo apt-get update && sudo apt-get install -y jq
    if [ $? -ne 0 ]; then
        echo "Failed to install jq. Continuing without it, but some functionality may be limited."
    fi
fi

# Function to prompt for API key
get_api_key() {
    echo "Please enter your Grafana API key (or create one in Grafana UI > Configuration > API Keys):"
    read -s API_KEY
    
    if [ -z "$API_KEY" ]; then
        echo "No API key provided. Please create one in Grafana UI and try again."
        exit 1
    fi
    
    echo "Testing API key..."
    response=$(curl -s -H "Authorization: Bearer $API_KEY" "$GRAFANA_URL/api/datasources")
    
    if [[ "$response" == *"Invalid API key"* ]] || [[ "$response" == *"Unauthorized"* ]]; then
        echo "ERROR: Invalid API key. Please check and try again."
        exit 1
    fi
    
    echo "API key is valid!"
    return 0
}

# Get API key
get_api_key

# Check if PostgreSQL datasource exists
echo "Checking for existing PostgreSQL datasource..."
datasources=$(curl -s -H "Authorization: Bearer $API_KEY" "$GRAFANA_URL/api/datasources")

# Check if datasource exists
datasource_id=""
if command -v jq &> /dev/null; then
    # Use jq if available
    datasource_id=$(echo "$datasources" | jq '.[] | select(.name=="PostgreSQL") | .id')
else
    # Fallback to grep
    if echo "$datasources" | grep -q '"name":"PostgreSQL"'; then
        echo "PostgreSQL datasource exists, but we'll recreate it to ensure proper configuration."
        # Extract ID using grep and sed (basic approach)
        datasource_id=$(echo "$datasources" | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')
    fi
fi

# Delete existing datasource if found
if [ ! -z "$datasource_id" ]; then
    echo "Deleting existing PostgreSQL datasource (ID: $datasource_id)..."
    curl -s -X DELETE -H "Authorization: Bearer $API_KEY" "$GRAFANA_URL/api/datasources/$datasource_id"
    echo "Existing datasource deleted."
fi

# Create new PostgreSQL datasource
echo "Creating new PostgreSQL datasource..."
datasource_json='{
  "name": "PostgreSQL",
  "type": "postgres",
  "url": "'$POSTGRES_HOST':'$POSTGRES_PORT'",
  "access": "proxy",
  "user": "'$POSTGRES_USER'",
  "database": "'$POSTGRES_DB'",
  "basicAuth": false,
  "isDefault": true,
  "jsonData": {
    "postgresVersion": 1200,
    "sslmode": "disable",
    "timescaledb": false
  },
  "secureJsonData": {
    "password": "'$POSTGRES_PASSWORD'"
  }
}'

response=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $API_KEY" -d "$datasource_json" "$GRAFANA_URL/api/datasources")

if command -v jq &> /dev/null; then
    if [ "$(echo "$response" | jq -r '.message')" == "Datasource added" ]; then
        echo "PostgreSQL datasource created successfully!"
    else
        echo "ERROR: Failed to create datasource. Response: $(echo "$response" | jq -c .)"
    fi
else
    if [[ "$response" == *"Datasource added"* ]]; then
        echo "PostgreSQL datasource created successfully!"
    else
        echo "ERROR: Failed to create datasource. Response: $response"
    fi
fi

# Test the datasource
echo "Testing the datasource connection..."
if command -v jq &> /dev/null; then
    datasource_id=$(echo "$response" | jq -r '.id')
else
    # Basic extraction with grep and sed
    datasource_id=$(echo "$response" | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')
fi

if [ ! -z "$datasource_id" ]; then
    test_response=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $API_KEY" "$GRAFANA_URL/api/datasources/$datasource_id/health")
    
    if command -v jq &> /dev/null; then
        status=$(echo "$test_response" | jq -r '.status')
        if [ "$status" == "OK" ]; then
            echo "Datasource connection test successful!"
        else
            echo "WARNING: Datasource connection test failed. Response: $(echo "$test_response" | jq -c .)"
        fi
    else
        if [[ "$test_response" == *"\"status\":\"OK\""* ]]; then
            echo "Datasource connection test successful!"
        else
            echo "WARNING: Datasource connection test failed. Response: $test_response"
        fi
    fi
else
    echo "WARNING: Could not extract datasource ID for testing."
fi

echo -e "\n=== Fix Complete ==="
echo "The PostgreSQL datasource has been recreated with the correct settings."
echo "Please refresh your Grafana dashboards to see if data appears now."
echo "If dashboards are still empty, run the diagnose_grafana.sh script to check for data issues."
echo "You may also need to restart Grafana: sudo systemctl restart grafana-server"