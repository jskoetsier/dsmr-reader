#!/bin/bash

echo "=== DSMR Reader Grafana Diagnostics ==="
echo "This script will diagnose issues with Grafana dashboards not showing data"

# Configuration
POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"
POSTGRES_DB="dsmrreader"
POSTGRES_USER="dsmrreader"
POSTGRES_PASSWORD="dsmrreader"  # Change this if your PostgreSQL password is different
GRAFANA_URL="http://localhost:3000"

# Check if psql is installed
if ! command -v psql &> /dev/null; then
    echo "ERROR: PostgreSQL client (psql) is not installed. Please install it first."
    exit 1
fi

# Function to run a PostgreSQL query
run_query() {
    local query="$1"
    local description="$2"
    
    echo "Checking $description..."
    result=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "$query" 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to run query: $result"
        return 1
    fi
    
    echo "$result"
    return 0
}

# Check PostgreSQL connection
echo "Testing PostgreSQL connection..."
if ! run_query "SELECT 1;" "basic connection"; then
    echo "ERROR: Could not connect to PostgreSQL. Please check your connection settings."
    exit 1
fi
echo "PostgreSQL connection successful!"

# Check if tables exist
echo -e "\nChecking if required tables exist..."
tables=(
    "dsmr_consumption_electricityconsumption"
    "dsmr_datalogger_dsmrreading"
    "dsmr_consumption_gasconsumption"
)

for table in "${tables[@]}"; do
    if ! run_query "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = '$table');" "table $table"; then
        echo "ERROR: Failed to check if table $table exists."
    elif [[ $(echo "$result" | tr -d ' ') == "f" ]]; then
        echo "ERROR: Table $table does not exist in the database."
    else
        echo "Table $table exists."
    fi
done

# Check if tables have data
echo -e "\nChecking if tables have data..."
for table in "${tables[@]}"; do
    count=$(run_query "SELECT COUNT(*) FROM $table;" "data in $table")
    if [[ $? -eq 0 ]]; then
        count=$(echo "$count" | tr -d ' ')
        echo "Table $table has $count rows."
        if [[ $count -eq 0 ]]; then
            echo "WARNING: Table $table has no data. This could be why dashboards are empty."
        fi
    fi
done

# Check specific columns used in dashboards
echo -e "\nChecking columns in electricity consumption table..."
run_query "SELECT column_name FROM information_schema.columns WHERE table_name = 'dsmr_consumption_electricityconsumption';" "electricity columns"

echo -e "\nChecking columns in datalogger readings table..."
run_query "SELECT column_name FROM information_schema.columns WHERE table_name = 'dsmr_datalogger_dsmrreading';" "datalogger columns"

echo -e "\nChecking columns in gas consumption table..."
run_query "SELECT column_name FROM information_schema.columns WHERE table_name = 'dsmr_consumption_gasconsumption';" "gas columns"

# Check sample data for electricity
echo -e "\nChecking sample electricity consumption data..."
run_query "SELECT read_at, delivered_1, delivered_2, returned_1, returned_2 FROM dsmr_consumption_electricityconsumption ORDER BY read_at DESC LIMIT 5;" "electricity sample data"

# Check sample data for phase readings
echo -e "\nChecking sample phase data..."
run_query "SELECT read_at, phase_currently_delivered_l1, phase_currently_delivered_l2, phase_currently_delivered_l3 FROM dsmr_datalogger_dsmrreading ORDER BY read_at DESC LIMIT 5;" "phase sample data"

# Check sample data for gas
echo -e "\nChecking sample gas consumption data..."
run_query "SELECT read_at, currently_delivered FROM dsmr_consumption_gasconsumption ORDER BY read_at DESC LIMIT 5;" "gas sample data"

# Check Grafana connection
echo -e "\nChecking Grafana connection..."
if ! command -v curl &> /dev/null; then
    echo "WARNING: curl is not installed. Skipping Grafana connection check."
else
    if curl -s "$GRAFANA_URL/api/health" | grep -q "ok"; then
        echo "Grafana is running and accessible."
    else
        echo "ERROR: Could not connect to Grafana at $GRAFANA_URL. Please check if Grafana is running."
    fi
fi

echo -e "\n=== Diagnostics Complete ==="
echo "If tables exist but have no data, you may need to check your DSMR reader configuration."
echo "If tables are missing columns used in dashboard queries, you may need to update the dashboard queries."
echo "If everything looks good but dashboards are still empty, check Grafana datasource configuration."