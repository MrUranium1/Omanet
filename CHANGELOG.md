# Changelog

## Unreleased

### Fixed
- Background `dnsmasq` and the monitor no longer inherit the start/stop lock
  (fd 9), which previously made `stop` and the monitor's auto-cleanup fail with
  "another start/stop operation is in progress".
- Monitor no longer tears sharing down before the link has come up once, and no
  longer dies silently when the carrier file is unreadable (interface down).
- Monitor's dead `if ! read_state` branch removed.
- Rollback failure warning in `rollback_start` is now reachable.
- Address cleanup match no longer matches look-alikes such as `110.203.0.1/24`.

### Changed
- Forward chain uses `policy accept` with explicit drops for the USB interface
  only, so Docker/libvirt/VM forwarding is not disturbed while sharing.
- dnsmasq now runs with `--no-hosts` and `--dhcp-authoritative`.
- Runtime directory is `0755` so dnsmasq can reach its files after dropping
  privileges (the state file remains `0600`).
- The script can be sourced for testing (`main` only runs when executed).

### Added
- Unit checks for helper functions, shellcheck in the test script, GitHub
  Actions CI, hardware test checklist, CHANGELOG.
