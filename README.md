# USB Internet Share

A lightweight Linux utility and Omarchy bar plugin for sharing a laptop's internet connection with an Android phone over USB using [GNirehtet](https://github.com/Genymobile/gnirehtet).

Unlike normal Android USB tethering, which shares the phone's internet with the computer, this project shares the computer's internet with the phone.

## Features

- Start, stop, and check USB internet sharing.
- Run GNirehtet through a user-level systemd service.
- Control sharing from the terminal.
- Integrate with the Omarchy bar through a plugin widget.
- No root privileges required for normal start/stop controls after setup.

## Requirements

- Linux with Bash and a working user-level systemd manager.
- An Android phone with USB debugging enabled.
- A USB data cable.
- ADB installed, with the phone authorized.
- GNirehtet available as the `gnirehtet` command.

On Arch Linux, GNirehtet is available from the AUR as `gnirehtet-bin`.

## Installation

Clone or download this repository, then run the installer as your normal user, without `sudo`:

```bash
./install.sh
```

OmaNet is currently distributed as a source checkout; there is no separate release archive. Keep the repository layout intact (in particular `scripts/install-dependencies.sh`), because `install.sh` invokes that script relative to its own location. The installer can be run from any working directory.

The installer places the CLI commands in `~/.local/bin`, installs the user-level systemd service, and creates a desktop launcher.

Make sure `~/.local/bin` is included in your `PATH`.

### Dependencies

Before installing, the installer runs `scripts/install-dependencies.sh`, which checks for GNirehtet and ADB. If either is missing it detects your package manager (pacman, apt-get, dnf, zypper, apk, or brew) and **asks for confirmation before installing anything**. Nothing is ever installed silently.

- ADB is installed from your distribution's packages (`android-tools` or `adb`).
- GNirehtet is only available automatically on Arch Linux, through the AUR package `gnirehtet-bin` (using `yay` or `paru` if present). Elsewhere, install it manually.

If you decline, no supported package manager is found, or an install fails, the installer stops and prints the exact remaining steps. You can also run the check on its own:

```bash
./scripts/install-dependencies.sh
```

Pass `--yes` to skip the prompt when running unattended.

### Omarchy bar plugin

The Omarchy bar widget is provided by `manifest.json`, `Service.qml`, and `BarWidget.qml`.

Install the utility and service first using the installer above. Then install the plugin through Omarchy's plugin manager once this repository is published and its Git URL is available.

The widget relies on the installed `usb-internet-share.service`; installing the widget alone is not sufficient.

## Android setup

1. Enable Developer options on your Android phone.
2. Enable USB debugging.
3. Connect the phone to your laptop with a USB data cable.
4. Approve the USB debugging authorization prompt.
5. Start sharing using the CLI or Omarchy bar widget.
6. Approve Android's VPN prompt if requested.

Keep USB debugging enabled while using GNirehtet.

## Usage

Start sharing:

```bash
usb-internet-share start
```

Stop sharing:

```bash
usb-internet-share stop
```

Check service status:

```bash
usb-internet-share status
```

Open the terminal menu:

```bash
usb-internet-share-menu
```

## Uninstallation

Run the following from the project directory:

```bash
./uninstall.sh
```

This removes the installed utility, desktop launcher, and user-level service. It stops sharing as part of the removal process. GNirehtet itself is not uninstalled.

If you installed the Omarchy plugin separately, remove or disable it through Omarchy's plugin manager as well.

## Limitations

- Android USB debugging and ADB authorization are required.
- Android may display a persistent VPN notification while sharing.
- The project depends on GNirehtet and a working user-level systemd manager.
- The Omarchy widget requires the utility and service to be installed separately.

