#!/usr/bin/env bash
set -euo pipefail

NOTARY_PROFILE="${KEYMOOD_NOTARY_PROFILE:-keymood-notary}"

echo "KeyMood distribution readiness"
echo

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "FAIL: Xcode command line tools are not available."
  exit 1
fi
echo "OK: $(xcodebuild -version | tr '\n' ' ')"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "FAIL: xcrun is not available."
  exit 1
fi

if ! xcrun notarytool --help >/dev/null 2>&1; then
  echo "FAIL: notarytool is not available through xcrun."
  exit 1
fi
echo "OK: notarytool is available"

IDENTITIES="$(security find-identity -p codesigning -v 2>/dev/null || true)"
DEVELOPER_ID_IDENTITY="$(printf "%s\n" "$IDENTITIES" | grep "Developer ID Application" | head -n 1 || true)"
if [[ -z "$DEVELOPER_ID_IDENTITY" ]]; then
  echo "FAIL: No Developer ID Application certificate is installed in this keychain."
  echo "      Install one through Xcode or Apple Developer Certificates, then rerun this script."
  exit 1
fi

echo "OK: $DEVELOPER_ID_IDENTITY"
echo
echo "Next notarization check, if you have stored credentials:"
echo "  xcrun notarytool history --keychain-profile \"$NOTARY_PROFILE\""
echo
echo "Build a signed and notarized archive with:"
echo "  KEYMOOD_SIGN_IDENTITY=\"$(printf "%s" "$DEVELOPER_ID_IDENTITY" | sed -E 's/^.*\"(Developer ID Application:[^\"]+)\".*$/\1/')\" \\"
echo "  KEYMOOD_NOTARIZE=1 \\"
echo "  KEYMOOD_NOTARY_PROFILE=\"$NOTARY_PROFILE\" \\"
echo "  ./scripts/build_app_bundle.sh"
