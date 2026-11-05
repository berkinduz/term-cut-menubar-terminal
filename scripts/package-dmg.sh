#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -d build/Peeksh.app ]; then
  echo "Run scripts/build-app.sh first." >&2
  exit 1
fi
codesign --verify --deep --strict build/Peeksh.app
staging_directory="$(mktemp -d "$PWD/build/dmg-content.XXXXXX")"
trap 'rm -rf "$staging_directory"' EXIT
ditto build/Peeksh.app "$staging_directory/Peeksh.app"
ln -sfn /Applications "$staging_directory/Applications"
cp Resources/DMG/FinderLayout.dsstore "$staging_directory/.DS_Store"
hdiutil create -volname "Peeksh" -srcfolder "$staging_directory" -ov -format UDZO build/Peeksh.dmg
