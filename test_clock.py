import unittest
from datetime import datetime, timezone

from clock import clocks, offset_label, city_catalog, DEFAULT_ZONES


class ClockTests(unittest.TestCase):
    def test_offline_catalog(self):
        catalog = city_catalog()
        self.assertEqual(catalog["defaults"], DEFAULT_ZONES)
        self.assertIn({"label": "New York", "zone": "America/New_York"}, catalog["choices"])
        self.assertIn({"label": "Bergen", "zone": "Europe/Oslo"}, catalog["choices"])
        self.assertIn({"label": "Home", "zone": ""}, catalog["choices"])
        self.assertGreater(len(catalog["choices"]), 100)
        self.assertEqual(catalog["choices"], sorted(catalog["choices"], key=lambda city: (city["label"].casefold(), city["zone"])))
        self.assertEqual(len(catalog["choices"]), len({(city["label"], city["zone"]) for city in catalog["choices"]}))

    def test_default_cities(self):
        self.assertEqual([row["label"] for row in clocks()],
                         ["New York", "London", "Bergen", "Istanbul", "Tokyo"])

    def test_midnight_and_fractional_offsets(self):
        now = datetime(2026, 1, 1, 23, 45, tzinfo=timezone.utc)
        rows = clocks([{"label": "Mumbai", "zone": "Asia/Kolkata"},
                       {"label": "Kathmandu", "zone": "Asia/Kathmandu"}], now=now, home_zone="UTC")
        self.assertEqual(rows[0], {"label": "Mumbai", "detail": "Tomorrow, +5:30", "time": "5:15", "period": "AM"})
        self.assertEqual(rows[1]["detail"], "Tomorrow, +5:45")

    def test_dst_changes_at_the_actual_transition(self):
        zones = [{"zone": "America/Los_Angeles"}]
        before = clocks(zones, now=datetime(2026, 3, 8, 9, 59, tzinfo=timezone.utc), home_zone="UTC")[0]
        after = clocks(zones, now=datetime(2026, 3, 8, 10, 0, tzinfo=timezone.utc), home_zone="UTC")[0]
        self.assertEqual((before["time"], before["detail"]), ("1:59", "Today, −8 HRS"))
        self.assertEqual((after["time"], after["detail"]), ("3:00", "Today, −7 HRS"))

    def test_yesterday_and_24_hour_time(self):
        row = clocks([{"zone": "America/Los_Angeles"}], "24h",
                     datetime(2026, 1, 1, 0, 0, tzinfo=timezone.utc), "UTC")[0]
        self.assertEqual((row["time"], row["period"], row["detail"]), ("16:00", "", "Yesterday, −8 HRS"))

    def test_noon_midnight_home_and_invalid_zone(self):
        for hour, time, period in [(0, "12:00", "AM"), (12, "12:00", "PM")]:
            row = clocks([{"label": "Home", "zone": ""}], now=datetime(2026, 1, 1, hour, tzinfo=timezone.utc), home_zone="UTC")[0]
            self.assertEqual((row["time"], row["period"], row["detail"]), (time, period, "Today, +0 HRS"))
        self.assertEqual(clocks([{"zone": "Not/AZone"}])[0]["time"], "—")
        self.assertEqual(clocks([]), [])
        self.assertEqual(offset_label(-210), "−3:30")


if __name__ == "__main__":
    unittest.main()
