#!/bin/bash
# Packages Lumina.app into a compressed, distributable DMG installer with an /Applications symlink.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

APP_NAME="Lumina"
APP="$DIR/$APP_NAME.app"
DIST_DIR="$DIR/dist"
STAGING=""

cleanup() {
    [[ -n "$STAGING" && -d "$STAGING" ]] && rm -rf "$STAGING"
    return 0
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP

echo "==> Building fresh production application bundle..."
./build.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist" 2>/dev/null || echo "1.0")
DMG_PATH="$DIST_DIR/Lumina-$VERSION.dmg"

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

echo "==> Staging DMG distribution contents for version $VERSION..."
STAGING=$(mktemp -d /tmp/lumina-dmg-XXXXXX)

# Copy app cleanly without quarantine or provenance xattrs
ditto "$APP" "$STAGING/$APP_NAME.app"
xattr -cr "$STAGING/$APP_NAME.app"

# Create drag-and-drop /Applications shortcut
ln -s /Applications "$STAGING/Applications"

echo "==> Building compressed disk image: $DMG_PATH..."
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "==> Successfully created $DMG_PATH"
ls -lh "$DMG_PATH"
