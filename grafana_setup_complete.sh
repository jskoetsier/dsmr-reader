#!/bin/bash

echo "=== DSMR Reader Grafana Dashboard Setup ==="
echo "This script will create a PostgreSQL datasource and import dashboards into Grafana"

# Configuration
GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="rEjacap2"  # Change this if you've set a different password
POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"
POSTGRES_DB="dsmrreader"
POSTGRES_USER="dsmrreader"
POSTGRES_PASSWORD="dsmrreader"  # Change this if your PostgreSQL password is different

# Temporary files for dashboard JSON
TEMP_DIR="/tmp/grafana_dashboards"
mkdir -p $TEMP_DIR

# Function to check if Grafana is running
check_grafana() {
  echo "Checking if Grafana is running..."
  for i in {1..10}; do
    if curl -s "$GRAFANA_URL/api/health" | grep -q "ok"; then
      echo "Grafana is running!"
      return 0
    fi
    echo "Waiting for Grafana to start... ($i/10)"
    sleep 3
  done
  echo "ERROR: Grafana is not running. Please make sure Grafana is installed and running."
  exit 1
}

# Function to create API key
create_api_key() {
  echo "Creating Grafana API key..."
  
  # Get CSRF token and cookie for login
  COOKIE_FILE="$TEMP_DIR/cookies.txt"
  CSRF_TOKEN=$(curl -s -c "$COOKIE_FILE" "$GRAFANA_URL/login" | grep -oP 'name="_csrf" value="\K[^"]+')
  
  # Login to Grafana
  curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" \
    -b "$COOKIE_FILE" -c "$COOKIE_FILE" \
    --data-urlencode "user=$GRAFANA_USER" \
    --data-urlencode "password=$GRAFANA_PASSWORD" \
    --data-urlencode "_csrf=$CSRF_TOKEN" \
    "$GRAFANA_URL/login"
  
  # Create API key
  API_KEY_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
    -b "$COOKIE_FILE" \
    -d '{
      "name": "dsmr-reader-api-key",
      "role": "Admin",
      "secondsToLive": 86400
    }' \
    "$GRAFANA_URL/api/auth/keys")
  
  # Extract API key
  API_KEY=$(echo "$API_KEY_RESPONSE" | grep -oP '"key":"\K[^"]+')
  
  if [ -z "$API_KEY" ]; then
    echo "Failed to create API key. Using basic auth instead."
    echo "Please enter your Grafana API key manually (create one in Grafana UI -> Administration -> API Keys):"
    read -p "> " API_KEY
    
    if [ -z "$API_KEY" ]; then
      echo "No API key provided. Will use basic authentication."
      AUTH_HEADER="Authorization: Basic $(echo -n "$GRAFANA_USER:$GRAFANA_PASSWORD" | base64)"
    else
      AUTH_HEADER="Authorization: Bearer $API_KEY"
    fi
  else
    echo "API key created successfully!"
    AUTH_HEADER="Authorization: Bearer $API_KEY"
  fi
  
  echo "$AUTH_HEADER" > "$TEMP_DIR/auth_header.txt"
}

# Function to create PostgreSQL datasource
create_datasource() {
  echo "Creating PostgreSQL datasource..."
  
  AUTH_HEADER=$(cat "$TEMP_DIR/auth_header.txt")
  
  curl -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" \
    -d '{
      "name": "DSMR-Reader PostgreSQL",
      "type": "postgres",
      "url": "'"$POSTGRES_HOST:$POSTGRES_PORT"'",
      "access": "proxy",
      "basicAuth": false,
      "database": "'"$POSTGRES_DB"'",
      "user": "'"$POSTGRES_USER"'",
      "password": "'"$POSTGRES_PASSWORD"'",
      "isDefault": true,
      "jsonData": {
        "sslmode": "disable",
        "postgresVersion": 1200,
        "timescaledb": false
      }
    }' \
    "$GRAFANA_URL/api/datasources"
  
  echo "PostgreSQL datasource created."
}

# Function to create and import a dashboard
create_dashboard() {
  local name="$1"
  local json="$2"
  local file="$TEMP_DIR/$name.json"
  
  echo "Creating $name dashboard..."
  echo "$json" > "$file"
  
  AUTH_HEADER=$(cat "$TEMP_DIR/auth_header.txt")
  
  curl -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" \
    -d "{
      \"dashboard\": $(cat "$file"),
      \"overwrite\": true,
      \"folderId\": 0
    }" \
    "$GRAFANA_URL/api/dashboards/db"
  
  echo "$name dashboard created and imported."
}

# Check if Grafana is running
check_grafana

# Create API key
create_api_key

# Create PostgreSQL datasource
create_datasource

# Create Electricity Usage Dashboard
ELECTRICITY_DASHBOARD='{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "aliasColors": {
        "Delivered": "green",
        "Returned": "orange"
      },
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "DSMR-Reader PostgreSQL",
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 9,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 2,
      "legend": {
        "avg": true,
        "current": true,
        "max": true,
        "min": false,
        "show": true,
        "total": true,
        "values": true
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "format": "time_series",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT\n  read_at AS \"time\",\n  delivered_1 + delivered_2 AS \"Delivered\",\n  returned_1 + returned_2 AS \"Returned\"\nFROM dsmr_consumption_electricityconsumption\nWHERE\n  $__timeFilter(read_at)\nORDER BY 1",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "delivered_1"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "dsmr_consumption_electricityconsumption",
          "timeColumn": "read_at",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Electricity Consumption",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "kwatth",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    }
  ],
  "schemaVersion": 22,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-24h",
    "to": "now"
  },
  "timepicker": {
    "refresh_intervals": [
      "5s",
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ]
  },
  "timezone": "",
  "title": "Electricity Usage",
  "uid": "electricity",
  "version": 1
}'

