#!/bin/zsh
# Полный релиз одной командой:
#   1. собирает DMG (dist.sh)
#   2. подписывает его ключом Sparkle (sign_update, ключ в Keychain)
#   3. обновляет appcast.xml (фид автообновления)
#   4. коммитит appcast, пушит, создаёт GitHub-релиз с DMG
#
# Использование: поднять версию в Resources/Info.plist
# (CFBundleShortVersionString и CFBundleVersion), затем ./release.sh
#
# Требует: create-dmg, gh (залогиненный), sign_update из дистрибутива Sparkle
# (путь можно переопределить: SIGN_UPDATE=/путь/к/sign_update ./release.sh)
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" Resources/Info.plist)
TAG="v$VERSION"
ASSET="VolumeMixer-$VERSION.dmg"
REPO="djet00/VolumeMixer"

SIGN_UPDATE="${SIGN_UPDATE:-$HOME/.local/bin/sparkle/sign_update}"
[[ -x "$SIGN_UPDATE" ]] || SIGN_UPDATE="$(command -v sign_update || true)"
[[ -x "$SIGN_UPDATE" ]] || { echo "Не найден sign_update (инструменты Sparkle). Задай SIGN_UPDATE=/путь/к/sign_update"; exit 1 }

if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Тег $TAG уже существует — подними версию в Resources/Info.plist"; exit 1
fi

./dist.sh
DMG="build/Микшер громкости $VERSION.dmg"
cp "$DMG" "build/$ASSET"

# Подпись обновления ключом Sparkle из Keychain
SIGNATURE_LINE=$("$SIGN_UPDATE" "build/$ASSET")   # sparkle:edSignature="…" length="…"
echo "Подпись: $SIGNATURE_LINE"

DOWNLOAD_URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"
PUBDATE=$(LC_ALL=en_US.UTF-8 date -u "+%a, %d %b %Y %H:%M:%S +0000")

cat > appcast.xml <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Микшер громкости</title>
        <item>
            <title>Версия $VERSION</title>
            <pubDate>$PUBDATE</pubDate>
            <sparkle:version>$BUILD</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
            <sparkle:releaseNotesLink>https://github.com/$REPO/releases/tag/$TAG</sparkle:releaseNotesLink>
            <enclosure url="$DOWNLOAD_URL" $SIGNATURE_LINE type="application/octet-stream"/>
        </item>
    </channel>
</rss>
APPCAST

git add appcast.xml Resources/Info.plist
git commit -m "release: $VERSION" || true
git tag "$TAG"
git push origin main "$TAG"

gh release create "$TAG" "build/$ASSET#Микшер громкости $VERSION.dmg" \
    --title "Микшер громкости $VERSION" \
    --generate-notes

echo ""
echo "Релиз $TAG опубликован: https://github.com/$REPO/releases/tag/$TAG"
echo "Автообновление подхватят все, у кого версия с Sparkle (1.1+)."
