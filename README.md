# Lumina WiZ

A small, native macOS menu bar controller for WiZ smart bulbs. Lumina talks directly to the bulb over your local network, with no account, cloud service, or third-party package dependencies.

## Screenshots

| Color controls | Scenes and color flows |
| --- | --- |
| ![Lumina color controls](public/SS1.png) | ![Lumina scenes and color flows](public/SS2.png) |

## Features

- Turn the bulb on or off from the menu bar popover. Right-click or Option-click the menu bar icon to toggle power quickly.
- Adjust brightness, choose a color from the wheel, enter a custom hex color, or set white color temperature.
- Use the bulb preview to see color and brightness changes. Its label can be customized in **Settings**.
- Choose built-in WiZ scenes or start a cycling color flow, including Diwali, Aurora, Sunset, and Ocean palettes.
- Set the bulb's IP address in Settings or use **Rescan IP** to look for it on your local network.
- Scheduled alarms and wake-up routines with firmware pulse effects or custom color strobe loops.
- Rock-solid `.applicationDefined` popover behavior with outside-click and Escape key monitors.
- Cached menu bar rendering to minimize CPU overhead.

## Requirements

- macOS 13 or later
- Apple Command Line Tools with the macOS SDK and Swift compiler
- A WiZ bulb reachable from the Mac on the local network

Full Xcode is not required to build the app when the Command Line Tools and macOS SDK are installed.

## Build and Run

```sh
# Build production app bundle
./build.sh

# Run unit tests
./build.sh --test

# Run headless verification
./build.sh --selftest

# Build isolated developer variant side-by-side with production
./build.sh --dev

# Install to /Applications
./build.sh --install

# Package a compressed distributable DMG
./Tools/make-dmg.sh
```

## Connect to a Bulb

1. Connect the Mac and bulb to the same local network. Guest Wi-Fi and client isolation can block communication between devices.
2. Open Lumina from the menu bar and choose the gear icon.
3. Enter the bulb's IP address, then save.
4. In the WiZ app, enable **Allow all controls** under **Settings → Security**.

Lumina sends unsigned local UDP commands to port `38899`. Bulbs configured to require verified controls are not supported by this version. If a command is rejected, check the WiZ security setting and the IP address shown in Lumina.

## Project Architecture

- `Sources/`
  - `App/` — [`AppDelegate.swift`](Sources/App/AppDelegate.swift), [`StatusItemController.swift`](Sources/App/StatusItemController.swift)
  - `Core/` — [`Defaults.swift`](Sources/Core/Defaults.swift), [`WizModels.swift`](Sources/Core/WizModels.swift)
  - `Services/` — [`WizService.swift`](Sources/Services/WizService.swift), [`ScheduleManager.swift`](Sources/Services/ScheduleManager.swift)
  - `Support/` — [`SelfTest.swift`](Sources/Support/SelfTest.swift)
  - `UI/` — [`MainView.swift`](Sources/UI/MainView.swift), [`Sections/`](Sources/UI/Sections), [`Components/`](Sources/UI/Components)
- `Tests/` — Standalone test runner and test cases for UDP commands, color conversions, and schedules
- `Tools/` — [`make-dmg.sh`](Tools/make-dmg.sh) packaging script

## Privacy and Affiliation

Lumina controls bulbs on your local network and does not send bulb data to a cloud service. This is an independent community project and is not affiliated with or endorsed by Signify, Philips, or WiZ. Bulb features and local control behavior may vary by model, firmware, and security settings.
