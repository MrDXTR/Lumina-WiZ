# Lumina WiZ

Lumina is a native macOS menu bar app for controlling WiZ smart bulbs over your local network. It provides a menu bar power control, brightness slider, color wheel, white temperature controls, scene presets, and a live 3D bulb preview.

## Requirements

- macOS 13 or later
- Apple Command Line Tools with the macOS SDK and Swift compiler (full Xcode is not required)
- A WiZ bulb on the same local network as your Mac

## Build

From the project directory, run:

```sh
./build.sh
```

This creates `Lumina.app` in the project directory and ad hoc signs it for local use. Open it with:

```sh
open Lumina.app
```

## Connect to a bulb

1. Make sure the Mac and bulb are on the same LAN. Guest Wi-Fi or client isolation can block local traffic.
2. Find the bulb's IP address in your router or the WiZ app.
3. Open Lumina's settings from the menu bar popover and enter the IP address.
4. In the WiZ app, allow local control. This version sends unsigned local UDP commands and does not support WiZ's verified-controls security mode.

Lumina communicates using WiZ's local UDP interface on port `38899`. The bulb must permit local control for commands to work. If the bulb is configured for verified controls, Lumina will report that commands were rejected.

## Project layout

- `Sources/` — Swift app and UI source
- `Info.plist` — macOS app bundle metadata
- `Package.swift` — Swift package definition
- `build.sh` — standalone app bundle build script

## Notes

The app is an independent community project and is not affiliated with or endorsed by Signify/Philips WiZ. Local network behavior and available bulb features may vary by model, firmware, and security settings.
