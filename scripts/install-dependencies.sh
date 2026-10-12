#!/usr/bin/env bash
#
# install-dependencies.sh
#
# Check for OmaNet's runtime dependencies (GNirehtet and ADB), detect the
# system package manager, and offer to install whatever is missing.
#
# Nothing is installed without explicit consent: either an interactive "yes"
# or the --yes flag. If consent is declined, an install fails, or the system
# is unsupported, the script explains exactly what still needs to be done.
#
# The script is invoked by install.sh and is safe to run on its own from any
# working directory.

set -Eeuo pipefail

# Command used for privileged installs. Tests and unusual environments can
# override this (set it empty to run package managers directly).
SUDO="${OMANET_SUDO-sudo}"

# Set to 1 by --yes for scripted installs.
ASSUME_YES=0

log() { printf '%s\n' "$*"; }
note() { printf '%s\n' "$*" >&2; }

usage() {
    printf '%s\n' \
        'Usage: install-dependencies.sh [--yes] [--help]' \
        '' \
        'Checks for GNirehtet and ADB and offers to install anything missing' \
        'using the system package manager. Packages are installed only after' \
        'explicit consent.' \
        '' \
        '  --yes    Assume "yes" to the install prompt (for scripted use).' \
        '  --help   Show this help.'
}

# Print the first supported package manager found on PATH, or return 1.
find_manager() {
    local manager
    for manager in pacman apt-get dnf zypper apk brew; do
        if command -v "$manager" >/dev/null 2>&1; then
            printf '%s' "$manager"
            return 0
        fi
    done
    return 1
}

# Print the first AUR helper found on PATH, or return 1.
find_aur_helper() {
    local helper
    for helper in yay paru; do
        if command -v "$helper" >/dev/null 2>&1; then
            printf '%s' "$helper"
            return 0
        fi
    done
    return 1
}

# Print the ADB package name for a package manager, or return 1 if unknown.
adb_package_for() {
    case "$1" in
        pacman) printf 'android-tools' ;;
        apt-get) printf 'adb' ;;
        dnf) printf 'android-tools' ;;
        zypper) printf 'android-tools' ;;
        apk) printf 'android-tools' ;;
        brew) printf 'android-platform-tools' ;;
        *) return 1 ;;
    esac
}

run_privileged() {
    if [[ -n "$SUDO" ]]; then
        "$SUDO" "$@"
    else
        "$@"
    fi
}

# Install distro packages with the detected package manager.
install_packages() {
    local manager="$1"
    shift
    case "$manager" in
        pacman) run_privileged pacman -S --needed --noconfirm "$@" ;;
        apt-get) run_privileged apt-get install -y "$@" ;;
        dnf) run_privileged dnf install -y "$@" ;;
        zypper) run_privileged zypper --non-interactive install "$@" ;;
        apk) run_privileged apk add "$@" ;;
        brew) brew install "$@" ;;
        *) return 1 ;;
    esac
}

# Install AUR packages with an AUR helper.
install_aur_packages() {
    local helper="$1"
    shift
    "$helper" -S --needed --noconfirm "$@"
}

# Ask for explicit consent. Returns 0 only on a clear yes. A closed or empty
# stdin counts as "no" so nothing is ever installed silently.
confirm_install() {
    local reply=""
    if (( ASSUME_YES )); then
        return 0
    fi
    read -r -p "Install the missing dependencies now? [y/N] " reply || true
    case "$reply" in
        [yY] | [yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# Explain how to install the given dependencies by hand.
manual_instructions() {
    note ""
    note "Install the missing dependencies manually, then re-run ./install.sh:"
    local dep
    for dep in "$@"; do
        case "$dep" in
            gnirehtet)
                note "  - gnirehtet: https://github.com/Genymobile/gnirehtet/releases"
                note "    (Arch Linux: AUR package gnirehtet-bin, e.g. via yay or paru)"
                ;;
            adb)
                note "  - adb (Android platform tools): install your distribution's"
                note "    android-tools / adb package"
                ;;
            *)
                note "  - $dep"
                ;;
        esac
    done
    note "Both 'gnirehtet' and 'adb' must be available on your PATH."
}

