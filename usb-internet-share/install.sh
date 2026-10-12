#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
(( EUID == 0 )) || { printf 'Run this installer with sudo: sudo %s\n' "$0" >&2; exit 1; }

install -D -m 0755 "$ROOT/bin/usb-internet-share" /usr/local/bin/usb-internet-share
install -D -m 0755 "$ROOT/bin/usb-internet-share-menu" /usr/local/bin/usb-internet-share-menu
install -D -m 0644 "$ROOT/packaging/usb-internet-share.desktop" /usr/local/share/applications/usb-internet-share.desktop

if [[ ! -e /etc/usb-internet-share.conf ]]; then
  install -D -m 0644 "$ROOT/config/usb-internet-share.conf" /etc/usb-internet-share.conf
fi

printf 'Installed USB Internet Share.\n'
printf 'Edit /etc/usb-internet-share.conf if automatic interface selection is ambiguous.\n'
printf 'Run: usb-internet-share check\n'
