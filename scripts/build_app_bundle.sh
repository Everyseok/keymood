#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="KeyMood"
PRODUCT_NAME="keymood-menubar"
BUNDLE_ID="${KEYMOOD_BUNDLE_ID:-com.keymood.app}"
VERSION="${KEYMOOD_VERSION:-0.1.0}"
BUILD_CONFIG="${KEYMOOD_BUILD_CONFIG:-release}"
SIGN_IDENTITY="${KEYMOOD_SIGN_IDENTITY:--}"
NOTARIZE="${KEYMOOD_NOTARIZE:-0}"
NOTARY_PROFILE="${KEYMOOD_NOTARY_PROFILE:-}"
OUTPUT_DIR="$ROOT_DIR/output"
FINAL_APP_DIR="$OUTPUT_DIR/$APP_NAME.app"
FINAL_ZIP_PATH="$OUTPUT_DIR/$APP_NAME.zip"
STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/keymood_bundle.XXXXXX")"
APP_DIR="$STAGING_ROOT/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE_PATH="$MACOS_DIR/$APP_NAME"
ZIP_PATH="$STAGING_ROOT/$APP_NAME.zip"

trap 'rm -rf "$STAGING_ROOT"' EXIT

cd "$ROOT_DIR"

swift build -c "$BUILD_CONFIG" --product "$PRODUCT_NAME"
BIN_DIR="$(swift build -c "$BUILD_CONFIG" --show-bin-path)"

rm -rf "$FINAL_APP_DIR" "$FINAL_ZIP_PATH"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_DIR/$PRODUCT_NAME" "$EXECUTABLE_PATH"
chmod +x "$EXECUTABLE_PATH"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$APP_DIR"
fi

if command -v codesign >/dev/null 2>&1; then
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP_DIR" >/dev/null
  else
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null
  fi

  if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$APP_DIR"
  fi

  codesign --verify --deep --strict "$APP_DIR"
fi

ditto -c -k --norsrc --keepParent "$APP_DIR" "$ZIP_PATH"

if [[ "$NOTARIZE" == "1" ]]; then
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "KEYMOOD_SIGN_IDENTITY must be a Developer ID Application identity when KEYMOOD_NOTARIZE=1." >&2
    exit 1
  fi
  if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "KEYMOOD_NOTARY_PROFILE is required when KEYMOOD_NOTARIZE=1." >&2
    exit 1
  fi
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "xcrun is required for notarization." >&2
    exit 1
  fi

  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_DIR"
  if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$APP_DIR"
  fi
  rm -f "$ZIP_PATH"
  ditto -c -k --norsrc --keepParent "$APP_DIR" "$ZIP_PATH"
fi

ditto --norsrc "$APP_DIR" "$FINAL_APP_DIR"
cp "$ZIP_PATH" "$FINAL_ZIP_PATH"

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$FINAL_APP_DIR"
fi

echo "Built app: $FINAL_APP_DIR"
echo "Built archive: $FINAL_ZIP_PATH"
