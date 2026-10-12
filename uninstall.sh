#!/usr/bin/env bash
set -Eeuo pipefail

if (( EUID == 0 )); then
    echo "Run this uninstaller as your normal user, without sudo." >&2
    exit 1
fi

systemctl --user stop usb-internet-share.service 2>/dev/null || true

rm -f \
    "$HOME/.local/bin/usb-internet-share" \
    "$HOME/.local/bin/usb-internet-share-menu" \
    "$HOME/.local/share/applications/usb-internet-share.desktop" \
    "$HOME/.config/systemd/user/usb-internet-share.service"

systemctl --user daemon-reload
systemctl --user reset-failed usb-internet-share.service 2>/dev/null || true

echo "USB Internet Share removed for $USER."
echo "GNirehtet itself was not uninstalled."
