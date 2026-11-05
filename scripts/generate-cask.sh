#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: scripts/generate-cask.sh <dmg> [output.rb]" >&2
  exit 2
fi
dmg="$1"
output="${2:-build/peeksh.rb}"
if [ ! -f "$dmg" ]; then echo "DMG not found: $dmg" >&2; exit 1; fi
mount_directory="$(mktemp -d "${TMPDIR:-/tmp}/peeksh-cask.XXXXXX")"
attached=false
cleanup() {
  if [ "$attached" = true ]; then hdiutil detach "$mount_directory" >/dev/null; fi
  rmdir "$mount_directory"
}
trap cleanup EXIT
hdiutil attach -readonly -nobrowse -mountpoint "$mount_directory" "$dmg" >/dev/null
attached=true
app="$mount_directory/Peeksh.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-\.][0-9A-Za-z.-]+)?$ ]]; then
  echo "Unsupported application version: $version" >&2
  exit 1
fi
if [ ! -x "$app/Contents/Resources/bin/peeksh" ]; then
  echo "The DMG does not contain the bundled peeksh launcher; package Peeksh.app before generating its cask." >&2
  exit 1
fi
digest=$(shasum -a 256 < "$dmg")
digest="${digest%% *}"
mkdir -p "$(dirname "$output")"
cat > "$output" <<CASK
cask "peeksh" do
  version "$version"
  sha256 "$digest"

  url "https://github.com/berkinduz/peeksh/releases/download/v#{version}/Peeksh.dmg"
  name "Peeksh"
  desc "Terminal in your menu bar"
  homepage "https://github.com/berkinduz/peeksh"

  depends_on macos: ">= :ventura"

  app "Peeksh.app"
  binary "#{appdir}/Peeksh.app/Contents/Resources/bin/peeksh"
end
CASK
printf 'Generated %s for version %s\n' "$output" "$version"
