#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo ./backend/uninstall.sh" >&2
    exit 1
fi

systemctl disable --now thinkbook-fan-curve.service 2>/dev/null || true

rm -f /etc/systemd/system/thinkbook-fan-curve.service
rm -f /usr/local/sbin/thinkbook-fan-curve.py
rm -f /etc/modprobe.d/thinkpad_acpi.conf
rm -f /etc/modules-load.d/thinkpad_acpi.conf

systemctl daemon-reload

echo "Backend removed."
