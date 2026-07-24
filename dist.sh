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

# Ярлык-инструкция: открывает README на разделе «Установка»
# (ярлык с системной ссылкой x-apple.systempreferences macOS не открывает — только http/https)
cat > "$STAGE/Как разрешить запуск.webloc" <<'WEBLOC'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>URL</key>
    <string>https://github.com/djet00/VolumeMixer#установка</string>
</dict>
</plist>
WEBLOC

create-dmg \
    --volname "Микшер громкости" \
    --volicon "Resources/AppIcon.icns" \
    --background "Resources/dmg-background.tiff" \
    --window-pos 200 120 \
    --window-size 640 480 \
    --icon-size 128 \
    --text-size 12 \
    --icon "Микшер громкости.app" 160 275 \
    --hide-extension "Микшер громкости.app" \
    --app-drop-link 480 275 \
    --icon "Как разрешить запуск.webloc" 553 407 \
    --hide-extension "Как разрешить запуск.webloc" \
    --no-internet-enable \
    "$DMG" "$STAGE"

rm -rf "$STAGE"
echo "Готово: $DMG"
