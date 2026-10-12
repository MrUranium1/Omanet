#!/usr/bin/env bash
set -Eeuo pipefail

(( EUID == 0 )) || { printf 'Run this uninstaller with sudo: sudo %s\n' "$0" >&2; exit 1; }

if [[ -x /usr/local/bin/usb-internet-share ]] && [[ -e /run/usb-internet-share/state ]]; then
  /usr/local/bin/usb-internet-share stop
fi

rm -f -- \
  /usr/local/bin/usb-internet-share \
  /usr/local/bin/usb-internet-share-menu \
  /usr/local/share/applications/usb-internet-share.desktop

printf 'Removed USB Internet Share executables and desktop entry.\n'
printf 'Configuration /etc/usb-internet-share.conf was preserved; remove it manually if no longer needed.\n'
