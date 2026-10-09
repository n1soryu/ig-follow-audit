#!/bin/zsh
# Builds a universal (Apple Silicon + Intel) release copy of the app into
# build/IG Follow Audit.app.
# Works with just the Xcode Command Line Tools; full Xcode isn't required.
set -euo pipefail

cd "${0:A:h}/.."
APP="build/IG Follow Audit.app"

ARCHS=(--arch arm64 --arch x86_64)
swift build -c release --product IGFollowAudit "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/IGFollowAudit"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/IGFollowAudit"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: enough to apply the sandbox entitlements on this Mac.
codesign --force --sign - --entitlements Resources/IGFollowAudit.entitlements "$APP"

echo "Built $APP"
