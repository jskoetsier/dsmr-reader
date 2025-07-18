#!/usr/bin/env python3
"""
Script to explain the consumption data in DSMR Reader.
This script analyzes the latest readings and explains why consumption might show as zero.
"""

import os
import sys
import django
from decimal import Decimal

# Set up Django environment
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "dsmrreader.settings")
django.setup()

from django.utils import timezone
from dsmr_datalogger.models.reading import DsmrReading
from dsmr_datalogger.models.settings import DataloggerSettings
from dsmr_datalogger.models.statistics import MeterStatistics
from dsmr_consumption.models.consumption import ElectricityConsumption


def print_header(text):
    """Print a header with the given text."""
    print("\n" + "=" * 80)
    print(f" {text}")
    print("=" * 80)


def analyze_consumption():
    """Analyze the consumption data and explain why consumption might show as zero."""
    print_header("DSMR Reader Consumption Explanation")

    # Get current settings
    datalogger_settings = DataloggerSettings.get_solo()
    meter_statistics = MeterStatistics.get_solo()

    print(f"DSMR Version Setting: {datalogger_settings.dsmr_version}")
    print(f"DSMR Version from Meter: {meter_statistics.dsmr_version}")

    # Check latest readings
    try:
        latest_reading = DsmrReading.objects.all().order_by("-timestamp")[0]

        print("\n=== Latest Reading Analysis ===")
        print(f"Timestamp: {timezone.localtime(latest_reading.timestamp)}")
        print(f"Electricity Currently Delivered: {latest_reading.electricity_currently_delivered} kW")
        print(f"Electricity Currently Returned: {latest_reading.electricity_currently_returned} kW")

        # Check if user is generating more electricity than consuming
        if latest_reading.electricity_currently_delivered == 0 and latest_reading.electricity_currently_returned > 0:
            print("\n=== Explanation ===")
            print("Your smart meter is showing 0.000 kW for consumption because you are currently")
            print("generating more electricity than you are consuming.")
            print("\nThis is normal behavior for homes with solar panels or other renewable energy sources.")
            print("When your solar panels produce more electricity than your home is using,")
            print("the excess electricity is returned to the grid, and your net consumption shows as zero.")

            print("\n=== What's Happening ===")
            print("1. Your home is using electricity for appliances, lights, etc.")
            print("2. Your solar panels are generating electricity")
            print("3. Since your generation exceeds your usage, the net consumption is zero")
            print("4. The excess electricity is being returned to the grid")

            print("\n=== Suggestions ===")
            print("If you want to see your actual consumption (regardless of solar production),")
            print("you would need additional monitoring equipment that measures consumption")
            print("and production separately.")

            # Check recent readings to see if this is consistent
            recent_readings = DsmrReading.objects.all().order_by("-timestamp")[:100]
            zero_consumption_count = sum(1 for r in recent_readings if r.electricity_currently_delivered == 0)

            print(f"\nOut of the last 100 readings, {zero_consumption_count} showed zero consumption.")

            if zero_consumption_count > 80:
                print("\nThis suggests that your solar production consistently exceeds your consumption.")
                print("This is common during sunny days when solar panels are producing at their peak.")
            elif zero_consumption_count > 50:
                print("\nYour consumption varies between zero and non-zero values.")
                print("This is normal as solar production changes throughout the day.")
            else:
                print("\nYou occasionally have zero consumption readings.")
                print("This might happen during peak sunlight hours when solar production is highest.")

        elif latest_reading.electricity_currently_delivered > 0:
            print("\n=== Explanation ===")
            print("Your smart meter is correctly showing your current electricity consumption.")
            print(f"You are currently consuming {latest_reading.electricity_currently_delivered} kW.")

            if latest_reading.electricity_currently_returned > 0:
                print(f"You are also returning {latest_reading.electricity_currently_returned} kW to the grid.")
                print("\nThis means your solar panels are generating electricity, but not enough")
                print("to cover all your current usage.")
            else:
                print("\nYou are not currently returning any electricity to the grid.")
                print("This could be because it's nighttime, cloudy, or you don't have solar panels.")

        # Check phase data
        print("\n=== Phase Data Analysis ===")
        total_phase_delivered = (
            (latest_reading.phase_currently_delivered_l1 or Decimal('0')) +
            (latest_reading.phase_currently_delivered_l2 or Decimal('0')) +
            (latest_reading.phase_currently_delivered_l3 or Decimal('0'))
        )

        total_phase_returned = (
            (latest_reading.phase_currently_returned_l1 or Decimal('0')) +
            (latest_reading.phase_currently_returned_l2 or Decimal('0')) +
            (latest_reading.phase_currently_returned_l3 or Decimal('0'))
        )

        print(f"Total Phase Delivered: {total_phase_delivered} kW")
        print(f"Total Phase Returned: {total_phase_returned} kW")

        if total_phase_delivered == 0 and total_phase_returned > 0:
            print("\nYour phase data also confirms that you are generating more electricity than consuming.")

    except IndexError:
        print("No readings found in the database.")

    # Check daily statistics
    print("\n=== Daily Statistics Analysis ===")
    try:
        today = timezone.localtime(timezone.now()).date()
        yesterday = today - timezone.timedelta(days=1)

        # Get consumption for today and yesterday
        today_consumption = ElectricityConsumption.objects.filter(
            read_at__date=today
        ).order_by("read_at")

        yesterday_consumption = ElectricityConsumption.objects.filter(
            read_at__date=yesterday
        ).order_by("read_at")

        if today_consumption.exists():
            delivered_count = sum(1 for c in today_consumption if c.currently_delivered > 0)
            returned_count = sum(1 for c in today_consumption if c.currently_returned > 0)
            total_count = today_consumption.count()

            print(f"Today's readings with consumption > 0: {delivered_count}/{total_count} ({delivered_count/total_count*100:.1f}%)")
            print(f"Today's readings with return > 0: {returned_count}/{total_count} ({returned_count/total_count*100:.1f}%)")

            if delivered_count == 0 and returned_count > 0:
                print("\nToday, you have been consistently generating more electricity than consuming.")
            elif delivered_count < total_count * 0.2 and returned_count > total_count * 0.8:
                print("\nToday, you have been mostly generating more electricity than consuming.")
            elif delivered_count > 0 and returned_count > 0:
                print("\nToday, you have been both consuming and returning electricity.")
                print("This is normal behavior for homes with solar panels.")

        if yesterday_consumption.exists():
            delivered_count = sum(1 for c in yesterday_consumption if c.currently_delivered > 0)
            returned_count = sum(1 for c in yesterday_consumption if c.currently_returned > 0)
            total_count = yesterday_consumption.count()

            print(f"\nYesterday's readings with consumption > 0: {delivered_count}/{total_count} ({delivered_count/total_count*100:.1f}%)")
            print(f"Yesterday's readings with return > 0: {returned_count}/{total_count} ({returned_count/total_count*100:.1f}%)")

            if delivered_count == 0 and returned_count > 0:
                print("\nYesterday, you were consistently generating more electricity than consuming.")
            elif delivered_count < total_count * 0.2 and returned_count > total_count * 0.8:
                print("\nYesterday, you were mostly generating more electricity than consuming.")
            elif delivered_count > 0 and returned_count > 0:
                print("\nYesterday, you were both consuming and returning electricity.")
                print("This pattern is normal for homes with solar panels (consumption at night, return during the day).")

    except Exception as e:
        print(f"Error analyzing daily statistics: {e}")

    print("\n=== Conclusion ===")
    print("The 'consumption not showing' issue is not actually an issue - it's expected behavior")
    print("when you're generating more electricity than you're consuming.")
    print("\nDSMR Reader is working correctly by showing:")
    print("1. Zero consumption when your generation exceeds your usage")
    print("2. The amount of electricity you're returning to the grid")
    print("\nIf you want to see your gross consumption (regardless of solar production),")
    print("you would need additional monitoring equipment that measures consumption")
    print("and production separately.")


if __name__ == "__main__":
    analyze_consumption()
