#!/bin/zsh
# Собирает красивый DMG для раздачи: кастомный фон с инструкцией,
# иконка приложения слева, ярлык «Программы» справа.
# Требует create-dmg: brew install create-dmg
# Фон перегенерируется скриптом scripts/render-dmg-background.swift.
set -euo pipefail
cd "$(dirname "$0")"

command -v create-dmg >/dev/null || { echo "Нужен create-dmg: brew install create-dmg"; exit 1 }

./build.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
STAGE="build/dmg-stage"
DMG="build/Микшер громкости $VERSION.dmg"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "build/Микшер громкости.app" "$STAGE/"

create-dmg \
    --volname "Микшер громкости" \
    --volicon "Resources/AppIcon.icns" \
    --background "Resources/dmg-background.tiff" \
    --window-pos 200 120 \
    --window-size 640 440 \
    --icon-size 128 \
    --text-size 12 \
    --icon "Микшер громкости.app" 160 275 \
    --hide-extension "Микшер громкости.app" \
    --app-drop-link 480 275 \
    --no-internet-enable \
    "$DMG" "$STAGE"

rm -rf "$STAGE"
echo "Готово: $DMG"
