#!/usr/bin/env bash
#
# Tests for scripts/install-dependencies.sh
#
# Every package manager is replaced by a fake executable on a throwaway PATH,
# so these tests never install real packages and never touch the host system.

set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/install-dependencies.sh"

BASH_BIN="$(command -v bash)"
ENV_BIN="$(command -v env)"
CHMOD_BIN="$(command -v chmod)"
DIRNAME_BIN="$(command -v dirname)"

FAILURES=0
WORKDIR=""
FAKEBIN=""
LOG=""
OUT=""
CODE=0
RUN_SUDO="sudo"
STDIN_FILE=""

pass() { printf 'ok   - %s\n' "$1"; }
fail() {
    printf 'FAIL - %s\n' "$1"
    FAILURES=$((FAILURES + 1))
}

cleanup() {
    if [[ -n "$WORKDIR" && -d "$WORKDIR" ]]; then
        rm -rf "$WORKDIR"
    fi
}
trap cleanup EXIT

# Create a fresh, isolated fake PATH for one test case.
setup_env() {
    if [[ -n "$WORKDIR" && -d "$WORKDIR" ]]; then
        rm -rf "$WORKDIR"
    fi
    WORKDIR="$(mktemp -d)"
    FAKEBIN="$WORKDIR/bin"
    LOG="$WORKDIR/calls.log"
    mkdir -p "$FAKEBIN"
    : > "$LOG"
    # Only dirname is needed from the host; everything else is faked below.
    ln -s "$DIRNAME_BIN" "$FAKEBIN/dirname"
    CHMOD="$CHMOD_BIN"
    export FAKEBIN LOG CHMOD
    RUN_SUDO="sudo"
    STDIN_FILE="$WORKDIR/stdin"
    : > "$STDIN_FILE"
}

# A harmless fake command used to represent "already installed" binaries.
add_fake() {
    local name="$1"
    {
        printf '#!%s\n' "$BASH_BIN"
        printf 'exit 0\n'
    } > "$FAKEBIN/$name"
    chmod +x "$FAKEBIN/$name"
}

# sudo that logs and then runs its arguments via the fake PATH.
add_fake_sudo() {
    {
        printf '#!%s\n' "$BASH_BIN"
        cat <<'BODY'
printf '%s\n' "sudo $*" >> "$LOG"
exec "$@"
BODY
    } > "$FAKEBIN/sudo"
    chmod +x "$FAKEBIN/sudo"
}

# pacman that logs and "provides" adb when asked to install android-tools.
add_fake_pacman() {
    {
        printf '#!%s\n' "$BASH_BIN"
        cat <<'BODY'
printf '%s\n' "pacman $*" >> "$LOG"
for arg in "$@"; do
  case "$arg" in
    android-tools)
      printf '#!/bin/bash\nexit 0\n' > "$FAKEBIN/adb"
      "$CHMOD" +x "$FAKEBIN/adb"
      ;;
  esac
done
exit 0
BODY
    } > "$FAKEBIN/pacman"
    chmod +x "$FAKEBIN/pacman"
}

# yay that logs and "provides" gnirehtet when asked for gnirehtet-bin.
add_fake_yay() {
    {
        printf '#!%s\n' "$BASH_BIN"
        cat <<'BODY'
printf '%s\n' "yay $*" >> "$LOG"
for arg in "$@"; do
  case "$arg" in
    gnirehtet-bin)
      printf '#!/bin/bash\nexit 0\n' > "$FAKEBIN/gnirehtet"
      "$CHMOD" +x "$FAKEBIN/gnirehtet"
      ;;
  esac
done
exit 0
BODY
    } > "$FAKEBIN/yay"
    chmod +x "$FAKEBIN/yay"
}

# pacman that fails, to exercise the failed-installation path.
add_fake_pacman_failing() {
    {
        printf '#!%s\n' "$BASH_BIN"
        cat <<'BODY'
printf '%s\n' "pacman $*" >> "$LOG"
exit 1
BODY
    } > "$FAKEBIN/pacman"
    chmod +x "$FAKEBIN/pacman"
}

# apt-get that logs and "provides" adb when asked to install adb.
add_fake_apt() {
    {
        printf '#!%s\n' "$BASH_BIN"
        cat <<'BODY'
printf '%s\n' "apt-get $*" >> "$LOG"
for arg in "$@"; do
  case "$arg" in
    adb)
      printf '#!/bin/bash\nexit 0\n' > "$FAKEBIN/adb"
      "$CHMOD" +x "$FAKEBIN/adb"
      ;;
  esac
done
exit 0
BODY
    } > "$FAKEBIN/apt-get"
    chmod +x "$FAKEBIN/apt-get"
}

# Run the installer with the fake PATH. Reads stdin from $STDIN_FILE.
run_script() {
    set +e
    OUT="$("$ENV_BIN" PATH="$FAKEBIN" OMANET_SUDO="$RUN_SUDO" "$BASH_BIN" "$SCRIPT" "$@" < "$STDIN_FILE" 2>&1)"
    CODE=$?
    set -e
}

assert_code() {
    if [[ "$CODE" -eq "$1" ]]; then
        pass "$2"
    else
        fail "$2 (expected exit $1, got $CODE)"
    fi
}

assert_out_contains() {
    if grep -qF -- "$1" <<<"$OUT"; then
        pass "$2"
    else
        fail "$2 (output did not contain: $1)"
    fi
}

assert_log_contains() {
    if grep -qF -- "$1" "$LOG"; then
        pass "$2"
    else
        fail "$2 (log did not contain: $1)"
    fi
}

