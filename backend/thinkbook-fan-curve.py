#!/usr/bin/env python3
"""AC-aware fan curve for Lenovo ThinkBook 15 G2 ITL.

Uses thinkpad_acpi's /proc/acpi/ibm/fan level interface (0 = off, 7 = max).
Writes state for the panel widget to /run/thinkbook-fan/state and reads a
pinned level from /run/thinkbook-fan/pin.
"""

import grp
import json
import os
import signal
import sys
import time

FAN = "/proc/acpi/ibm/fan"
POWER_SUPPLY = "/sys/class/power_supply"
AC_ONLINE = "/sys/class/power_supply/ACAD/online"
STATE_DIR = "/run/thinkbook-fan"
PIN_FILE = os.path.join(STATE_DIR, "pin")
STATE_FILE = os.path.join(STATE_DIR, "state")
POLL_SECONDS = 2
REFRESH_SECONDS = 30
HYSTERESIS_C = 3
EMERGENCY_C = 90
SAFETY_C = 95

# (up_threshold_C, fan_level). Level 0 = off/min, 7 = max.
AC_CURVE = [
    (88, 7),
    (81, 6),
    (74, 5),
    (66, 4),
    (59, 3),
    (51, 2),
    (0, 1),
]
BATTERY_CURVE = [
    (92, 7),
    (86, 5),
    (79, 4),
    (71, 3),
    (63, 2),
    (0, 0),
]


def read_int(path):
    try:
        with open(path) as fh:
            return int(fh.read().strip())
    except (OSError, ValueError):
        return None


def read_override():
    """Return a pinned fan level from PIN_FILE if it is still valid."""
    try:
        with open(PIN_FILE) as fh:
            parts = fh.read().split()
    except OSError:
        return None
    if not parts:
        return None
    try:
        level = int(parts[0])
        if not 0 <= level <= 7:
            return None
        if len(parts) > 1 and time.time() > float(parts[1]):
            return None
    except ValueError:
        return None
    return level


def read_temp_c():
    values = []
    for path in (
        "/sys/class/thermal/thermal_zone7/temp",  # x86_pkg_temp
        "/sys/class/thermal/thermal_zone8/temp",  # TCPU (DPTF)
    ):
        millideg = read_int(path)
        if millideg is not None:
            values.append(millideg / 1000.0)

    hwmon_root = "/sys/class/hwmon"
    try:
        hwmons = os.listdir(hwmon_root)
    except OSError:
        hwmons = []
    for hw in hwmons:
        base = os.path.join(hwmon_root, hw)
        try:
            with open(os.path.join(base, "name")) as fh:
                if fh.read().strip() != "coretemp":
                    continue
        except OSError:
            continue
        try:
            entries = os.listdir(base)
        except OSError:
            continue
        for entry in entries:
            if entry.startswith("temp") and entry.endswith("_input"):
                millideg = read_int(os.path.join(base, entry))
                if millideg is not None:
                    values.append(millideg / 1000.0)
    return max(values) if values else None


def on_ac():
    if read_int(AC_ONLINE) == 1:
        return True

    # Fallback for USB-C charging and charge-threshold ("Not charging") states.
    try:
        supplies = os.listdir(POWER_SUPPLY)
    except OSError:
        return False
    for entry in supplies:
        base = os.path.join(POWER_SUPPLY, entry)
        try:
            with open(os.path.join(base, "type")) as fh:
                if fh.read().strip() != "Battery":
                    continue
            with open(os.path.join(base, "status")) as fh:
                status = fh.read().strip()
        except OSError:
            continue
        if status in ("Charging", "Full", "Not charging"):
            return True
    return False


def curve_for(ac):
    return AC_CURVE if ac else BATTERY_CURVE


def desired_level(temp_c, ac):
    curve = curve_for(ac)
    for threshold, level in curve:
        if temp_c >= threshold:
            return level
    return curve[-1][1]


def level_threshold(level, ac):
    for threshold, lvl in curve_for(ac):
        if lvl == level:
            return threshold
    return None


def write_level(level):
    with open(FAN, "w") as fh:
        fh.write(f"level {level}\n")


def ensure_state_dir():
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
    except OSError as exc:
        print(f"cannot create {STATE_DIR}: {exc}", flush=True)
        return
    try:
        gid = grp.getgrnam("users").gr_gid
        os.chown(STATE_DIR, 0, gid)
    except (KeyError, OSError):
        pass
    try:
        os.chmod(STATE_DIR, 0o775)
    except OSError:
        pass


def write_state(level, mode, temp, ac, pin):
    data = {
        "level": level,
        "mode": mode,
        "temp": None if temp is None else round(temp),
        "ac": bool(ac),
        "pin": pin,
        "updated": int(time.time()),
    }
    tmp = STATE_FILE + ".tmp"
    try:
        with open(tmp, "w") as fh:
            json.dump(data, fh, separators=(",", ":"))
        os.chmod(tmp, 0o644)
        os.replace(tmp, STATE_FILE)
    except OSError as exc:
        print(f"state write failed: {exc}", flush=True)


def main():
    if not os.path.exists(FAN):
        print("fan interface /proc/acpi/ibm/fan not present", flush=True)
        return 0

    ensure_state_dir()

    stopping = False

    def stop(_signum, _frame):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    current = None
    last_ac = None
    last_write = 0.0
    last_temp = None

    while not stopping:
        temp = read_temp_c()
        if temp is None:
            time.sleep(POLL_SECONDS)
            continue
        last_temp = temp

        ac = on_ac()
        pinned = read_override()
        pin_active = pinned is not None and temp < SAFETY_C
        if pin_active:
            want = pinned
        else:
            want = 7 if temp >= EMERGENCY_C else desired_level(temp, ac)

        if ac != last_ac:
            current = None
            last_ac = ac

        if pin_active:
            target = pinned
        elif current is None:
            target = want
        elif want > current:
            target = want
        elif want < current:
            threshold = level_threshold(current, ac)
            if threshold is not None and temp > threshold - HYSTERESIS_C:
                target = current
            else:
                # Step down one level at a time to avoid overshooting.
                target = max(want, current - 1)
        else:
            target = current

        if target != current:
            try:
                write_level(target)
                pin_note = " pin" if pin_active else ""
                print(
                    f"{time.strftime('%H:%M:%S')} temp={temp:.0f}C "
                    f"ac={int(ac)} level {current}->{target}{pin_note}",
                    flush=True,
                )
                current = target
                last_write = time.time()
            except OSError as exc:
                print(f"fan write failed: {exc}", flush=True)
        elif time.time() - last_write >= REFRESH_SECONDS:
            try:
                write_level(current)
                last_write = time.time()
            except OSError:
                pass

        mode = "pin" if pin_active else ("ac" if ac else "battery")
        write_state(current, mode, temp, ac, pinned if pin_active else None)
        time.sleep(POLL_SECONDS)

    write_state(None, "off", last_temp, on_ac(), None)
    try:
        with open(FAN, "w") as fh:
            fh.write("level auto\n")
        print("restored level auto", flush=True)
    except OSError as exc:
        print(f"failed to restore level auto: {exc}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
