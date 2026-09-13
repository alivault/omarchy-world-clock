"""Render all clocks at one instant using the system IANA timezone database."""

import json
import sys
from datetime import datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError, available_timezones


DEFAULT_ZONES = [
    {"label": "New York", "zone": "America/New_York"},
    {"label": "London", "zone": "Europe/London"},
    {"label": "Bergen", "zone": "Europe/Oslo"},
    {"label": "Istanbul", "zone": "Europe/Istanbul"},
    {"label": "Tokyo", "zone": "Asia/Tokyo"},
]


def city_catalog():
    """Offline timezone locations, with useful city aliases for shared zones."""
    regions = {"Africa", "America", "Antarctica", "Asia", "Atlantic",
               "Australia", "Europe", "Indian", "Pacific"}
    choices = [{"label": zone.rsplit("/", 1)[-1].replace("_", " "), "zone": zone}
               for zone in available_timezones() if zone.split("/")[0] in regions]
    choices += [
        {"label": "Home", "zone": ""},
        {"label": "UTC", "zone": "UTC"},
        {"label": "Bergen", "zone": "Europe/Oslo"},
        {"label": "Cupertino", "zone": "America/Los_Angeles"},
        {"label": "Mumbai", "zone": "Asia/Kolkata"},
    ]
    choices.sort(key=lambda city: (city["label"].casefold(), city["zone"]))
    return {"defaults": DEFAULT_ZONES, "choices": choices}


def offset_label(minutes):
    sign = "+" if minutes >= 0 else "−"
    hours, remainder = divmod(abs(minutes), 60)
    return f"{sign}{hours}:{remainder:02d}" if remainder else f"{sign}{hours} HRS"


def clocks(zones=None, hour_format="12h", now=None, home_zone=None):
    now = now or datetime.now(timezone.utc)
    home = now.astimezone(ZoneInfo(home_zone)) if home_zone else now.astimezone()
    result = []
    for config in DEFAULT_ZONES if zones is None else zones:
        zone = str(config.get("zone", ""))
        label = str(config.get("label") or zone.split("/")[-1].replace("_", " ") or "Home")
        try:
            local = now.astimezone(ZoneInfo(zone)) if zone else home
        except (ZoneInfoNotFoundError, ValueError):
            result.append({"label": label, "detail": "Unknown timezone", "time": "—", "period": ""})
            continue
        days = (local.date() - home.date()).days
        day = {-1: "Yesterday", 0: "Today", 1: "Tomorrow"}.get(days, f"{days:+d} days")
        minutes = int((local.utcoffset() - home.utcoffset()).total_seconds() / 60)
        use_12h = hour_format != "24h"
        hour = (local.hour % 12 or 12) if use_12h else local.hour
        time = f"{hour}:{local.minute:02d}" if use_12h else f"{hour:02d}:{local.minute:02d}"
        result.append({
            "label": label,
            "detail": f"{day}, {offset_label(minutes)}",
            "time": time,
            "period": ("AM" if local.hour < 12 else "PM") if use_12h else "",
        })
    return result


if __name__ == "__main__":
    if sys.argv[1:] == ["--catalog"]:
        print(json.dumps(city_catalog(), ensure_ascii=False))
        raise SystemExit(0)
    zones = json.loads(sys.argv[1]) if len(sys.argv) > 1 else None
    if zones is not None and (not isinstance(zones, list) or not all(isinstance(z, dict) for z in zones)):
        raise SystemExit("zones must be a list of objects with label and zone fields")
    print(json.dumps(clocks(zones, sys.argv[2] if len(sys.argv) > 2 else "12h"), ensure_ascii=False))
