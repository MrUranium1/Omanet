#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if (( EUID == 0 )); then
    echo "Run this installer as your normal user, without sudo." >&2
    exit 1
fi

if ! "$ROOT/scripts/install-dependencies.sh"; then
    echo "Dependency check failed; OmaNet was not installed." >&2
    exit 1
fi

if ! systemctl --user is-system-running >/dev/null 2>&1; then
    echo "Your user systemd manager is not ready." >&2
    exit 1
fi

install -D -m 0755 "$ROOT/bin/usb-internet-share" \
    "$HOME/.local/bin/usb-internet-share"
install -D -m 0755 "$ROOT/bin/usb-internet-share-menu" \
    "$HOME/.local/bin/usb-internet-share-menu"
install -D -m 0644 "$ROOT/packaging/usb-internet-share.service" \
    "$HOME/.config/systemd/user/usb-internet-share.service"

mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/usb-internet-share.desktop" <<EOF_DESKTOP
[Desktop Entry]
Type=Application
Name=OmaNet
Comment=Share laptop internet with an Android phone over USB
Exec=$HOME/.local/bin/usb-internet-share-menu
Terminal=true
Categories=Network;Utility;
EOF_DESKTOP

systemctl --user daemon-reload

echo "OmaNet installed for $USER."
echo "Start with: usb-internet-share start"
echo "Stop with:  usb-internet-share stop"
echo "Status with: usb-internet-share status"