assert_log_empty() {
    if [[ ! -s "$LOG" ]]; then
        pass "$1"
    else
        fail "$1 (unexpected calls: $(tr '\n' ';' <"$LOG"))"
    fi
}

assert_log_not_contains() {
    if grep -qF -- "$1" "$LOG"; then
        fail "$2 (log unexpectedly contained: $1)"
    else
        pass "$2"
    fi
}

assert_executable() {
    if [[ -x "$FAKEBIN/$1" ]]; then
        pass "$2"
    else
        fail "$2"
    fi
}

# --- syntax ----------------------------------------------------------------

if bash -n "$SCRIPT"; then
    pass "syntax: scripts/install-dependencies.sh"
else
    fail "syntax: scripts/install-dependencies.sh"
fi

if [[ -x "$SCRIPT" ]]; then
    pass "script is executable"
else
    fail "script is executable"
fi

# --- all dependencies present ---------------------------------------------

setup_env
add_fake_sudo
add_fake gnirehtet
add_fake adb
run_script --yes
assert_code 0 "all present: exits 0"
assert_out_contains "already installed" "all present: reports success"
assert_log_empty "all present: installs nothing"

# --- adb missing, install via pacman --------------------------------------

setup_env
add_fake_sudo
add_fake gnirehtet
add_fake_pacman
run_script --yes
assert_code 0 "pacman: exits 0"
assert_log_contains "android-tools" "pacman: installs android-tools"
assert_log_contains "sudo pacman" "pacman: install runs through sudo"
assert_executable adb "pacman: provides adb"

# --- gnirehtet missing, no AUR helper -------------------------------------

setup_env
add_fake_sudo
add_fake adb
add_fake_pacman
run_script --yes
assert_code 1 "no AUR helper: exits non-zero"
assert_out_contains "Nothing can be installed automatically" "no AUR helper: explains"
assert_log_empty "no AUR helper: installs nothing"

# --- adb installs but gnirehtet cannot (no AUR helper) --------------------

setup_env
add_fake_sudo
add_fake_pacman
run_script --yes
assert_code 1 "partial: exits non-zero"
assert_out_contains "Installed: adb" "partial: reports adb installed"
assert_out_contains "Still missing: gnirehtet" "partial: reports gnirehtet missing"
assert_log_contains "sudo pacman -S --needed --noconfirm android-tools" "partial: installed adb"
assert_executable adb "partial: adb is now present"

# --- package installation fails -------------------------------------------

setup_env
add_fake_sudo
add_fake_pacman_failing
run_script --yes
assert_code 1 "failed install: exits non-zero"
assert_out_contains "Package installation failed" "failed install: reports failure"
assert_out_contains "Still missing: gnirehtet adb" "failed install: reports what is missing"
assert_out_contains "manually" "failed install: gives manual steps"

# --- unsupported environment ----------------------------------------------

setup_env
add_fake_sudo
add_fake gnirehtet
run_script --yes
assert_code 1 "unsupported: exits non-zero"
assert_out_contains "No supported package manager" "unsupported: explains"
assert_log_empty "unsupported: installs nothing"

# --- declined prompt -------------------------------------------------------

setup_env
add_fake_sudo
add_fake_pacman
printf 'n\n' > "$STDIN_FILE"
run_script
assert_code 1 "declined: exits non-zero"
assert_out_contains "declined" "declined: reports no install"
assert_log_empty "declined: installs nothing"

# --- closed stdin never installs silently ---------------------------------

setup_env
add_fake_sudo
add_fake_pacman
run_script
assert_code 1 "empty stdin: exits non-zero"
assert_out_contains "declined" "empty stdin: refuses to install"
assert_log_empty "empty stdin: installs nothing"

# --- pacman + yay install both dependencies -------------------------------

setup_env
add_fake_sudo
add_fake_pacman
add_fake_yay
run_script --yes
assert_code 0 "pacman+yay: exits 0"
assert_log_contains "android-tools" "pacman+yay: installs android-tools"
assert_log_contains "yay -S --needed --noconfirm gnirehtet-bin" "pacman+yay: installs gnirehtet-bin via AUR"
assert_log_not_contains "sudo yay" "pacman+yay: AUR helper not run via sudo"
assert_log_not_contains "sudo paru" "pacman+yay: AUR helper not run via sudo"
assert_executable adb "pacman+yay: provides adb"
assert_executable gnirehtet "pacman+yay: provides gnirehtet"

# --- apt-get, without sudo override ---------------------------------------

setup_env
add_fake gnirehtet
add_fake_apt
RUN_SUDO=""
run_script --yes
assert_code 0 "apt-get: exits 0"
assert_log_contains "apt-get install -y adb" "apt-get: installs adb"
assert_executable adb "apt-get: provides adb"

# --- refuses to run as root (AUR helpers must not run as root) -------------

if unshare -r "$BASH_BIN" -c 'exit 0' >/dev/null 2>&1; then
    setup_env
    add_fake gnirehtet
    add_fake adb
    set +e
    OUT="$(unshare -r "$BASH_BIN" "$SCRIPT" --yes 2>&1)"
    CODE=$?
    set -e
    assert_code 1 "root: exits non-zero"
    assert_out_contains "normal user" "root: refuses to run as root"
    assert_log_empty "root: installs nothing"
else
    printf 'skip - root guard (user namespaces unavailable)\n'
fi

# --- help ------------------------------------------------------------------

setup_env
run_script --help
assert_code 0 "help: exits 0"
assert_out_contains "Usage:" "help: prints usage"
assert_log_empty "help: installs nothing"

if (( FAILURES > 0 )); then
    printf '\n%d test(s) failed.\n' "$FAILURES"
    exit 1
fi

printf '\nAll dependency tests passed.\n'
