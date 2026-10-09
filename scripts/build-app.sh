#!/bin/zsh
# Builds a release copy of the app into build/IG Follow Audit.app.
# Works with just the Xcode Command Line Tools; full Xcode isn't required.
set -euo pipefail

cd "${0:A:h}/.."
APP="build/IG Follow Audit.app"

swift build -c release --product IGFollowAudit
BIN="$(swift build -c release --show-bin-path)/IGFollowAudit"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/IGFollowAudit"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: enough to apply the sandbox entitlements on this Mac.
codesign --force --sign - --entitlements Resources/IGFollowAudit.entitlements "$APP"

echo "Built $APP"
