#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="KeyMood"
APP_DIR="${1:-$ROOT_DIR/output/$APP_NAME.app}"
ZIP_PATH="${APP_DIR%/*}/$APP_NAME.zip"
INFO_PLIST="$APP_DIR/Contents/Info.plist"
EXECUTABLE="$APP_DIR/Contents/MacOS/$APP_NAME"

if [[ ! -d "$APP_DIR" ]]; then
  echo "Missing app bundle: $APP_DIR" >&2
  exit 1
fi

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Missing executable: $EXECUTABLE" >&2
  exit 1
fi

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Missing Info.plist: $INFO_PLIST" >&2
  exit 1
fi

PLIST_BUDDY="/usr/libexec/PlistBuddy"
"$PLIST_BUDDY" -c "Print :CFBundleExecutable" "$INFO_PLIST" | grep -qx "$APP_NAME"
"$PLIST_BUDDY" -c "Print :CFBundlePackageType" "$INFO_PLIST" | grep -qx "APPL"
"$PLIST_BUDDY" -c "Print :LSUIElement" "$INFO_PLIST" | grep -qx "true"
"$PLIST_BUDDY" -c "Print :LSMinimumSystemVersion" "$INFO_PLIST" | grep -qx "14.0"

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$APP_DIR"
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --verify --deep --strict "$APP_DIR"
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Missing release archive: $ZIP_PATH" >&2
  exit 1
fi

if command -v unzip >/dev/null 2>&1 && unzip -Z1 "$ZIP_PATH" | grep -q "^__MACOSX/"; then
  echo "Release archive contains __MACOSX resource metadata." >&2
  exit 1
fi

echo "Bundle smoke test passed: $APP_DIR"