# Create Phase Usage Dashboard
PHASE_USAGE_DASHBOARD='{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "aliasColors": {
        "Phase 1": "blue",
        "Phase 2": "green",
        "Phase 3": "red"
      },
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "DSMR-Reader PostgreSQL",
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 9,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 2,
      "legend": {
        "avg": true,
        "current": true,
        "max": true,
        "min": false,
        "show": true,
        "total": true,
        "values": true
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "format": "time_series",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT\n  read_at AS \"time\",\n  phase_currently_delivered_l1 AS \"Phase 1\",\n  phase_currently_delivered_l2 AS \"Phase 2\",\n  phase_currently_delivered_l3 AS \"Phase 3\"\nFROM dsmr_datalogger_dsmrreading\nWHERE\n  $__timeFilter(read_at)\nORDER BY 1",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "phase_currently_delivered_l1"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "dsmr_datalogger_dsmrreading",
          "timeColumn": "read_at",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Phase Usage",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "watt",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    }
  ],
  "schemaVersion": 22,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-24h",
    "to": "now"
  },
  "timepicker": {
    "refresh_intervals": [
      "5s",
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ]
  },
  "timezone": "",
  "title": "Phase Usage",
  "uid": "phase-usage",
  "version": 1
}'

# Create Phase Voltages Dashboard
PHASE_VOLTAGES_DASHBOARD='{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "aliasColors": {
        "Phase 1": "blue",
        "Phase 2": "green",
        "Phase 3": "red"
      },
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "DSMR-Reader PostgreSQL",
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 9,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 2,
      "legend": {
        "avg": true,
        "current": true,
        "max": true,
        "min": false,
        "show": true,
        "total": false,
        "values": true
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "format": "time_series",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT\n  read_at AS \"time\",\n  phase_voltage_l1 AS \"Phase 1\",\n  phase_voltage_l2 AS \"Phase 2\",\n  phase_voltage_l3 AS \"Phase 3\"\nFROM dsmr_datalogger_dsmrreading\nWHERE\n  $__timeFilter(read_at)\nORDER BY 1",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "phase_voltage_l1"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "dsmr_datalogger_dsmrreading",
          "timeColumn": "read_at",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Phase Voltages",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "volt",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    }
  ],
  "schemaVersion": 22,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-24h",
    "to": "now"
  },
  "timepicker": {
    "refresh_intervals": [
      "5s",
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ]
  },
  "timezone": "",
  "title": "Phase Voltages",
  "uid": "phase-voltages",
  "version": 1
}'

# Create Phase Currents Dashboard
PHASE_CURRENTS_DASHBOARD='{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "aliasColors": {
        "Phase 1": "blue",
        "Phase 2": "green",
        "Phase 3": "red"
      },
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "DSMR-Reader PostgreSQL",
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 9,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 2,
      "legend": {
        "avg": true,
        "current": true,
        "max": true,
        "min": false,
        "show": true,
        "total": false,
        "values": true
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "format": "time_series",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT\n  read_at AS \"time\",\n  phase_power_current_l1 AS \"Phase 1\",\n  phase_power_current_l2 AS \"Phase 2\",\n  phase_power_current_l3 AS \"Phase 3\"\nFROM dsmr_datalogger_dsmrreading\nWHERE\n  $__timeFilter(read_at)\nORDER BY 1",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "phase_power_current_l1"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "dsmr_datalogger_dsmrreading",
          "timeColumn": "read_at",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Phase Currents",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "amp",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    }
  ],
  "schemaVersion": 22,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-24h",
    "to": "now"
  },
  "timepicker": {
    "refresh_intervals": [
      "5s",
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ]
  },
  "timezone": "",
  "title": "Phase Currents",
  "uid": "phase-currents",
  "version": 1
}'

# Create Gas Consumption Dashboard
GAS_DASHBOARD='{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "aliasColors": {
        "Gas": "orange"
      },
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "DSMR-Reader PostgreSQL",
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 9,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 2,
      "legend": {
        "avg": true,
        "current": true,
        "max": true,
        "min": false,
        "show": true,
        "total": true,
        "values": true
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "format": "time_series",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT\n  read_at AS \"time\",\n  currently_delivered AS \"Gas\"\nFROM dsmr_consumption_gasconsumption\nWHERE\n  $__timeFilter(read_at)\nORDER BY 1",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "currently_delivered"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "dsmr_consumption_gasconsumption",
          "timeColumn": "read_at",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Gas Consumption",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "m3",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    }
  ],
  "schemaVersion": 22,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-24h",
    "to": "now"
  },
  "timepicker": {
    "refresh_intervals": [
      "5s",
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ]
  },
  "timezone": "",
  "title": "Gas Consumption",
  "uid": "gas-consumption",
  "version": 1
}'

# Create and import dashboards
create_dashboard "electricity" "$ELECTRICITY_DASHBOARD"
create_dashboard "phase_usage" "$PHASE_USAGE_DASHBOARD"
create_dashboard "phase_voltages" "$PHASE_VOLTAGES_DASHBOARD"
create_dashboard "phase_currents" "$PHASE_CURRENTS_DASHBOARD"
create_dashboard "gas" "$GAS_DASHBOARD"

echo "=== Dashboard Setup Complete ==="
echo "All dashboards have been created and imported into Grafana."
echo "You can access them at http://localhost:3000"
echo "Login with username: admin and password: $GRAFANA_PASSWORD"

# Clean up temporary files
rm -rf "$TEMP_DIR"