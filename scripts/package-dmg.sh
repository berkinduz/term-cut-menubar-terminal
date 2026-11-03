#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -d build/term-cut.app ]; then
  echo "Run scripts/build-app.sh first." >&2
  exit 1
fi
staging_directory="$(mktemp -d "$PWD/build/dmg-content.XXXXXX")"
trap 'rm -rf "$staging_directory"' EXIT
ditto build/term-cut.app "$staging_directory/term-cut.app"
ln -sfn /Applications "$staging_directory/Applications"
cp Resources/DMG/FinderLayout.dsstore "$staging_directory/.DS_Store"
hdiutil create -volname "term-cut" -srcfolder "$staging_directory" -ov -format UDZO build/term-cut.dmg
