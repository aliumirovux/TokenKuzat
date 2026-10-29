#!/bin/bash
# Token Kuzatuv — tarqatish uchun DMG: universal (Apple Silicon + Intel) ilova, «Applications» yorlig'i bilan.
#   bash scripts/release.sh            dist/TokenKuzatuv-<versiya>.dmg yasaydi
#   bash scripts/release.sh --test     avval testlarni yurgizadi
# Imzo: TK_SIGN_IDENTITY (masalan, «Developer ID Application: …») berilsa — o'sha bilan, aks holda vaqtinchalik (ad-hoc).
# Notarizatsiya: TK_NOTARY_PROFILE (xcrun notarytool store-credentials nomi) va Developer ID imzosi bo'lsa — DMG notarizatsiyadan o'tkaziladi.
set -euo pipefail
cd "$(dirname "$0")/.."

for arg in "$@"; do
    case "$arg" in
        --test) swift test 2>&1 | grep -E "Executed .* tests|error:|failed" | tail -3 ;;
        *) echo "Noma'lum parametr: $arg"; exit 1 ;;
    esac
done

VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD="$(date +%Y%m%d%H%M)"
NAME="Token Kuzatuv"
DIST="dist"
STAGE="$DIST/stage"
APP="$STAGE/$NAME.app"
DMG="$DIST/TokenKuzatuv-$VERSION.dmg"

echo "▸ Universal yig'ish — v$VERSION (arm64 + x86_64)…"
swift build -c release --product TokenKuzat --arch arm64 --arch x86_64 2>&1 | grep -E "error|warning: unre" || true
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/TokenKuzat"
[ -x "$BIN" ] || { echo "✗ Yig'ish muvaffaqiyatsiz"; exit 1; }
[ -f Resources/AppIcon.icns ] || swift scripts/make-icon.swift .

rm -rf "$STAGE" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TokenKuzat"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"

IDENTITY="${TK_SIGN_IDENTITY:-}"
if [ -n "$IDENTITY" ]; then
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
    echo "✓ Imzolandi: $IDENTITY"
else
    codesign --force --sign - "$APP"
    echo "! Developer ID yo'q — vaqtinchalik imzo. Birinchi ochishda macOS ogohlantiradi (README → «O'rnatish»)."
fi
codesign --verify --strict "$APP"

ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$NAME $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"
[ -n "$IDENTITY" ] && codesign --force --timestamp --sign "$IDENTITY" "$DMG"

if [ -n "${TK_NOTARY_PROFILE:-}" ] && [ -n "$IDENTITY" ]; then
    echo "▸ Notarizatsiya…"
    xcrun notarytool submit "$DMG" --keychain-profile "$TK_NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
fi

shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "✓ Tayyor: $DMG ($(du -h "$DMG" | cut -f1))"
