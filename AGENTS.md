# Agent instructions

## Project overview

Lumina WiZ is a native Swift macOS menu bar app that controls WiZ bulbs over local UDP. The app uses AppKit, SwiftUI, SceneKit, and Combine and targets macOS 13 or later.

## Working guidelines

- Keep the app native and dependency-free unless the user asks otherwise.
- Preserve local-only control; do not introduce cloud access or credentials.
- WiZ commands use UDP port `38899`. This app currently supports unsigned local control only; do not claim verified-controls support unless it is implemented and validated.
- Keep generated build products (`.build/` and `Lumina.app/`) out of commits.
- Build with `./build.sh` when asked to verify a source change. Full Xcode is not required when the Apple Command Line Tools and macOS SDK are installed.
