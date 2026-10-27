#!/bin/bash
# Builds Lumina, assembles the .app bundle, signs it and optionally runs tests or installs.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

STAGE_TMP=""
cleanup() {
    [[ -n "$STAGE_TMP" && -d "$STAGE_TMP" ]] && rm -rf "$STAGE_TMP"
    return 0
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP

DEV=0
INSTALL=0
RUN_TESTS=0
SELFTEST=0

for arg in "$@"; do
    case "$arg" in
        --dev)      DEV=1 ;;
        --install)  INSTALL=1 ;;
        --test)     RUN_TESTS=1 ;;
        --selftest) SELFTEST=1 ;;
        --help|-h)
            echo "Usage: ./build.sh [OPTIONS]"
            echo "Options:"
            echo "  --dev       Build 'Lumina (Developer)' variant (com.dxtr.lumina.dev)"
            echo "  --install   Install application to /Applications"
            echo "  --test      Compile and run standalone unit tests"
            echo "  --selftest  Run headless self-test verification"
            exit 0
            ;;
    esac
done

if (( DEV )); then
    APP_NAME="Lumina (Developer)"
    BUNDLE_ID="com.dxtr.lumina.dev"
    BUILD_OPT="-Onone"
    echo "==> Building Developer Variant: $APP_NAME ($BUNDLE_ID)..."
else
    APP_NAME="Lumina"
    BUNDLE_ID="com.dxtr.lumina"
    BUILD_OPT="-O"
    echo "==> Building Production Release: $APP_NAME ($BUNDLE_ID)..."
fi

# Run Standalone Unit Tests if requested
if (( RUN_TESTS )); then
    echo "==> Compiling and running unit tests..."
    mkdir -p "$DIR/build"
    NON_MAIN_SOURCES=$(find "$DIR/Sources" -name "*.swift" ! -name "main.swift")
    TEST_SOURCES=$(find "$DIR/Tests" -name "*.swift")

    swiftc -Onone \
        -target arm64-apple-macosx13.0 \
        -sdk "$(xcrun --show-sdk-path)" \
        -framework SwiftUI \
        -framework AppKit \
        -framework SceneKit \
        -framework Combine \
        $NON_MAIN_SOURCES $TEST_SOURCES \
        -o "$DIR/build/lumina-tests"

    "$DIR/build/lumina-tests"
    echo "==> Unit tests finished successfully."
    if (( ! INSTALL && ! SELFTEST && ! DEV )); then
        exit 0
    fi
fi

# Stage build in a clean temporary directory to prevent xattr provenance issues
STAGE_TMP=$(mktemp -d /tmp/lumina-build-XXXXXX)
APP_DIR="$STAGE_TMP/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy Resources if available (App icons, assets)
if [[ -d "$DIR/Resources" ]]; then
    cp -R "$DIR/Resources/"* "$RESOURCES_DIR/" 2>/dev/null || true
fi

# Generate Info.plist with appropriate Bundle ID and Display Name
cat << EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Lumina</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Compile Swift sources
SWIFT_FILES=$(find "$DIR/Sources" -name "*.swift")

echo "==> Compiling Swift sources..."
swiftc $BUILD_OPT \
    -target arm64-apple-macosx13.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework SwiftUI \
    -framework AppKit \
    -framework SceneKit \
    -framework Combine \
    $SWIFT_FILES \
    -o "$MACOS_DIR/Lumina"

# Sign application bundle ad-hoc
echo "==> Signing application bundle..."
codesign --force --deep --sign - "$APP_DIR"

# Move from stage to destination
DEST_APP="$DIR/$APP_NAME.app"
rm -rf "$DEST_APP"
cp -R "$APP_DIR" "$DEST_APP"

echo "==> Successfully created $DEST_APP"

# Execute headless selftest if requested
if (( SELFTEST )); then
    echo "==> Executing --selftest verification..."
    "$DEST_APP/Contents/MacOS/Lumina" --selftest
fi

# Install to /Applications if requested
if (( INSTALL )); then
    TARGET_APP="/Applications/$APP_NAME.app"
    echo "==> Installing to $TARGET_APP..."
    rm -rf "$TARGET_APP"
    cp -R "$DEST_APP" "$TARGET_APP"
    echo "==> Successfully installed to $TARGET_APP"
fi
