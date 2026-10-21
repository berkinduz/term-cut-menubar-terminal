#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${CONFIGURATION:-release}"
architectures=("$(uname -m)")
case "${1:-}" in
  --universal) architectures=(arm64 x86_64) ;;
  "") ;;
  *) echo "Usage: scripts/build-app.sh [--universal]" >&2; exit 2 ;;
esac

binary_paths=()
resource_directory=""
for architecture in "${architectures[@]}"; do
  swift build --configuration "$configuration" --product TermCut --arch "$architecture"
  binary_directory="$(swift build --configuration "$configuration" --show-bin-path --arch "$architecture")"
  binary_paths+=("$binary_directory/TermCut")
  if [ -z "$resource_directory" ]; then resource_directory="$binary_directory"; fi
done
app_directory="$PWD/build/term-cut.app"
mkdir -p build
rm -rf "$app_directory"
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources"
if [ "${#binary_paths[@]}" -gt 1 ]; then
  lipo -create "${binary_paths[@]}" -output "$app_directory/Contents/MacOS/TermCut"
  chmod 755 "$app_directory/Contents/MacOS/TermCut"
else
  install -m 755 "${binary_paths[0]}" "$app_directory/Contents/MacOS/TermCut"
fi
cp Resources/Info.plist "$app_directory/Contents/Info.plist"
ditto Sources/TermCut/Resources/ShellIntegration "$app_directory/Contents/Resources/ShellIntegration"
for bundle in "$resource_directory/"*.bundle; do
  if [ -d "$bundle" ]; then ditto "$bundle" "$app_directory/Contents/Resources/$(basename "$bundle")"; fi
done
swift scripts/create-icon.swift "$PWD/build/AppIcon.iconset"
iconutil --convert icns build/AppIcon.iconset --output "$app_directory/Contents/Resources/AppIcon.icns"
cp LICENSE THIRD_PARTY_NOTICES.md "$app_directory/Contents/Resources/"
codesign --force --deep --sign - --timestamp=none "$app_directory"
printf '\nBuilt %s\n' "$app_directory"
