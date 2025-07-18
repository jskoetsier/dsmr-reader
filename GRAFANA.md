# DSMR Reader Grafana Integration

This directory contains scripts to set up Grafana dashboards for visualizing your DSMR Reader data. Grafana provides powerful visualization capabilities that complement the built-in DSMR Reader interface.

## Included Dashboards

The integration includes the following dashboards:

1. **Electricity Usage**
   - Real-time electricity consumption and production in watts
   - Daily electricity consumption and production in kWh

2. **Phase Usage**
   - Per-phase electricity consumption (L1, L2, L3)
   - Per-phase electricity production (L1, L2, L3)

3. **Phase Voltages**
   - Voltage levels for each phase (L1, L2, L3)
   - Real-time gauges showing current voltage levels with thresholds

4. **Phase Currents**
   - Current levels for each phase (L1, L2, L3)
   - Real-time gauges showing current amperage with thresholds

5. **Gas Consumption**
   - Gas consumption over time
   - Daily gas consumption
   - Current gas usage statistics

## Installation

### Automatic Installation

The easiest way to install is using the provided setup script:

```bash
./setup_grafana.sh
```

This script will:
1. Install Grafana on your server
2. Configure Grafana to connect to your DSMR Reader database
3. Create all the dashboards
4. Set up proper permissions

### Manual Installation

If you prefer to install manually, follow these steps:

1. Install Grafana:
```bash
./install_grafana.sh
```

2. Create the dashboards:
```bash
# On the server after running install_grafana.sh
./combined_create_dashboards.sh
```

## Accessing Grafana

After installation, you can access Grafana at:

```
http://your-server-ip:3000
```

Default login credentials:
- Username: admin
- Password: admin

You will be prompted to change the password on first login.

## Customizing Dashboards

You can customize the dashboards directly in the Grafana interface:

1. Log in to Grafana
2. Navigate to the dashboard you want to customize
3. Click the gear icon in the top right to enter edit mode
4. Make your changes and click "Save"

## Troubleshooting

### API Key Issues

If you encounter issues with the API key:

```bash
# Check if the API key file exists
ls -la /home/dsmr/grafana_api_key.txt

# If needed, generate a new API key in Grafana:
# 1. Log in to Grafana
# 2. Go to Configuration > API Keys
# 3. Create a new key with Admin permissions
# 4. Save the key to /home/dsmr/grafana_api_key.txt:
echo "API_KEY=your_new_key" > /home/dsmr/grafana_api_key.txt
```

### Database Connection Issues

If Grafana cannot connect to the DSMR Reader database:

1. Check the database settings in `/home/dsmr/dsmr-reader/dsmrreader/settings.py`
2. Make sure the database user has proper permissions
3. Verify the database is running and accessible

### Dashboard Import Failures

If dashboards fail to import:

1. Check the Grafana logs: `sudo journalctl -u grafana-server`
2. Try importing the JSON files manually through the Grafana UI
3. Verify the API key has Admin permissions

## Updating

To update the dashboards:

1. Pull the latest changes from the repository
2. Run the setup script again:
```bash
./setup_grafana.sh
```

This will overwrite any existing dashboards with the latest versions.