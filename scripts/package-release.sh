#!/bin/zsh
# Builds the app and zips it for a GitHub release:
#   build/IG-Follow-Audit-<version>.zip
set -euo pipefail

cd "${0:A:h}/.."
./scripts/build-app.sh

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
ZIP="build/IG-Follow-Audit-$VERSION.zip"

rm -f "$ZIP"
# ditto keeps the bundle's signature and metadata intact, unlike plain zip.
ditto -c -k --keepParent "build/IG Follow Audit.app" "$ZIP"

echo "Packaged $ZIP"
shasum -a 256 "$ZIP"
