#!/bin/bash
# Master script to set up Grafana and create dashboards for DSMR Reader

# Exit on error but print the command that failed
set -e

# Function to handle errors
handle_error() {
  echo "Error occurred at line $1"
  exit 1
}

# Set up error handling
trap 'handle_error $LINENO' ERR

echo "=== DSMR Reader Grafana Setup ==="
echo "This script will install Grafana and create dashboards for your DSMR Reader data."
echo ""
echo "The following steps will be performed:"
echo "1. Install Grafana on your server"
echo "2. Configure Grafana to connect to your DSMR Reader database"
echo "3. Create dashboards for:"
echo "   - Electricity Usage"
echo "   - Phase Usage"
echo "   - Phase Voltages"
echo "   - Phase Currents"
echo "   - Gas Consumption"
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Make all scripts executable
echo "Making scripts executable..."
chmod +x install_grafana.sh
chmod +x create_grafana_dashboards.sh
chmod +x create_grafana_dashboards_part2.sh
chmod +x create_grafana_dashboards_part3.sh

# Combine the dashboard creation scripts into one
echo "Combining dashboard creation scripts..."
cat create_grafana_dashboards.sh > combined_create_dashboards.sh
echo "" >> combined_create_dashboards.sh
cat create_grafana_dashboards_part2.sh | grep -v "#!/bin/bash" >> combined_create_dashboards.sh
echo "" >> combined_create_dashboards.sh
cat create_grafana_dashboards_part3.sh | grep -v "#!/bin/bash" >> combined_create_dashboards.sh
chmod +x combined_create_dashboards.sh

# Copy scripts to the server
echo "Copying scripts to the server..."
scp -o ConnectTimeout=10 install_grafana.sh combined_create_dashboards.sh dsmr@192.168.1.172:/home/dsmr/ || {
  echo "Failed to copy scripts to the server. Please check your SSH connection."
  exit 1
}

# Execute the installation script on the server
echo "Installing Grafana on the server..."
echo "This may take a few minutes. Please be patient..."
ssh -o ConnectTimeout=10 dsmr@192.168.1.172 "cd /home/dsmr && sudo bash ./install_grafana.sh" || {
  echo "Failed to install Grafana. Please check the server logs."
  exit 1
}

# Execute the dashboard creation script on the server
echo "Creating dashboards..."
ssh -o ConnectTimeout=10 dsmr@192.168.1.172 "cd /home/dsmr && bash ./combined_create_dashboards.sh" || {
  echo "Failed to create dashboards. Please check the server logs."
  exit 1
}

echo ""
echo "=== Setup Complete ==="
echo "Grafana has been installed and dashboards have been created."
echo "You can access Grafana at http://192.168.1.172:3000"
echo "Default login credentials: admin/admin"
echo "Please change the default password after your first login."
echo ""
echo "Cleaning up temporary files..."
rm -f combined_create_dashboards.sh

# Clean up the temporary files on the server
ssh -o ConnectTimeout=10 dsmr@192.168.1.172 "cd /home/dsmr && rm -f combined_create_dashboards.sh" || {
  echo "Warning: Failed to clean up temporary files on the server."
}

echo "Done!"