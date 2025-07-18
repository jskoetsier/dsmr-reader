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
# This is part 2 of the create_grafana_dashboards.sh script

# Phase Currents Dashboard (continued)
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
        "L1": "#F2CC0C",
        "L2": "#3274D9",
        "L3": "#FF9830"
      },
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "DSMR Reader",
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
        "min": true,
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
          "rawSql": "SELECT\n  read_at AS \"time\",\n  phase_power_current_l1 AS \"L1\",\n  phase_power_current_l2 AS \"L2\",\n  phase_power_current_l3 AS \"L3\"\nFROM dsmr_consumption_electricityconsumption\nWHERE\n  $__timeFilter(read_at)\nORDER BY read_at ASC",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "value"
                ],
                "type": "column"
              }
            ]
          ],
          "timeColumn": "time",
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
      "title": "Phase Currents (A)",
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
    },
    {
      "datasource": "DSMR Reader",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "max": 25,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 16
              },
              {
                "color": "red",
                "value": 20
              }
            ]
          },
          "unit": "amp"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 8,
        "x": 0,
        "y": 9
      },
      "id": 4,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "pluginVersion": "7.0.0",
      "targets": [
        {
          "format": "time_series",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT\n  read_at AS \"time\",\n  phase_power_current_l1 AS \"L1 Current\"\nFROM dsmr_consumption_electricityconsumption\nWHERE\n  $__timeFilter(read_at)\nORDER BY read_at DESC\nLIMIT 1",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "value"
                ],
                "type": "column"
              }
            ]
          ],
          "timeColumn": "time",
          "where": [
            {
              "name": "$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "L1 Current",
      "type": "gauge"
    },
    {
      "datasource": "DSMR Reader",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "max": 25,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 16
              },
              {
                "color": "red",
                "value": 20
              }
            ]
          },
          "unit": "amp"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 8,
        "x": 8,
        "y": 9
      },
      "id": 5,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "pluginVersion": "7.0.0",
      "targets": [
        {
          "format": "time_series",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT\n  read_at AS \"time\",\n  phase_power_current_l2 AS \"L2 Current\"\nFROM dsmr_consumption_electricityconsumption\nWHERE\n  $__timeFilter(read_at)\nORDER BY read_at DESC\nLIMIT 1",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "value"
                ],
                "type": "column"
              }
            ]
          ],
          "timeColumn": "time",
          "where": [
            {
              "name": "$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "L2 Current",
      "type": "gauge"
    },
    {
      "datasource": "DSMR Reader",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "max": 25,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 16
              },
              {
                "color": "red",
                "value": 20
              }
            ]
          },
          "unit": "amp"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 8,
        "x": 16,
        "y": 9
      },
      "id": 6,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "pluginVersion": "7.0.0",
      "targets": [
        {
          "format": "time_series",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT\n  read_at AS \"time\",\n  phase_power_current_l3 AS \"L3 Current\"\nFROM dsmr_consumption_electricityconsumption\nWHERE\n  $__timeFilter(read_at)\nORDER BY read_at DESC\nLIMIT 1",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "value"
                ],
                "type": "column"
              }
            ]
          ],
          "timeColumn": "time",
          "where": [
            {
              "name": "$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "L3 Current",
      "type": "gauge"
    }
  ],
  "schemaVersion": 22,
  "style": "dark",
  "tags": ["dsmr", "electricity", "current"],
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
  "uid": "phase_currents",
  "version": 1
}'

# 5. Gas Consumption Dashboard
GAS_DASHBOARD_FILE="/home/dsmr/grafana-dashboards/gas_consumption.json"
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
        "Gas": "#73BF69"
      },
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "DSMR Reader",
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
        "min": true,
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
          "rawSql": "SELECT\n  read_at AS \"time\",\n  currently_delivered AS \"Gas\"\nFROM dsmr_consumption_gasconsumption\nWHERE\n  $__timeFilter(read_at)\nORDER BY read_at ASC",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "value"
                ],
                "type": "column"
              }
            ]
          ],
          "timeColumn": "time",
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
      "title": "Gas Consumption (m³)",
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
    },
    {
      "aliasColors": {
        "Gas": "#73BF69"
      },
      "bars": true,
      "dashLength": 10,
      "dashes": false,
      "datasource": "DSMR Reader",
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 9,
        "w": 24,
        "x": 0,
        "y": 9
      },
      "hiddenSeries": false,
      "id": 3,
      "legend": {
        "avg": true,
        "current": true,
        "max": true,
        "min": true,
        "show": true,
        "total": false,
        "values": true
      },
      "lines": false,
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
          "rawSql": "SELECT\n  date_trunc(\'day\', read_at) AS \"time\",\n  SUM(currently_delivered) AS \"Gas\"\nFROM dsmr_consumption_gasconsumption\nWHERE\n  $__timeFilter(read_at)\nGROUP BY date_trunc(\'day\', read_at)\nORDER BY date_trunc(\'day\', read_at) ASC",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "value"
                ],
                "type": "column"
              }
            ]
          ],
          "timeColumn": "time",
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
      "title": "Daily Gas Consumption (m³)",
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
    },
    {
      "datasource": "DSMR Reader",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 0.5
              },
              {
                "color": "red",
                "value": 1
              }
            ]
          },
          "unit": "m3"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 18
      },
      "id": 4,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        }
      },
      "pluginVersion": "7.0.0",
      "targets": [
        {
          "format": "time_series",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT\n  read_at AS \"time\",\n  currently_delivered AS \"Last Gas Reading\"\nFROM dsmr_consumption_gasconsumption\nWHERE\n  $__timeFilter(read_at)\nORDER BY read_at DESC\nLIMIT 1",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "value"
                ],
                "type": "column"
              }
            ]
          ],
          "timeColumn": "time",
          "where": [
            {
              "name": "$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "Last Gas Reading",
      "type": "stat"
    },
    {
      "datasource": "DSMR Reader",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 5
              },
              {
                "color": "red",
                "value": 10
              }
            ]
          },
          "unit": "m3"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 18
      },
      "id": 5,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "sum"
          ],
          "fields": "",
          "values": false
        }
      },
      "pluginVersion": "7.0.0",
      "targets": [
        {
          "format": "time_series",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT\n  date_trunc(\'day\', read_at) AS \"time\",\n  SUM(currently_delivered) AS \"Today\'s Gas Usage\"\nFROM dsmr_consumption_gasconsumption\nWHERE\n  read_at >= date_trunc(\'day\', now())\nGROUP BY date_trunc(\'day\', read_at)\nORDER BY date_trunc(\'day\', read_at) ASC",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "value"
                ],
                "type": "column"
              }
            ]
          ],
          "timeColumn": "time",
          "where": [
            {
              "name": "$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "Today\'s Gas Usage",
      "type": "stat"
    }
  ],
  "schemaVersion": 22,
  "style": "dark",
  "tags": ["dsmr", "gas"],
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
  "uid": "gas_consumption",
  "version": 1
}'

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
