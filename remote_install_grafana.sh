#!/bin/bash
# Script to install Grafana directly on the remote server

# Exit on error but print the command that failed
set -e

# Function to handle errors
handle_error() {
  echo "Error occurred at line $1"
  exit 1
}

# Set up error handling
trap 'handle_error $LINENO' ERR

echo "=== Remote DSMR Reader Grafana Setup ==="
echo "This script will connect to the remote server and install Grafana directly."
echo ""
echo "The following steps will be performed:"
echo "1. Connect to the remote server"
echo "2. Pull the latest changes from the git repository"
echo "3. Install Grafana and create dashboards"
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Connect to the remote server and run the installation
echo "Connecting to remote server and installing Grafana..."
ssh -o ConnectTimeout=10 dsmr@192.168.1.172 << 'EOF'
  cd /home/dsmr/dsmr-reader
  echo "Pulling latest changes from git repository..."
  git pull
  
  echo "Making installation scripts executable..."
  chmod +x install_grafana.sh
  chmod +x create_grafana_dashboards.sh
  chmod +x create_grafana_dashboards_part2.sh
  chmod +x create_grafana_dashboards_part3.sh
  
  echo "Combining dashboard creation scripts..."
  cat create_grafana_dashboards.sh > combined_create_dashboards.sh
  echo "" >> combined_create_dashboards.sh
  cat create_grafana_dashboards_part2.sh | grep -v "#!/bin/bash" >> combined_create_dashboards.sh
  echo "" >> combined_create_dashboards.sh
  cat create_grafana_dashboards_part3.sh | grep -v "#!/bin/bash" >> combined_create_dashboards.sh
  chmod +x combined_create_dashboards.sh
  
  echo "Installing Grafana..."
  sudo bash ./install_grafana.sh
  
  echo "Creating dashboards..."
  bash ./combined_create_dashboards.sh
  
  echo "Cleaning up..."
  rm -f combined_create_dashboards.sh
EOF

echo ""
echo "=== Remote Setup Complete ==="
echo "If no errors were reported, Grafana has been installed and dashboards have been created."
echo "You can access Grafana at http://192.168.1.172:3000"
echo "Default login credentials: admin/admin"
echo "Please change the default password after your first login."
echo ""
echo "Done!"