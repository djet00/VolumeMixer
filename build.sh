#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP="build/Микшер громкости.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp ".build/release/VolumeMixerApp" "$APP/Contents/MacOS/VolumeMixer"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Sparkle.framework из SPM-артефакта (rpath на Frameworks задан в Package.swift)
SPARKLE_FW=$(ls -d .build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-*/Sparkle.framework | head -1)
cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/"

codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - --identifier ru.mikhail.VolumeMixer "$APP"
echo "Готово: $APP"
