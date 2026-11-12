#!/usr/bin/env python3
"""AC-aware fan curve for Lenovo ThinkBook 15 G2 ITL.

Uses thinkpad_acpi's /proc/acpi/ibm/fan level interface (0 = off, 7 = max).
Writes state for the panel widget to /run/thinkbook-fan/state and reads a
pinned level from /run/thinkbook-fan/pin.

Curve selection is read from /run/thinkbook-fan/curves. The file uses one
key=value line per power state: ac, default, power-save. Values are auto,
power-save, or aggressive.
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
PLATFORM_PROFILE = "/sys/firmware/acpi/platform_profile"
STATE_DIR = "/run/thinkbook-fan"
PIN_FILE = os.path.join(STATE_DIR, "pin")
STATE_FILE = os.path.join(STATE_DIR, "state")
MIN_LEVEL_FILE = os.path.join(STATE_DIR, "min-level")
CURVE_FILE = os.path.join(STATE_DIR, "curves")
MIN_LEVEL = 3
POLL_SECONDS = 2
REFRESH_SECONDS = 30
HYSTERESIS_C = 3
EMERGENCY_C = 90
SAFETY_C = 95
LOW_BATTERY_PERCENT = 20
TEMP_WINDOW = 3

# (up_threshold_C, fan_level). Level 3 is the lowest allowed, 7 is max.
CURVES = {
    "auto": [
        (88, 7),
        (81, 6),
        (74, 5),
        (66, 4),
        (0, 3),
    ],
    "power-save": [
        (94, 7),
        (88, 5),
        (82, 4),
        (0, 3),
    ],
    "aggressive": [
        (80, 7),
        (74, 6),
        (68, 5),
        (60, 4),
        (0, 3),
    ],
}
DEFAULT_CURVES = {"ac": "auto", "default": "auto", "power-save": "power-save"}


def read_int(path):
    try:
        with open(path) as fh:
            return int(fh.read().strip())
    except (OSError, ValueError):
        return None


def read_string(path):
    try:
        with open(path) as fh:
            return fh.read().strip()
    except OSError:
        return ""


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


def read_min_level():
    value = read_int(MIN_LEVEL_FILE)
    if value is None:
        return MIN_LEVEL
    return max(MIN_LEVEL, min(7, value))


def read_curve_config():
    config = dict(DEFAULT_CURVES)
    try:
        with open(CURVE_FILE) as fh:
            for line in fh:
                key, sep, value = line.strip().partition("=")
                if sep and key in config and value in CURVES:
                    config[key] = value
    except OSError:
        pass
    return config


def battery_capacity():
    try:
        supplies = os.listdir(POWER_SUPPLY)
    except OSError:
        return None
    for entry in supplies:
        base = os.path.join(POWER_SUPPLY, entry)
        try:
            with open(os.path.join(base, "type")) as fh:
                if fh.read().strip() != "Battery":
                    continue
        except OSError:
            continue
        return read_int(os.path.join(base, "capacity"))
    return None


def platform_profile():
    return read_string(PLATFORM_PROFILE)


def power_state(ac):
    if ac:
        return "ac"
    capacity = battery_capacity()
    if platform_profile() == "low-power" or (
        capacity is not None and capacity <= LOW_BATTERY_PERCENT
    ):
        return "power-save"
    return "default"


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


def desired_level(temp_c, curve):
    for threshold, level in curve:
        if temp_c >= threshold:
            return level
    return curve[-1][1]


def level_threshold(level, curve):
    for threshold, lvl in curve:
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


def write_state(level, mode, temp, ac, pin, curve, control=None):
    data = {
        "level": level,
        "mode": mode,
        "curve": curve,
        "temp": None if temp is None else round(temp),
        "control": None if control is None else round(control),
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
    temp_history = []

    while not stopping:
        temp = read_temp_c()
        if temp is None:
            time.sleep(POLL_SECONDS)
            continue
        last_temp = temp
        temp_history.append(temp)
        if len(temp_history) > TEMP_WINDOW:
            temp_history.pop(0)
        control_temp = sorted(temp_history)[len(temp_history) // 2]

        ac = on_ac()
        min_level = read_min_level()
        curve_config = read_curve_config()
        state_name = power_state(ac)
        curve_name = curve_config[state_name]
        curve = CURVES[curve_name]
        pinned = read_override()
        pin_active = pinned is not None and control_temp < SAFETY_C
        emergency = control_temp >= EMERGENCY_C
        if pin_active:
            want = max(min_level, pinned)
        else:
            want = 7 if emergency else max(
                min_level, desired_level(control_temp, curve)
            )

        if ac != last_ac:
            current = None
            last_ac = ac

        if emergency:
            target = 7
        elif pin_active:
            target = max(min_level, pinned)
        elif current is None:
            target = want
        elif want > current:
            # Step up one level at a time to avoid jumps.
            target = min(want, current + 1)
        elif want < current:
            threshold = level_threshold(current, curve)
            if threshold is not None and control_temp > threshold - HYSTERESIS_C:
                target = current
            else:
                # Step down one level at a time to avoid overshooting.
                target = max(min_level, max(want, current - 1))
        else:
            target = current

        if target != current:
            try:
                write_level(target)
                pin_note = " pin" if pin_active else ""
                print(
                    f"{time.strftime('%H:%M:%S')} temp={temp:.0f}C "
                    f"control={control_temp:.0f}C ac={int(ac)} "
                    f"level {current}->{target}{pin_note} "
                    f"state={state_name} curve={curve_name}",
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

        mode = "pin" if pin_active else state_name
        effective_pin = max(min_level, pinned) if pin_active else None
        write_state(
            current,
            mode,
            temp,
            ac,
            effective_pin,
            None if pin_active else curve_name,
            control_temp,
        )
        time.sleep(POLL_SECONDS)

    write_state(None, "off", last_temp, on_ac(), None, None, None)
    try:
        with open(FAN, "w") as fh:
            fh.write("level auto\n")
        print("restored level auto", flush=True)
    except OSError as exc:
        print(f"failed to restore level auto: {exc}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
