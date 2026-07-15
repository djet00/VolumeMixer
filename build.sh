#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP="build/Микшер громкости.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/VolumeMixerApp" "$APP/Contents/MacOS/VolumeMixer"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - --identifier ru.mikhail.VolumeMixer "$APP"
echo "Готово: $APP"
