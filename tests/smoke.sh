#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

bash -n "$ROOT/bin/usb-internet-share"
bash -n "$ROOT/bin/usb-internet-share-menu"
bash -n "$ROOT/install.sh"
bash -n "$ROOT/uninstall.sh"

"$ROOT/bin/usb-internet-share" --help >/dev/null
if "$ROOT/bin/usb-internet-share" invalid >/dev/null 2>&1; then
  printf 'unknown command unexpectedly succeeded\n' >&2
  exit 1
fi

printf 'Smoke checks passed.\n'
