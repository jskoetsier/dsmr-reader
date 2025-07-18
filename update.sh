#!/usr/bin/env bash
#
# DSMR Reader Comprehensive Update Script
# This script updates DSMR Reader to the latest version and performs various checks
#

set -e  # Exit on error

# Color codes for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if we're in a virtual environment
in_virtualenv() {
    python -c 'import sys; exit(0 if hasattr(sys, "real_prefix") or sys.base_prefix != sys.prefix else 1)'
}

# Function to check Python version
check_python_version() {
    print_header "Checking Python Version"

    # Get Python version
    python_version=$(python --version 2>&1)
    echo "Current Python version: $python_version"

    # Check if Python version is at least 3.8
    python -c 'import sys; sys.exit(0) if sys.version_info >= (3, 8) else sys.exit(1)'

    if [ $? -eq 0 ]; then
        print_success "Python version is compatible"
    else
        print_error "Python version is not compatible. DSMR Reader requires Python 3.8 or higher."
        exit 1
    fi
}

# Function to activate virtual environment
activate_virtualenv() {
    print_header "Checking Virtual Environment"

    if ! in_virtualenv; then
        echo "Virtual environment not activated, attempting to activate..."

        # Check if .venv directory exists
        if [ -d ".venv" ]; then
            source .venv/bin/activate
            print_success "Activated virtual environment in .venv"
        elif [ -d "../.venv" ]; then
            source ../.venv/bin/activate
            print_success "Activated virtual environment in ../.venv"
        elif [ -d "$HOME/dsmr-reader/.venv" ]; then
            source $HOME/dsmr-reader/.venv/bin/activate
            print_success "Activated virtual environment in $HOME/dsmr-reader/.venv"
        else
            print_error "Could not find virtual environment. Please activate it manually."
            exit 1
        fi

        # Verify activation was successful
        if ! in_virtualenv; then
            print_error "Failed to activate virtual environment"
            exit 1
        fi
    else
        print_success "Virtual environment is already activated"
    fi
}

# Function to check current version
check_current_version() {
    print_header "Current DSMR Reader Version"

    current_version=$(python -c 'import dsmrreader; print(dsmrreader.__version__)')
    if [ $? -eq 0 ]; then
        echo "Currently running DSMR Reader version: $current_version"
    else
        print_error "Failed to determine current DSMR Reader version"
        exit 1
    fi
}

# Function to check for local changes
check_local_changes() {
    print_header "Checking for Local Changes"

    git diff --quiet

    if [ $? -ne 0 ]; then
        print_warning "Local file changes detected"
        echo "The following files have been modified:"
        git status --porcelain

        echo ""
        echo "Options:"
        echo "1. Continue anyway (changes might be overwritten)"
        echo "2. Stash changes and continue"
        echo "3. Abort update"

        read -p "Choose an option (1-3): " choice

        case $choice in
            1)
                print_warning "Continuing with update despite local changes"
                ;;
            2)
                echo "Stashing local changes..."
                git stash save "Auto-stashed during update.sh on $(date)"
                print_success "Changes stashed successfully"
                ;;
            3)
                print_warning "Update aborted by user"
                exit 0
                ;;
            *)
                print_error "Invalid choice. Aborting update."
                exit 1
                ;;
        esac
    else
        print_success "No local changes detected"
    fi
}

# Function to update code from git
update_code() {
    print_header "Updating Code from Git Repository"

    # Get current branch
    current_branch=$(git branch --show-current)
    echo "Current branch: $current_branch"

    # Fetch updates
    echo "Fetching updates..."
    git fetch

    # Merge updates
    echo "Merging updates..."
    git merge FETCH_HEAD

    print_success "Code updated successfully"
}

# Function to update dependencies
update_dependencies() {
    print_header "Updating Dependencies"

    echo "Installing/updating base requirements..."
    pip install -r dsmrreader/provisioning/requirements/base.txt --upgrade

    print_success "Dependencies updated successfully"
}

# Function to apply database migrations
apply_migrations() {
    print_header "Applying Database Migrations"

    echo "Running migrations..."
    ./manage.py migrate --noinput

    if [ $? -ne 0 ]; then
        print_warning "Migration failed, attempting automatic fix..."

        # Try auto fix
        ./manage.py dsmr_sqlsequencereset

        # Run migrations again
        ./manage.py migrate --noinput

        if [ $? -ne 0 ]; then
            print_error "Migration failed again after attempted fix"
            exit 1
        else
            print_success "Migration succeeded after automatic fix"
        fi
    else
        print_success "Migrations applied successfully"
    fi
}

# Function to update static files
update_static_files() {
    print_header "Updating Static Files"

    echo "Collecting static files..."
    ./manage.py collectstatic --noinput

    print_success "Static files updated successfully"
}

# Function to clear cache
clear_cache() {
    print_header "Clearing Cache"

    echo "Clearing frontend cache..."
    ./manage.py dsmr_frontend_clear_cache

    print_success "Cache cleared successfully"
}

# Function to restart services
restart_services() {
    print_header "Restarting Services"

    echo "Reloading DSMR Reader services..."
    ./reload.sh

    print_success "Services restarted successfully"
}

# Function to run diagnostics
run_diagnostics() {
    print_header "Running Diagnostics"

    echo "Checking for consumption data issues..."
    python diagnose_consumption.py
}

# Function to check for DSMR version setting
check_dsmr_version_setting() {
    print_header "Checking DSMR Version Setting"

    dsmr_version=$(python -c 'from dsmr_datalogger.models.settings import DataloggerSettings; print(DataloggerSettings.get_solo().dsmr_version)')

    echo "Current DSMR version setting: $dsmr_version"
    echo ""
    echo "Available DSMR versions:"
    echo "2 - DSMR version 2.2 (older Dutch meters)"
    echo "4 - DSMR version 4+ (most Dutch smart meters)"
    echo "5 - DSMR Belgium Fluvius"
    echo "6 - DSMR Luxembourg Smarty"
    echo ""

    read -p "Do you want to change the DSMR version setting? (y/n): " change_version

    if [[ $change_version == "y" || $change_version == "Y" ]]; then
        read -p "Enter the new DSMR version (2, 4, 5, or 6): " new_version

        case $new_version in
            2|4|5|6)
                python -c "from dsmr_datalogger.models.settings import DataloggerSettings; settings = DataloggerSettings.get_solo(); settings.dsmr_version = '$new_version'; settings.save()"
                print_success "DSMR version setting changed to $new_version"
                ;;
            *)
                print_error "Invalid DSMR version. No changes made."
                ;;
        esac
    else
        echo "DSMR version setting unchanged."
    fi
}

# Main function
main() {
    print_header "DSMR Reader Update Script"
    echo "This script will update DSMR Reader to the latest version and perform various checks."
    echo ""

    # Ask for confirmation
    read -p "Do you want to continue with the update? (y/n): " confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        print_warning "Update aborted by user"
        exit 0
    fi

    # Run all steps
    activate_virtualenv
    check_python_version
    check_current_version
    check_local_changes
    update_code
    update_dependencies
    apply_migrations
    update_static_files
    clear_cache
    restart_services
    check_dsmr_version_setting
    run_diagnostics

    # Show final version
    print_header "Update Complete"
    new_version=$(python -c 'import dsmrreader; print(dsmrreader.__version__)')
    echo "DSMR Reader updated to version: $new_version"

    print_success "Update completed successfully!"
}

# Run the main function
main
