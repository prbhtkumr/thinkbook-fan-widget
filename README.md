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
- Pick Auto: remove the pin and let the AC/battery curve run.

The compact display shows `L<level>` and `AC`, `BAT`, or `PIN`. The tooltip shows the package temperature.

## Settings

Right click the widget and choose Configure.

- Minimum fan level: 3 to 7. This clamps both manual pins and the AC/battery curve.
- Show icon: uncheck to hide the icon. Clearing the icon field also hides it.
- Icon: a theme icon name such as `cpu`, or a path such as `../icons/fan.svg`. The default is the bundled fan icon.

The widget writes the minimum level to `/run/thinkbook-fan/min-level`. The service reads it and keeps the fan at or above that level.

## How it works

The service writes `/run/thinkbook-fan/state` every 2 seconds. The widget reads that file with the Plasma executable data engine. Changing the level writes `/run/thinkbook-fan/pin`. The service reads the pin file and writes the level to `/proc/acpi/ibm/fan`.

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
