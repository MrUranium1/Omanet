# USB Internet Share

A small Bash utility that configures an IPv4 USB network interface on a Linux
laptop to share the laptop's internet connection with a connected device. It
sets the host-side USB interface address, provides DHCP and DNS with `dnsmasq`,
enables IPv4 forwarding, adds narrowly scoped nftables forwarding/NAT rules,
and offers a cleanup command that restores the settings it changed.

**Android reverse tethering is not verified.** Android's standard “USB
tethering” feature normally shares the phone's connection *to* the computer,
which is the opposite direction. This project configures only the Linux host
side. The phone must independently support reverse USB tethering (including
obtaining an address using DHCP) or provide a compatible manual configuration.
No claim is made that stock Android supports this. A cable, USB debugging, or
`adb reverse` alone does not establish this network connection.

If your goal is internet on a stock, unrooted Android phone through a laptop,
look at [Gnirehtet](https://github.com/Genymobile/gnirehtet), which does this
over `adb` instead. This project is better suited to devices that natively act
as USB network clients: a Raspberry Pi Zero in gadget mode (`g_ether` /
`g_ncm`), another Linux machine, or an embedded board or router.

## Features and safety

- Bash-only networking.
- Auto-detects the upstream IPv4 default route and a unique USB network device,
  with optional interface overrides.
- Refuses non-USB devices, identical uplink/USB devices, an already-addressed
  USB interface, conflicting sharing subnets, and a pre-existing nftables table
  with the service's name.
- Temporarily asks NetworkManager to leave the USB device unmanaged when
  `nmcli` reports it as managed, then restores that state on stop.
- Uses its own nftables table; it does not flush or rewrite existing firewall
  rules. Its forwarding chain has `policy accept`, so unrelated forwarding
  (Docker, libvirt, VMs) is not affected. Only traffic entering or leaving the
  USB interface is restricted: USB-to-uplink traffic sourced from the sharing
  subnet and established return traffic are accepted, and everything else
  through the USB interface is dropped. Existing firewall policies in other
  tables may still block the permitted traffic.
- Saves the previous interface-up and IPv4-forwarding states, and cleans up
  only the address, DHCP process, and nftables table created by this utility.
- Starts a lightweight watcher that stops sharing when the USB interface
  disappears or its driver reports sustained carrier loss. The watcher ignores
  "no carrier" until the link has been seen up once (or two minutes have
  passed), so a slow phone-side bring-up does not trigger a teardown. Driver
  carrier reporting varies; use `stop` manually if a disconnect is not
  detected.
- dnsmasq runs with `--no-hosts` (the host's `/etc/hosts` is not served to the
  device) and `--dhcp-authoritative`.

## Requirements

Targeted at Linux systems with Bash and systemd-style `/run` layout; Omarchy is
Arch-based, but the script does not depend on Omarchy internals.

Required runtime commands/packages:

- `bash`
- `ip` from `iproute2`
- `nft` from `nftables`
- `dnsmasq`
- `sysctl` from `procps-ng`; `stat`, `nohup`, and standard file utilities from
  `coreutils`
- `flock` from `util-linux`
- `readlink`, `awk`, `grep`, and `tr` from standard userland

For NetworkManager coordination, install `networkmanager` (`nmcli` is optional;
without it the script will not change NetworkManager's device management).
The graphical toggle additionally needs `rofi` or `wofi`, `pkexec` from
`polkit`, an active Polkit authentication agent, and optionally `notify-send`
from `libnotify`.

On Arch Linux, for example:

```sh
sudo pacman -S iproute2 nftables dnsmasq networkmanager polkit rofi libnotify
```

Packages already present can be omitted. Install/enable a Polkit authentication
agent using your desktop's supported setup; the menu does not install or
configure one.

## Install

From a clone of this project:

```sh
sudo ./install.sh
```

The installer places the commands under `/usr/local/bin`, installs the desktop
launcher, and creates `/etc/usb-internet-share.conf` only if it does not already
exist. It does not install packages or alter Hyprland/Omarchy configuration.

Check dependencies and interface selection before sharing:

```sh
usb-internet-share check
```

If automatic selection is ambiguous, edit `/etc/usb-internet-share.conf` as
root:

```ini
USB_IFACE=enx0123456789ab
UPSTREAM_IFACE=wlan0
```

`USB_IFACE` must be a USB network interface. `UPSTREAM_IFACE` should be the
interface currently providing the laptop's IPv4 internet route. Leave either
setting empty to use automatic selection. The configuration must be a regular,
root-owned file and must not be writable by group or others.

Start and stop from a terminal:

```sh
sudo usb-internet-share start
usb-internet-share status
sudo usb-internet-share stop
```

The graphical application launcher entry is **USB Internet Share**. It offers
a start/stop menu and uses `pkexec` to request authorization. An active Polkit
agent is required. For a Hyprland shortcut, copy the optional line in
`packaging/hyprland-bindings.conf` into a user-owned bindings file, then reload
Hyprland. Check first that the key combination is not already bound:

```ini
bind = SUPER SHIFT, T, exec, usb-internet-share-menu
```

The project does not edit a user's `~/.config` automatically.

## Uninstall

```sh
sudo ./uninstall.sh
```

If sharing is active, the uninstaller first attempts to stop it. It removes
only this project's executables and desktop entry. It preserves
`/etc/usb-internet-share.conf` and installed dependencies. Remove that config
manually if desired.

## Runtime behavior

The host interface is assigned `10.203.0.1/24`. `dnsmasq` leases addresses
`10.203.0.10`–`10.203.0.200`, advertises the host as gateway and DNS server,
and forwards DNS using the host's resolver configuration. IPv4 traffic is
masqueraded out the selected uplink. IPv6 is not configured.

Runtime state and the lock live under `/run`; they do not survive a reboot.
There is no persistent system service. A background watcher attempts automatic
cleanup after disconnect, but always check `usb-internet-share status` and run
`sudo usb-internet-share stop` if it remains active. Monitor output is written
to `/run/usb-internet-share/monitor.log` while the service is active. A
world-readable status marker at `/run/usb-internet-share.active` lets the
unprivileged menu display the current state; it contains only `starting` or
`active`, not interface details. The runtime directory is world-traversable so
`dnsmasq` can reach its lease and log files after dropping privileges; the
saved-state file inside it is `0600` and root-only.

If startup fails, the program attempts rollback and reports when manual cleanup
is needed.

The `net.ipv4.ip_forward` setting is global. The program restores its saved
value on stop, so avoid running another service that relies on changing this
setting concurrently. If startup/cleanup is interrupted by a crash or power
loss, inspect `usb-internet-share status` and run `sudo usb-internet-share
stop` before starting again. A reboot clears runtime nftables rules and state.

## Limitations

- Android reverse-tether support varies by device, Android version, vendor, and
  any extra phone-side software. It has not been tested or verified by this
  project.
- Disconnect cleanup is best-effort: it detects interface removal and a driver
  reporting no carrier for 30 seconds. Some USB network drivers do not expose
  reliable carrier status, so use the manual `stop` command if needed.
- This handles IPv4 only; it does not configure IPv6, USB gadget mode on the
  phone, Android settings, or phone-side routes.
- The selected shared subnet is fixed at `10.203.0.0/24`. Start is refused if
  an existing IPv4 route or host address overlaps it.
- nftables rules are additive and isolated in a dedicated table, but a host
  firewall can independently reject forwarded traffic, or block the device's
  DHCP/DNS requests to the host. The utility does not rewrite firewalld, ufw,
  or other firewall policy.
- DHCP/DNS can fail if another daemon owns the required port on the USB device.
  Startup reports dnsmasq errors and rolls back.
- Automatic USB-interface selection requires exactly one eligible USB network
  interface other than the internet uplink. Set `USB_IFACE` when there are
  multiple USB NICs (including docks or USB ethernet adapters).

## Tests

Run the non-root checks:

```sh
./tests/smoke.sh
```

These run `bash -n`, `shellcheck` (if installed), CLI argument handling, and
unit checks of the pure helper functions (IPv4 parsing, subnet-overlap math,
interface-name validation, the address-match regex). They do not alter network
settings and do not test tethering. CI runs the same script on every push.

### Hardware test checklist

Use a device known to work as a USB network client first (for example a
Raspberry Pi Zero running `g_ether` or `g_ncm`), on a machine where a change to
forwarding or firewall behavior will not disrupt other users or services.

1. `usb-internet-share check` passes and names the right interfaces.
2. `sudo usb-internet-share start`, then `usb-internet-share status` reports
   `active`.
3. Confirm the lock is released: `sudo usb-internet-share status` is fine, and
   `ls -l /proc/$(cat /run/usb-internet-share/dnsmasq.pid)/fd` shows no fd
   pointing at `/run/lock/usb-internet-share.lock`.
4. The device receives an address in `10.203.0.0/24`
   (`cat /run/usb-internet-share/dnsmasq.leases`).
5. The device can resolve DNS and reach the internet.
6. `sudo nft list table ip usb_internet_share` shows the expected rules.
7. Unplug the device: sharing stops automatically within about 30 seconds
   (`/run/usb-internet-share/monitor.log`, then `status`).
8. Start again, then `sudo usb-internet-share stop`. Verify the nft table,
   the `10.203.0.1/24` address, the interface up/down state, NetworkManager's
   managed state, and `sysctl net.ipv4.ip_forward` are all restored.
9. Failure paths: a pre-existing `usb_internet_share` nft table; an overlapping
   subnet; killing dnsmasq mid-session; running `stop` twice; running `start`
   twice; confirming dnsmasq can write its lease/log files after dropping
   privileges.
