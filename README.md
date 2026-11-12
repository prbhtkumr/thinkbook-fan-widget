# ThinkBook Fan Widget

Plasma 6 panel widget for the fan curve service on a Lenovo ThinkBook 15 G2 ITL.

The widget shows the current fan level and whether the service is on AC, on battery, or pinned. Click it to open the level menu. Scroll over it to move one level. Selecting Auto returns control to the AC/battery curve.

## Requirements

- Plasma 6
- Lenovo ThinkBook 15 G2 ITL
- `thinkpad_acpi` with `fan_control=1`
- Python 3

The fan controls are specific to this laptop. Other models may expose different EC registers.

## Install

### Backend

```bash
sudo ./backend/install.sh
```

This installs the fan curve service and the `thinkpad_acpi` module options.

### Widget

```bash
kpackagetool6 --type Plasma/Applet --install .
```

Open the panel context menu, choose Add Widgets, and search for ThinkBook Fan.

## Use

- Left click: open the level menu.
- Scroll up or down over the widget: change the fan level one step.
- Pick 3 to 7: pin that level.
- Pick a curve: follow that curve and remove any pin.

When a level is pinned, the curve buttons lose their highlight. The pinned level is the only active control.

The compact title can show the icon, level, status, and temperature. The tooltip shows the package temperature in the selected unit.

## Curves

Three presets are available:

- Balanced: balanced response
- Power Save: quieter, with higher temperature thresholds
- Aggressive: earlier ramp and higher levels

In Settings, choose which preset applies to each power state:

- On AC power
- Default, meaning on battery
- On power save, meaning the platform profile is low-power or the battery is at or below 20 percent

The active curve is shown in the popup and tooltip. The popup curve buttons change the curve for the current power state and remove any manual pin. The compact display shows the status as `AC`, `BAT`, or `PWR` when status is enabled.

## Settings

Right click the widget and choose Configure.

- Minimum fan level: 3 to 7. This clamps manual pins and every curve.
- Temperature: System locale, Celsius, or Fahrenheit. The default follows the system locale. A changed setting is saved.
- On AC power: curve used while plugged in.
- Default: curve used on battery.
- On power save: curve used in power save.
- Title: choose which items appear in the compact display: icon, level, status, temperature.
- Icon: a theme icon name such as `cpu`, or a path such as `../icons/fan.svg`. The default is the bundled fan icon. Clearing the field also hides the icon.

The widget writes the minimum level to `/run/thinkbook-fan/min-level` and the curve selection to `/run/thinkbook-fan/curves`. The service reads both within 2 seconds.

## How it works

The service writes `/run/thinkbook-fan/state` every 2 seconds. The widget reads that file with the Plasma executable data engine. Changing the level writes `/run/thinkbook-fan/pin`. The service reads the pin file and writes the level to `/proc/acpi/ibm/fan`.

The curve file contains one line per power state:

```text
ac=auto
default=auto
power-save=power-save
```

Balanced is stored as `auto` in this file.

The service uses the median of the last three temperature samples for curve decisions and moves the fan one level per poll. A single short spike does not move the fan. The raw temperature is still reported in the state and shown in the widget.

The service creates `/run/thinkbook-fan` as group writable for the `users` group. If your user is not in that group, change the group in `backend/thinkbook-fan-curve.py` or adjust the directory after the service starts.

## Notes

- Fan RPM is not exposed on this machine. The widget shows the level and temperature.
- Stopping the service writes `level auto` back to the EC.
- If the pin file cannot be written, the widget shows the error in the popup.

## Uninstall

```bash
sudo ./backend/uninstall.sh
kpackagetool6 --type Plasma/Applet --remove io.github.prbhtkumr.thinkbookfan
```

## License

MIT
