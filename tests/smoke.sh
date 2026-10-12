#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
SCRIPT="$ROOT/bin/usb-internet-share"
failures=0

pass() { printf 'ok   - %s\n' "$1"; }
bad()  { printf 'FAIL - %s\n' "$1" >&2; failures=$((failures + 1)); }

expect_eq() { # description expected actual
  if [[ $2 == "$3" ]]; then pass "$1"; else bad "$1 (expected '$2', got '$3')"; fi
}

# --- syntax ---------------------------------------------------------------
for f in bin/usb-internet-share bin/usb-internet-share-menu install.sh uninstall.sh; do
  if bash -n "$ROOT/$f"; then pass "bash -n $f"; else bad "bash -n $f"; fi
done

# --- shellcheck (skipped if not installed) ---------------------------------
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "$SCRIPT" "$ROOT/bin/usb-internet-share-menu" "$ROOT/install.sh" \
      "$ROOT/uninstall.sh" "$ROOT/tests/smoke.sh"; then
    pass "shellcheck"
  else
    bad "shellcheck"
  fi
else
  printf 'skip - shellcheck not installed\n'
fi

# --- CLI behaviour ---------------------------------------------------------
if "$SCRIPT" --help >/dev/null; then pass "--help exits 0"; else bad "--help exits 0"; fi
if "$SCRIPT" invalid >/dev/null 2>&1; then bad "unknown command fails"; else pass "unknown command fails"; fi
if "$SCRIPT" start extra >/dev/null 2>&1; then bad "start rejects extra args"; else pass "start rejects extra args"; fi
if "$SCRIPT" start >/dev/null 2>&1 && (( EUID != 0 )); then bad "start requires root"; else pass "start requires root (or ran as root)"; fi
expect_eq "status is inactive without state" "usb-internet-share: inactive" "$("$SCRIPT" status)"

# --- pure helper functions (script is sourceable) --------------------------
# shellcheck source=../bin/usb-internet-share disable=SC1091
source "$SCRIPT"

expect_eq "ipv4_to_int 10.203.0.1"  "181075969" "$(ipv4_to_int 10.203.0.1)"
expect_eq "ipv4_to_int 0.0.0.0"     "0"          "$(ipv4_to_int 0.0.0.0)"
expect_eq "ipv4_to_int 255.255.255.255" "4294967295" "$(ipv4_to_int 255.255.255.255)"
if ipv4_to_int 256.1.1.1 >/dev/null 2>&1; then bad "ipv4_to_int rejects 256"; else pass "ipv4_to_int rejects 256"; fi
if ipv4_to_int 1.2.3 >/dev/null 2>&1; then bad "ipv4_to_int rejects short"; else pass "ipv4_to_int rejects short"; fi

expect_eq "route_range /24" "181075968 181076223" "$(route_range 10.203.0.0/24)"
expect_eq "route_range host" "181075969 181075969" "$(route_range 10.203.0.1)"
expect_eq "route_range /8"  "167772160 184549375" "$(route_range 10.0.0.0/8)"
if route_range 0.0.0.0/0 >/dev/null 2>&1; then bad "route_range rejects /0"; else pass "route_range rejects /0"; fi
if route_range 10.0.0.0/33 >/dev/null 2>&1; then bad "route_range rejects /33"; else pass "route_range rejects /33"; fi
if route_range local >/dev/null 2>&1; then bad "route_range rejects keywords"; else pass "route_range rejects keywords"; fi

# overlap logic used by check_network_available
read -r ts te < <(route_range "$SHARE_NETWORK")
overlaps() { local s e; read -r s e < <(route_range "$1"); (( ts <= e && s <= te )); }
if overlaps 10.0.0.0/8; then pass "overlap: 10.0.0.0/8 conflicts"; else bad "overlap: 10.0.0.0/8 conflicts"; fi
if overlaps 192.168.1.0/24; then bad "overlap: 192.168.1.0/24 is clear"; else pass "overlap: 192.168.1.0/24 is clear"; fi
if overlaps 110.203.0.0/24; then bad "overlap: 110.203.0.0/24 is clear"; else pass "overlap: 110.203.0.0/24 is clear"; fi

if valid_iface_name wlan0; then pass "iface name wlan0"; else bad "iface name wlan0"; fi
if valid_iface_name enx0123456789ab; then pass "iface name enx..."; else bad "iface name enx..."; fi
if valid_iface_name 'bad name'; then bad "iface name rejects space"; else pass "iface name rejects space"; fi
if valid_iface_name 'a;rm'; then bad "iface name rejects ;"; else pass "iface name rejects ;"; fi
if valid_iface_name 'waytoolonginterfacename'; then bad "iface name rejects >15"; else pass "iface name rejects >15"; fi
expect_eq "trim_space" "a b" "$(trim_space '   a b  ')"

# address-match regex used by stop_locked must not match look-alikes
re="inet ${SHARE_CIDR//./\\.}( |\$)"
if grep -Eq "$re" <<< '3: usb0    inet 10.203.0.1/24 brd 10.203.0.255 scope global usb0'; then
  pass "stop regex matches real address"; else bad "stop regex matches real address"; fi
if grep -Eq "$re" <<< '3: usb0    inet 110.203.0.1/24 brd 110.203.0.255 scope global usb0'; then
  bad "stop regex ignores 110.203.0.1/24"; else pass "stop regex ignores 110.203.0.1/24"; fi

if (( failures > 0 )); then
  printf '%d check(s) failed.\n' "$failures" >&2
  exit 1
fi
printf 'All checks passed.\n'
