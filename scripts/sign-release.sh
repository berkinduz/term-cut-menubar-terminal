#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
  sign)
    if [ "$#" -gt 2 ]; then echo "Usage: scripts/sign-release.sh sign [app]" >&2; exit 2; fi
    : "${PEEKSH_SIGNING_IDENTITY:?Set PEEKSH_SIGNING_IDENTITY to your Developer ID Application identity}"
    app="${2:-build/Peeksh.app}"
    if [ ! -d "$app" ]; then echo "Application not found: $app" >&2; exit 1; fi
    codesign --force --options runtime --timestamp --sign "$PEEKSH_SIGNING_IDENTITY" "$app"
    codesign --verify --deep --strict --verbose=2 "$app"
    ;;
  notarize)
    if [ "$#" -gt 2 ]; then echo "Usage: scripts/sign-release.sh notarize [dmg]" >&2; exit 2; fi
    : "${PEEKSH_NOTARY_PROFILE:?Set PEEKSH_NOTARY_PROFILE to an existing notarytool keychain profile}"
    dmg="${2:-build/Peeksh.dmg}"
    if [ ! -f "$dmg" ]; then echo "DMG not found: $dmg" >&2; exit 1; fi
    xcrun notarytool submit "$dmg" --keychain-profile "$PEEKSH_NOTARY_PROFILE" --wait
    xcrun stapler staple "$dmg"
    xcrun stapler validate "$dmg"
    ;;
  *) echo "Usage: scripts/sign-release.sh {sign [app]|notarize [dmg]}" >&2; exit 2 ;;
esac
