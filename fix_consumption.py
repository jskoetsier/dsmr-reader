#!/usr/bin/env python3
"""
Script to fix consumption data issues in DSMR Reader.
This script tries different DSMR version settings and checks if they resolve the issue.
"""

import os
import sys
import time
from decimal import Decimal

import django

# Set up Django environment
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "dsmrreader.settings")
django.setup()

from django.utils import timezone

from dsmr_datalogger.models.reading import DsmrReading
from dsmr_datalogger.models.settings import DataloggerSettings
from dsmr_datalogger.models.statistics import MeterStatistics


def print_header(text):
    """Print a header with the given text."""
    print("\n" + "=" * 80)
    print(f" {text}")
    print("=" * 80)


def print_success(text):
    """Print a success message."""
    print(f"\n✓ {text}")


def print_warning(text):
    """Print a warning message."""
    print(f"\n⚠ {text}")


def print_error(text):
    """Print an error message."""
    print(f"\n✗ {text}")


def check_consumption_data():
    """Check if consumption data is being recorded correctly."""
    try:
        latest_reading = DsmrReading.objects.all().order_by("-timestamp")[0]

        # Check if electricity_currently_delivered is zero
        if latest_reading.electricity_currently_delivered == 0:
            # Check if phase power is reported
            phase_power = (
                (latest_reading.phase_currently_delivered_l1 or 0)
                + (latest_reading.phase_currently_delivered_l2 or 0)
                + (latest_reading.phase_currently_delivered_l3 or 0)
            )

            if phase_power > 0:
                return {
                    "status": "inconsistent",
                    "message": "Phase power is reported but total power is zero",
                    "phase_power": phase_power,
                    "total_power": latest_reading.electricity_currently_delivered,
                }
            else:
                return {
                    "status": "zero",
                    "message": "Both total power and phase power are zero",
                    "phase_power": phase_power,
                    "total_power": latest_reading.electricity_currently_delivered,
                }
        else:
            return {
                "status": "ok",
                "message": "Consumption data is being recorded correctly",
                "total_power": latest_reading.electricity_currently_delivered,
            }
    except IndexError:
        return {"status": "no_data", "message": "No readings found in the database"}


def try_dsmr_version(version):
    """Try a specific DSMR version setting."""
    print_header(f"Trying DSMR Version {version}")

    # Get current settings
    settings = DataloggerSettings.get_solo()
    old_version = settings.dsmr_version

    print(f"Changing DSMR version from {old_version} to {version}")

    # Change DSMR version
    settings.dsmr_version = version
    settings.save()

    # Restart services
    print("Restarting services...")
    os.system("./reload.sh")

    # Wait for new readings
    print("Waiting for new readings (30 seconds)...")
    time.sleep(30)

    # Check if the issue is resolved
    result = check_consumption_data()

    if result["status"] == "ok":
        print_success(f"DSMR version {version} fixed the issue!")
        print(f"Total power: {result.get('total_power', 'N/A')} kW")
        return True
    else:
        print_warning(f"DSMR version {version} did not fix the issue.")
        print(f"Status: {result['status']}")
        print(f"Message: {result['message']}")
        if "phase_power" in result:
            print(f"Phase power: {result['phase_power']} kW")
        if "total_power" in result:
            print(f"Total power: {result['total_power']} kW")
        return False


def fix_consumption_issue():
    """Fix the consumption issue by trying different DSMR version settings."""
    print_header("DSMR Reader Consumption Fix")

    # Check current status
    print("Checking current consumption data...")
    current_result = check_consumption_data()

    print(f"Current status: {current_result['status']}")
    print(f"Message: {current_result['message']}")

    if current_result["status"] == "ok":
        print_success("Consumption data is already being recorded correctly!")
        return

    # Get current settings
    settings = DataloggerSettings.get_solo()
    original_version = settings.dsmr_version

    print(f"\nCurrent DSMR version setting: {original_version}")

    # Try different DSMR versions
    versions_to_try = ["5", "4", "2", "6"]

    # Remove the current version from the list
    if original_version in versions_to_try:
        versions_to_try.remove(original_version)

    # Try each version
    fixed = False
    successful_version = None

    for version in versions_to_try:
        if try_dsmr_version(version):
            fixed = True
            successful_version = version
            break

    # Final report
    print_header("Fix Results")

    if fixed:
        print_success(
            f"The consumption issue has been fixed by changing the DSMR version to {successful_version}!"
        )
        print(
            "\nThe new setting has been saved. You should now see consumption data in the dashboard."
        )
    else:
        print_error("Could not fix the consumption issue by changing the DSMR version.")
        print(f"\nRestoring original DSMR version: {original_version}")

        # Restore original version
        settings = DataloggerSettings.get_solo()
        settings.dsmr_version = original_version
        settings.save()

        # Restart services
        print("Restarting services...")
        os.system("./reload.sh")

        print("\nPossible solutions:")
        print("1. Check the wiring of your smart meter")
        print(
            "2. Contact your energy provider to check if your smart meter is correctly configured"
        )
        print("3. Check the DSMR Reader logs for any errors")
        print(
            "4. Try manually changing other settings in the DSMR Reader admin interface"
        )


def manual_fix():
    """Manually fix the consumption issue by setting electricity_currently_delivered based on phase power."""
    print_header("Manual Fix for Consumption Data")

    # Check if there are readings with zero consumption but non-zero phase power
    readings_to_fix = DsmrReading.objects.filter(
        electricity_currently_delivered=0,
        timestamp__gte=timezone.now() - timezone.timedelta(hours=24),
    ).exclude(
        phase_currently_delivered_l1=None,
        phase_currently_delivered_l2=None,
        phase_currently_delivered_l3=None,
    )

    count = readings_to_fix.count()

    if count == 0:
        print_warning("No readings found that need fixing.")
        return

    print(f"Found {count} readings with zero consumption but non-zero phase power.")

    # Ask for confirmation
    confirm = input(
        "\nDo you want to fix these readings by setting electricity_currently_delivered to the sum of phase power? (y/n): "
    )

    if confirm.lower() != "y":
        print("Manual fix aborted.")
        return

    # Fix the readings
    fixed_count = 0

    for reading in readings_to_fix:
        phase_power = (
            (reading.phase_currently_delivered_l1 or Decimal("0"))
            + (reading.phase_currently_delivered_l2 or Decimal("0"))
            + (reading.phase_currently_delivered_l3 or Decimal("0"))
        )

        if phase_power > 0:
            reading.electricity_currently_delivered = phase_power
            reading.save(update_fields=["electricity_currently_delivered"])
            fixed_count += 1

    print_success(f"Fixed {fixed_count} readings.")
    print("The dashboard should now show consumption data for these readings.")


if __name__ == "__main__":
    print("DSMR Reader Consumption Fix Tool")
    print("\nOptions:")
    print("1. Automatic fix (try different DSMR versions)")
    print("2. Manual fix (set electricity_currently_delivered based on phase power)")
    print("3. Exit")

    choice = input("\nChoose an option (1-3): ")

    if choice == "1":
        fix_consumption_issue()
    elif choice == "2":
        manual_fix()
    else:
        print("Exiting...")
