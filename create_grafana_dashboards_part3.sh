#!/bin/bash
# This is part 3 of the create_grafana_dashboards.sh script

# Create and import all dashboards
echo "Creating Electricity Usage dashboard..."
echo "$ELECTRICITY_DASHBOARD" > "$ELECTRICITY_DASHBOARD_FILE"
curl -X POST -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d "{
  \"dashboard\": $(cat $ELECTRICITY_DASHBOARD_FILE),
  \"overwrite\": true,
  \"folderId\": 0
}" http://localhost:3000/api/dashboards/db
echo "Electricity Usage dashboard created and imported."

echo "Creating Phase Usage dashboard..."
echo "$PHASE_USAGE_DASHBOARD" > "$PHASE_USAGE_DASHBOARD_FILE"
curl -X POST -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d "{
  \"dashboard\": $(cat $PHASE_USAGE_DASHBOARD_FILE),
  \"overwrite\": true,
  \"folderId\": 0
}" http://localhost:3000/api/dashboards/db
echo "Phase Usage dashboard created and imported."

echo "Creating Phase Voltages dashboard..."
echo "$PHASE_VOLTAGES_DASHBOARD" > "$PHASE_VOLTAGES_DASHBOARD_FILE"
curl -X POST -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d "{
  \"dashboard\": $(cat $PHASE_VOLTAGES_DASHBOARD_FILE),
  \"overwrite\": true,
  \"folderId\": 0
}" http://localhost:3000/api/dashboards/db
echo "Phase Voltages dashboard created and imported."

echo "Creating Phase Currents dashboard..."
echo "$PHASE_CURRENTS_DASHBOARD" > "$PHASE_CURRENTS_DASHBOARD_FILE"
curl -X POST -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d "{
  \"dashboard\": $(cat $PHASE_CURRENTS_DASHBOARD_FILE),
  \"overwrite\": true,
  \"folderId\": 0
}" http://localhost:3000/api/dashboards/db
echo "Phase Currents dashboard created and imported."

echo "Creating Gas Consumption dashboard..."
echo "$GAS_DASHBOARD" > "$GAS_DASHBOARD_FILE"
curl -X POST -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d "{
  \"dashboard\": $(cat $GAS_DASHBOARD_FILE),
  \"overwrite\": true,
  \"folderId\": 0
}" http://localhost:3000/api/dashboards/db
echo "Gas Consumption dashboard created and imported."

echo "=== Dashboard Creation Complete ==="
echo "All dashboards have been created and imported into Grafana."
echo "You can access them at http://your-server-ip:3000"