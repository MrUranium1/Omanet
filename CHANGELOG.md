# Changelog

## Unreleased

### Changed
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
