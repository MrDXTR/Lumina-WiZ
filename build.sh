#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "==> Building Lumina Menu Bar App..."

APP_NAME="Lumina"
APP_DIR="$DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy Info.plist
cp "$DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

# Compile Swift sources
SWIFT_FILES=$(find "$DIR/Sources" -name "*.swift")

echo "Compiling Swift source files..."
swiftc -O \
    -target arm64-apple-macosx13.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework SwiftUI \
    -framework AppKit \
    -framework SceneKit \
    -framework Combine \
    $SWIFT_FILES \
    -o "$MACOS_DIR/$APP_NAME"

# Ad-hoc code sign so macOS gatekeeper allows running smoothly
echo "Signing application bundle..."
codesign --force --deep --sign - "$APP_DIR"

echo "==> Successfully built $APP_DIR"
