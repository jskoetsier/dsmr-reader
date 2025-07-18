#!/bin/bash

echo "=== DSMR Reader Grafana Datasource Fix ==="
echo "This script will fix the Grafana datasource configuration for DSMR Reader"

# Configuration
GRAFANA_URL="http://localhost:3000"
DATASOURCE_NAME="PostgreSQL"
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

# Get admin credentials
echo "Please enter your Grafana admin username (default: admin):"
read -r GRAFANA_USER
GRAFANA_USER=${GRAFANA_USER:-admin}

echo "Please enter your Grafana admin password:"
read -r -s GRAFANA_PASSWORD

# Get authentication token
echo -e "\nGetting authentication token..."
TOKEN_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
    -d '{"username":"'"$GRAFANA_USER"'","password":"'"$GRAFANA_PASSWORD"'"}' \
    "$GRAFANA_URL/api/auth/login")

if echo "$TOKEN_RESPONSE" | grep -q "token"; then
    AUTH_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    if [ -z "$AUTH_TOKEN" ]; then
        echo "ERROR: Failed to get authentication token."
        exit 1
    fi
    echo "Authentication successful."
else
    echo "ERROR: Authentication failed. Please check your credentials."
    exit 1
fi

# Check if datasource exists
echo "Checking if datasource exists..."
response=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" "$GRAFANA_URL/api/datasources/name/$DATASOURCE_NAME")

if echo "$response" | grep -q "Data source not found"; then
    echo "Creating new PostgreSQL datasource..."
    response=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $AUTH_TOKEN" "$GRAFANA_URL/api/datasources" -d '{
        "name": "'"$DATASOURCE_NAME"'",
        "type": "postgres",
        "url": "'"$POSTGRES_HOST:$POSTGRES_PORT"'",
        "database": "'"$POSTGRES_DB"'",
        "user": "'"$POSTGRES_USER"'",
        "secureJsonData": {
            "password": "'"$POSTGRES_PASSWORD"'"
        },
        "jsonData": {
            "sslmode": "disable",
            "postgresVersion": 1200,
            "timescaledb": false
        },
        "access": "proxy",
        "isDefault": true
    }')
    
    if echo "$response" | grep -q "id"; then
        echo "PostgreSQL datasource created successfully!"
        # Extract datasource ID
        datasource_id=$(echo "$response" | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')
    else
        echo "ERROR: Failed to create datasource. Response: $response"
        exit 1
    fi
else
    echo "Updating existing PostgreSQL datasource..."
    datasource_id=$(echo "$response" | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')
    
    response=$(curl -s -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $AUTH_TOKEN" "$GRAFANA_URL/api/datasources/$datasource_id" -d '{
        "name": "'"$DATASOURCE_NAME"'",
        "type": "postgres",
        "url": "'"$POSTGRES_HOST:$POSTGRES_PORT"'",
        "database": "'"$POSTGRES_DB"'",
        "user": "'"$POSTGRES_USER"'",
        "secureJsonData": {
            "password": "'"$POSTGRES_PASSWORD"'"
        },
        "jsonData": {
            "sslmode": "disable",
            "postgresVersion": 1200,
            "timescaledb": false
        },
        "access": "proxy",
        "isDefault": true
    }')
    
    if echo "$response" | grep -q "datasource"; then
        echo "PostgreSQL datasource updated successfully!"
    else
        echo "ERROR: Failed to update datasource. Response: $response"
        exit 1
    fi
fi

# Test the datasource
echo "Testing the datasource connection..."
test_response=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $AUTH_TOKEN" \
    "$GRAFANA_URL/api/datasources/proxy/$datasource_id/query" \
    -d '{"queries":[{"refId":"A","datasource":{"type":"postgres","uid":"'"$datasource_id"'"},"rawSql":"SELECT 1 as value;","format":"table"}]}')

if echo "$test_response" | grep -q '"value":1'; then
    echo "Datasource connection test successful!"
else
    echo "WARNING: Datasource connection test failed. Please check your PostgreSQL connection settings."
fi

# Fix dashboard queries
echo -e "\nWould you like to fix dashboard queries to use correct column names? (y/n)"
read -r fix_queries

if [[ "$fix_queries" == "y" || "$fix_queries" == "Y" ]]; then
    echo "Fixing dashboard queries..."
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "ERROR: jq is not installed. Please install it first to fix dashboard queries."
        exit 1
    fi
    
    # Get list of dashboards
    dashboard_list=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" "$GRAFANA_URL/api/search?type=dash-db")
    
    # Extract dashboard UIDs
    dashboard_uids=$(echo "$dashboard_list" | jq -r '.[] | .uid')
    
    if [ -z "$dashboard_uids" ]; then
        echo "No dashboards found."
    else
        for uid in $dashboard_uids; do
            echo "Processing dashboard with UID: $uid"
            
            # Get dashboard JSON
            dashboard_json=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" "$GRAFANA_URL/api/dashboards/uid/$uid")
            
            # Create a temporary file for the dashboard JSON
            temp_file=$(mktemp)
            echo "$dashboard_json" > "$temp_file"
            
            # Fix queries in the dashboard JSON - replace column names in SQL queries
            sed -i.bak 's/"rawSql": "SELECT read_at/"rawSql": "SELECT timestamp/g' "$temp_file"
            sed -i.bak 's/FROM dsmr_datalogger_dsmrreading WHERE read_at/FROM dsmr_datalogger_dsmrreading WHERE timestamp/g' "$temp_file"
            sed -i.bak 's/GROUP BY read_at/GROUP BY timestamp/g' "$temp_file"
            sed -i.bak 's/ORDER BY read_at/ORDER BY timestamp/g' "$temp_file"
            
            # Read the modified JSON
            fixed_json=$(cat "$temp_file")
            
            # Extract the dashboard part only
            dashboard_part=$(echo "$fixed_json" | jq '.dashboard')
            
            # Update the dashboard
            update_response=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $AUTH_TOKEN" \
                "$GRAFANA_URL/api/dashboards/db" -d '{
                "dashboard": '"$dashboard_part"',
                "overwrite": true
            }')
            
            if echo "$update_response" | grep -q '"status":"success"'; then
                echo "Dashboard $uid updated successfully."
            else
                echo "WARNING: Failed to update dashboard $uid."
                echo "Response: $update_response"
            fi
            
            # Clean up
            rm "$temp_file" "$temp_file.bak"
        done
    fi
fi

echo -e "\n=== Fix Complete ==="
echo "The PostgreSQL datasource has been configured with the correct settings."
echo "Please refresh your Grafana dashboards to see if data appears now."
echo "If dashboards are still empty, run the diagnose_grafana.sh script to check for data issues."
echo "You may also need to restart Grafana: sudo systemctl restart grafana-server"