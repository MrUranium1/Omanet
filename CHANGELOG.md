# Changelog

## Unreleased

### Added
- Added `scripts/install-dependencies.sh`, which checks for GNirehtet and ADB, detects the system package manager, and offers to install missing dependencies only after explicit consent.
- `install.sh` now runs the dependency check during installation.
- Added mocked dependency tests (`tests/dependencies.sh`) that never install real packages.
- Added a marketplace preview image (`preview.png`).
- Added the `license` field (`MIT`) to `manifest.json`.

### Changed
- Standardized the user-facing product name to OmaNet (bar widget title and tooltip, CLI menu heading, installer/uninstaller messages, desktop entry, systemd unit description, README title, and plugin display name). Internal identifiers are unchanged: the plugin id, CLI command names, systemd service name, and install paths are all retained for backward compatibility.
- Rewrote the README: added a quick start, documented the bar-widget controls, expanded the Android setup steps, added a troubleshooting section, and documented the license.
- Qualified the `qs.Commons` palette as `Commons.Color` in `BarWidget.qml` for Qt 6.12 compatibility.
- Reworked internet sharing to use GNirehtet for Android reverse tethering.
- Use a user-level systemd service to manage the GNirehtet process.
- Provide a command-line interface to start, stop, and check sharing status.
- Provide a simple terminal menu for common actions.
- Install the utility and service configuration for the current user.

### Removed from the active approach
- The previous custom USB networking, DHCP, forwarding, and NAT setup is no longer used by the main utility.

### Testing
- Added smoke checks for Bash syntax, CLI help, invalid commands, and service status.
- Added a GitHub Actions workflow to run the checks.
