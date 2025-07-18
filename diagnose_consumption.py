#!/usr/bin/env python3
"""
Script to diagnose issues with consumption data in DSMR Reader.
This script checks the latest readings in the database and prints relevant information.
"""

import os
import sys
import django

# Set up Django environment
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "dsmrreader.settings")
django.setup()

from django.utils import timezone
from dsmr_datalogger.models.reading import DsmrReading
from dsmr_datalogger.models.settings import DataloggerSettings
from dsmr_datalogger.models.statistics import MeterStatistics
from dsmr_consumption.models.consumption import ElectricityConsumption


def check_latest_readings():
    """Check the latest readings in the database."""
    print("\n=== DSMR Reader Diagnostics ===\n")

    # Check DSMR version
    datalogger_settings = DataloggerSettings.get_solo()
    meter_statistics = MeterStatistics.get_solo()

    print(f"DSMR Version Setting: {datalogger_settings.dsmr_version}")
    print(f"DSMR Version from Meter: {meter_statistics.dsmr_version}")
    print(f"Serial Port: {datalogger_settings.serial_port}")
    print(f"Input Method: {datalogger_settings.input_method}")

    # Check latest readings
    try:
        latest_reading = DsmrReading.objects.all().order_by("-timestamp")[0]
        print("\n=== Latest DSMR Reading ===")
        print(f"Timestamp: {timezone.localtime(latest_reading.timestamp)}")
        print(f"Electricity Currently Delivered: {latest_reading.electricity_currently_delivered} kW")
        print(f"Electricity Currently Returned: {latest_reading.electricity_currently_returned} kW")

        # Check phase data
        print("\n=== Phase Data ===")
        print(f"Phase L1 Currently Delivered: {latest_reading.phase_currently_delivered_l1} kW")
        print(f"Phase L2 Currently Delivered: {latest_reading.phase_currently_delivered_l2} kW")
        print(f"Phase L3 Currently Delivered: {latest_reading.phase_currently_delivered_l3} kW")
        print(f"Phase L1 Currently Returned: {latest_reading.phase_currently_returned_l1} kW")
        print(f"Phase L2 Currently Returned: {latest_reading.phase_currently_returned_l2} kW")
        print(f"Phase L3 Currently Returned: {latest_reading.phase_currently_returned_l3} kW")

        # Check voltage data
        print("\n=== Voltage Data ===")
        print(f"Phase L1 Voltage: {latest_reading.phase_voltage_l1} V")
        print(f"Phase L2 Voltage: {latest_reading.phase_voltage_l2} V")
        print(f"Phase L3 Voltage: {latest_reading.phase_voltage_l3} V")

        # Check current data
        print("\n=== Current Data ===")
        print(f"Phase L1 Current: {latest_reading.phase_power_current_l1} A")
        print(f"Phase L2 Current: {latest_reading.phase_power_current_l2} A")
        print(f"Phase L3 Current: {latest_reading.phase_power_current_l3} A")

        # Check multiple recent readings to see if there's a pattern
        print("\n=== Recent Readings (Last 5) ===")
        recent_readings = DsmrReading.objects.all().order_by("-timestamp")[:5]
        for idx, reading in enumerate(recent_readings):
            print(f"\nReading {idx+1}:")
            print(f"  Timestamp: {timezone.localtime(reading.timestamp)}")
            print(f"  Electricity Currently Delivered: {reading.electricity_currently_delivered} kW")
            print(f"  Electricity Currently Returned: {reading.electricity_currently_returned} kW")
            print(f"  Phase L1 Currently Delivered: {reading.phase_currently_delivered_l1} kW")
            print(f"  Phase L2 Currently Delivered: {reading.phase_currently_delivered_l2} kW")
            print(f"  Phase L3 Currently Delivered: {reading.phase_currently_delivered_l3} kW")

        # Check if the sum of phase power matches the total power
        total_phase_power = (
            (latest_reading.phase_currently_delivered_l1 or 0) +
            (latest_reading.phase_currently_delivered_l2 or 0) +
            (latest_reading.phase_currently_delivered_l3 or 0)
        )

        print("\n=== Power Consistency Check ===")
        print(f"Total Electricity Currently Delivered: {latest_reading.electricity_currently_delivered} kW")
        print(f"Sum of Phase Power Delivered: {total_phase_power} kW")

        if abs(latest_reading.electricity_currently_delivered - total_phase_power) < 0.01:
            print("✓ Total power matches sum of phase power")
        else:
            print("✗ Total power does NOT match sum of phase power")
            print("  This might indicate an issue with the meter readings or configuration.")

    except IndexError:
        print("No DSMR readings found in the database.")

    # Check latest electricity consumption
    try:
        latest_consumption = ElectricityConsumption.objects.all().order_by("-read_at")[0]
        print("\n=== Latest Electricity Consumption ===")
        print(f"Read At: {timezone.localtime(latest_consumption.read_at)}")
        print(f"Currently Delivered: {latest_consumption.currently_delivered} kW")
        print(f"Currently Returned: {latest_consumption.currently_returned} kW")
    except IndexError:
        print("\nNo electricity consumption records found in the database.")

    print("\n=== Recommendations ===")

    # Check if electricity_currently_delivered is consistently 0
    zero_delivered_count = DsmrReading.objects.filter(
        electricity_currently_delivered=0,
        timestamp__gte=timezone.now() - timezone.timedelta(hours=24)
    ).count()

    total_recent_count = DsmrReading.objects.filter(
        timestamp__gte=timezone.now() - timezone.timedelta(hours=24)
    ).count()

    if total_recent_count > 0:
        zero_delivered_percentage = (zero_delivered_count / total_recent_count) * 100
        print(f"Readings with zero consumption in last 24h: {zero_delivered_percentage:.1f}%")

        if zero_delivered_percentage > 90:
            print("\n1. Your meter appears to consistently report zero consumption.")
            print("   Possible causes:")
            print("   - Incorrect DSMR version setting (currently set to {})".format(datalogger_settings.dsmr_version))
            print("   - Smart meter configuration issue")
            print("   - Wiring issue")
            print("\n   Try changing the DSMR version setting to another value:")
            print("   - For Dutch smart meters: 4")
            print("   - For Belgian Fluvius meters: 5")
            print("   - For Luxembourg Smarty meters: 6")
            print("   - For older Dutch meters: 2")

            # Check if phase power is reported but total is not
            if total_phase_power > 0 and latest_reading.electricity_currently_delivered == 0:
                print("\n2. Your meter is reporting phase power but not total power.")
                print("   This suggests a possible issue with the DSMR protocol version.")
                print("   Try changing the DSMR version setting.")
        else:
            print("\nYour meter appears to be reporting consumption correctly at times.")
            print("Check if there's a pattern to when consumption is reported as zero.")

    print("\nFor further assistance, please contact your energy provider or check the DSMR Reader documentation.")


if __name__ == "__main__":
    check_latest_readings()
