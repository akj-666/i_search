#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
APP_NAME="i search"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "=========================================="
echo "  Building $APP_NAME for macOS"
echo "=========================================="

cd "$PROJECT_ROOT"

# 1. Compile with Swift Package Manager (Release)
echo "==> Compiling Release binary..."
swift build -c release

# Find the compiled binary
BIN_PATH="$PROJECT_ROOT/.build/release/i search"
if [ ! -f "$BIN_PATH" ]; then
    # Fallback search
    BIN_PATH=$(find "$PROJECT_ROOT/.build" -name "i search" -type f -perm +111 | grep -v "\.build" | head -n 1)
fi

if [ ! -f "$BIN_PATH" ]; then
    echo "Error: Compiled binary not found at $BIN_PATH"
    exit 1
fi

echo "==> Binary compiled successfully at: $BIN_PATH"

# 2. Assemble .app bundle
echo "==> Creating macOS Application Bundle..."
# Terminate any running instance before replacing bundle
pkill -f "build/i search.app/Contents/MacOS/i search" 2>/dev/null || true
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# 3. Ad-hoc codesign with entitlements and stable designated requirement
echo "==> Code-signing application bundle..."
codesign --force --deep --sign - \
    --entitlements "$PROJECT_ROOT/Resources/i_search.entitlements" \
    -r="designated => identifier \"com.isearch.app\"" \
    "$APP_BUNDLE"

# 4. Verify bundle
echo "==> Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "=========================================="
echo "  Build Complete! 🎉"
echo "  Application bundle: $APP_BUNDLE"
echo "=========================================="
