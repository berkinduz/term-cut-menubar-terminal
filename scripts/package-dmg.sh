#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -d build/term-cut.app ]; then
  echo "Run scripts/build-app.sh first." >&2
  exit 1
fi
staging_directory="$PWD/build/dmg-content"
mkdir -p "$staging_directory"
ditto build/term-cut.app "$staging_directory/term-cut.app"
ln -sfn /Applications "$staging_directory/Applications"
hdiutil create -volname "term-cut" -srcfolder "$staging_directory" -ov -format UDZO build/term-cut.dmg
ditto -c -k --sequesterRsrc --keepParent build/term-cut.app build/term-cut.zip
