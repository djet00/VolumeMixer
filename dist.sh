#!/bin/zsh
# Собирает красивый DMG для раздачи: кастомный фон с инструкцией,
# иконка приложения слева, ярлык «Программы» справа.
# Требует create-dmg: brew install create-dmg
# Фон перегенерируется скриптом scripts/render-dmg-background.swift.
set -euo pipefail
cd "$(dirname "$0")"

command -v create-dmg >/dev/null || { echo "Нужен create-dmg: brew install create-dmg"; exit 1 }

./build.sh

# Перегенерировать фон (1x + 2x → многостраничный tiff, чтобы ретина была чёткой)
(cd scripts && swift render-dmg-background.swift 1 && swift render-dmg-background.swift 2)
tiffutil -cathidpicheck scripts/dmg-bg.png scripts/dmg-bg@2x.png -out Resources/dmg-background.tiff
rm -f scripts/dmg-bg.png scripts/dmg-bg@2x.png

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
    --window-size 700 440 \
    --icon-size 96 \
    --text-size 12 \
    --icon "Микшер громкости.app" 170 245 \
    --hide-extension "Микшер громкости.app" \
    --app-drop-link 520 245 \
    --no-internet-enable \
    "$DMG" "$STAGE"

rm -rf "$STAGE"
echo "Готово: $DMG"
