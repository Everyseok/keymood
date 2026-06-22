#!/usr/bin/env bash
set -euo pipefail

PROFILE="${KEYMOOD_NOTARY_PROFILE:-keymood-notary}"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is required." >&2
  exit 1
fi

cat <<EOF
This stores Apple notarization credentials in your local Keychain.

You need:
- Apple ID email for your Apple Developer Program account
- Team ID
- App-specific password, or App Store Connect API key credentials

Profile name: $PROFILE

EOF

xcrun notarytool store-credentials "$PROFILE"

echo
echo "Stored notary profile: $PROFILE"
echo "You can test it with:"
echo "  xcrun notarytool history --keychain-profile \"$PROFILE\""
