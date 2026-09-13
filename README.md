# Omarchy World Clock

![Omarchy World Clock showing New York, London, Bergen, Istanbul, and Tokyo](preview.png)

A personal Omarchy bar plugin by Ali. Click the globe for a simple city list:
large times, AM/PM, day relative to home, and the current offset from home.
The panel follows your theme. No network, accounts, or third-party plugin code.

Requires Omarchy Quattro (Omarchy 4), Python 3, and the system IANA timezone
database (`tzdata`). No pip packages, install hooks, or build steps are needed.
Clocks refresh on opening and every minute while open, including DST changes.
Home follows your system timezone. Escape/outside-click closes the panel;
Tab switches panels; scroll or Up/Down moves through longer lists.
Right-click the globe to toggle 12/24-hour time. The choice is saved in
`shell.json` and updates any open clocks without closing the panel.

## Install

```bash
omarchy plugin add https://github.com/alivault/omarchy-world-clock.git --enable
```

The globe appears in the right bar section. To move it there explicitly:

```bash
omarchy bar move ali.world-clock --section right
```

## Configure

Edit the `ali.world-clock` entry in `~/.config/omarchy/shell.json`:

```json
{
  "id": "ali.world-clock",
  "hourFormat": "12h",
  "zones": [
    { "label": "Home", "zone": "" },
    { "label": "Bergen", "zone": "Europe/Oslo" },
    { "label": "Tokyo", "zone": "Asia/Tokyo" }
  ]
}
```

Omit `zones` for New York, London, Bergen, Istanbul, and Tokyo. An empty zone
uses your system timezone; list order controls display order. Use `24h` to hide
AM/PM. Optional `fontFamily` defaults to the system bar font. Unknown zones show an em dash,
never a misleading local time. City labels are rendered as plain text.

Open from a command: `omarchy-shell shell summon ali.world-clock`

## Remove

```bash
omarchy plugin remove ali.world-clock
```

## Privacy and permissions

All time calculations run locally using Python's standard-library `zoneinfo`.
There are no network requests, credentials, telemetry, privileged operations,
or persistent background services. A short Python process runs when the panel
opens and each minute while it is open. Right-click explicitly saves the time
format through `omarchy bar set`; other user settings are left intact.

## Development

```bash
./check.sh
omarchy plugin validate .
```

Tests cover DST transitions, midnight/noon, fractional offsets, invalid zones,
12/24-hour formatting, and the default cities.

## License

[MIT](LICENSE).
