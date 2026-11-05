#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${CONFIGURATION:-release}"
swift_build() {
  if [ -n "${SWIFT_BUILD_SYSTEM:-}" ]; then
    swift build --build-system "$SWIFT_BUILD_SYSTEM" "$@"
  else
    swift build "$@"
  fi
}
architectures=("$(uname -m)")
case "${1:-}" in
  --universal) architectures=(arm64 x86_64) ;;
  "") ;;
  *) echo "Usage: scripts/build-app.sh [--universal]" >&2; exit 2 ;;
esac

binary_paths=()
resource_directory=""
for architecture in "${architectures[@]}"; do
  swift_build --configuration "$configuration" --product Peeksh --arch "$architecture"
  binary_directory="$(swift_build --configuration "$configuration" --show-bin-path --arch "$architecture")"
  binary_paths+=("$binary_directory/Peeksh")
  if [ -z "$resource_directory" ]; then resource_directory="$binary_directory"; fi
done
app_directory="$PWD/build/Peeksh.app"
mkdir -p build
rm -rf "$app_directory"
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources/bin"
if [ "${#binary_paths[@]}" -gt 1 ]; then
  lipo -create "${binary_paths[@]}" -output "$app_directory/Contents/MacOS/Peeksh"
  chmod 755 "$app_directory/Contents/MacOS/Peeksh"
else
  install -m 755 "${binary_paths[0]}" "$app_directory/Contents/MacOS/Peeksh"
fi
cp Resources/Info.plist "$app_directory/Contents/Info.plist"
install -m 755 scripts/peeksh "$app_directory/Contents/Resources/bin/peeksh"
ditto Sources/Peeksh/Resources/ShellIntegration "$app_directory/Contents/Resources/ShellIntegration"
for bundle in "$resource_directory/Peeksh_Peeksh.bundle" "$resource_directory/SwiftTerm_SwiftTerm.bundle"; do
  ditto "$bundle" "$app_directory/Contents/Resources/$(basename "$bundle")"
done
swiftc Sources/Peeksh/BrandMark.swift scripts/create-icon.swift -o build/create-icon
build/create-icon "$PWD/build/AppIcon.iconset"
iconutil --convert icns build/AppIcon.iconset --output "$app_directory/Contents/Resources/AppIcon.icns"
cp LICENSE THIRD_PARTY_NOTICES.md "$app_directory/Contents/Resources/"
codesign --force --deep --sign - --timestamp=none "$app_directory"
codesign --verify --deep --strict "$app_directory"
printf '\nBuilt %s\n' "$app_directory"
