#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT/bin/usb-internet-share"
FAILURES=0

pass() {
    printf 'ok   - %s\n' "$1"
}

fail() {
    printf 'FAIL - %s\n' "$1"
    FAILURES=$((FAILURES + 1))
}

for file in \
    "$CLI" \
    "$ROOT/bin/usb-internet-share-menu" \
    "$ROOT/install.sh" \
    "$ROOT/scripts/install-dependencies.sh" \
    "$ROOT/uninstall.sh"
do
    if bash -n "$file"; then
        pass "syntax: ${file#"$ROOT"/}"
    else
        fail "syntax: ${file#"$ROOT"/}"
    fi
done

if "$CLI" help | grep -q 'start|stop|status|help'; then
    pass "help output"
else
    fail "help output"
fi

if "$CLI" invalid-command >/dev/null 2>&1; then
    fail "unknown command is rejected"
else
    pass "unknown command is rejected"
fi

status=$("$CLI" status 2>&1 || true)
if [[ "$status" == *"usb-internet-share.service"* ]]; then
    pass "status shows systemd service"
else
    fail "status shows systemd service"
fi

if (( FAILURES > 0 )); then
    printf '\n%d test(s) failed.\n' "$FAILURES"
    exit 1
fi

printf '\nAll checks passed.\n'