main() {
    while (( $# )); do
        case "$1" in
            --yes) ASSUME_YES=1 ;;
            -h | --help)
                usage
                return 0
                ;;
            *)
                note "unknown argument: $1"
                usage >&2
                return 2
                ;;
        esac
        shift
    done

    # Never run as root: AUR helpers (yay/paru) refuse to build as root, and
    # system packages should go through the user's normal sudo path instead.
    if (( EUID == 0 )); then
        note "Run this script as your normal user, without sudo."
        note "It uses sudo itself for system packages and never runs AUR helpers as root."
        return 1
    fi

    local need_gnirehtet=0
    local need_adb=0
    if ! command -v gnirehtet >/dev/null 2>&1; then
        need_gnirehtet=1
    fi
    if ! command -v adb >/dev/null 2>&1; then
        need_adb=1
    fi

    if (( !need_gnirehtet && !need_adb )); then
        log "Dependencies OK: gnirehtet and adb are already installed."
        return 0
    fi

    local missing=()
    if (( need_gnirehtet )); then
        missing+=("gnirehtet")
    fi
    if (( need_adb )); then
        missing+=("adb")
    fi
    log "Missing dependencies: ${missing[*]}"

    local manager
    if ! manager="$(find_manager)"; then
        note "No supported package manager was detected (looked for pacman, apt-get, dnf, zypper, apk, brew)."
        manual_instructions "${missing[@]}"
        return 1
    fi
    log "Detected package manager: $manager"

    local packages=()
    local aur_packages=()

    if (( need_adb )); then
        local adb_package
        if adb_package="$(adb_package_for "$manager")"; then
            packages+=("$adb_package")
        fi
    fi

    if (( need_gnirehtet )) && [[ "$manager" == "pacman" ]] && find_aur_helper >/dev/null; then
        aur_packages+=("gnirehtet-bin")
    fi

    if (( ${#packages[@]} == 0 && ${#aur_packages[@]} == 0 )); then
        note "Nothing can be installed automatically for this system."
        manual_instructions "${missing[@]}"
        return 1
    fi

    log "Planned installation:"
    if (( ${#packages[@]} > 0 )); then
        log "  $manager: ${packages[*]}"
    fi
    if (( ${#aur_packages[@]} > 0 )); then
        log "  AUR: ${aur_packages[*]}"
    fi

    if ! confirm_install; then
        note "Installation declined; no packages were installed."
        manual_instructions "${missing[@]}"
        return 1
    fi

    if (( ${#packages[@]} > 0 )); then
        if ! install_packages "$manager" "${packages[@]}"; then
            note "Package installation failed."
        fi
    fi

    if (( ${#aur_packages[@]} > 0 )); then
        local helper
        helper="$(find_aur_helper)"
        if ! install_aur_packages "$helper" "${aur_packages[@]}"; then
            note "AUR installation failed."
        fi
    fi

    # Report exactly what is present now and what is still missing, so the
    # caller never reports success while a dependency is unaccounted for.
    local installed=()
    local still_missing=()

    if (( need_gnirehtet )); then
        if command -v gnirehtet >/dev/null 2>&1; then
            installed+=("gnirehtet")
        else
            still_missing+=("gnirehtet")
        fi
    fi

    if (( need_adb )); then
        if command -v adb >/dev/null 2>&1; then
            installed+=("adb")
        else
            still_missing+=("adb")
        fi
    fi

    if (( ${#installed[@]} > 0 )); then
        log "Installed: ${installed[*]}"
    fi

    if (( ${#still_missing[@]} > 0 )); then
        note "Still missing: ${still_missing[*]}"
        manual_instructions "${still_missing[@]}"
        return 1
    fi

    log "All required dependencies are now installed."
    return 0
}

main "$@"
