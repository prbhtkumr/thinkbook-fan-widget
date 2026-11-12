#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo ./backend/install.sh" >&2
    exit 1
fi

here="$(cd "$(dirname "$0")" && pwd)"

install -Dm755 "$here/thinkbook-fan-curve.py" /usr/local/sbin/thinkbook-fan-curve.py
install -Dm644 "$here/thinkbook-fan-curve.service" /etc/systemd/system/thinkbook-fan-curve.service
install -Dm644 "$here/thinkpad_acpi.conf" /etc/modprobe.d/thinkpad_acpi.conf
install -Dm644 "$here/thinkpad_acpi-load.conf" /etc/modules-load.d/thinkpad_acpi.conf

systemctl daemon-reload
systemctl enable thinkbook-fan-curve.service
systemctl restart thinkbook-fan-curve.service

echo "Backend installed."
echo "Check status: systemctl status thinkbook-fan-curve.service"
