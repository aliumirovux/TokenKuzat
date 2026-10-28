#!/bin/bash
# Token Kuzatuv — yig'adi, ~/Applications ga o'rnatadi va ishga tushiradi.
#   bash build.sh            yig'ish + o'rnatish + ochish
#   bash build.sh --test     avval testlarni yurgizadi
#   bash build.sh --no-open  o'rnatadi, lekin ochmaydi
set -euo pipefail
cd "$(dirname "$0")"

RUN_TESTS=0
OPEN=1
for arg in "$@"; do
    case "$arg" in
        --test) RUN_TESTS=1 ;;
        --no-open) OPEN=0 ;;
        *) echo "Noma'lum parametr: $arg"; exit 1 ;;
    esac
done

if ! command -v swift >/dev/null; then
    echo "✗ Swift topilmadi. Xcode yoki Command Line Tools o'rnating: xcode-select --install"
    exit 1
fi

VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD="$(date +%Y%m%d%H%M)"
APP="$HOME/Applications/Token Kuzatuv.app"

if [ "$RUN_TESTS" = 1 ]; then
    echo "▸ Testlar…"
    swift test 2>&1 | grep -E "Executed|error|failed" | tail -5
fi

echo "▸ Yig'ilmoqda — v$VERSION (birinchi marta 1–2 daqiqa)…"
swift build -c release --product TokenKuzat 2>&1 | grep -Ev "^\[|^Building|^Compiling|^Write" || true
BIN="$(swift build -c release --show-bin-path)/TokenKuzat"
[ -x "$BIN" ] || { echo "✗ Yig'ish muvaffaqiyatsiz"; exit 1; }

[ -f Resources/AppIcon.icns ] || swift scripts/make-icon.swift .

pkill -x TokenKuzat 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TokenKuzat"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"

# Doimiy sertifikat bo'lsa (Xcode → Settings → Accounts'da Apple ID bilan kirilgan) — o'sha bilan imzolanadi:
# macOS yangi build'larni ham tanib, Keychain ruxsatini qayta so'ramaydi. Bo'lmasa — vaqtinchalik (ad-hoc) imzo.
IDENTITY="${TK_SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development[^"]*\)".*/\1/p' | head -1)}"
if [ -n "$IDENTITY" ]; then
  codesign --force --sign "$IDENTITY" "$APP" >/dev/null 2>&1 && echo "✓ Imzolandi: $IDENTITY" \
    || { echo "! '$IDENTITY' bilan imzolab bo'lmadi — vaqtinchalik imzo"; codesign --force --sign - "$APP" >/dev/null 2>&1; }
else
  codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "! Imzolab bo'lmadi (ilova baribir ishlaydi)"
fi

echo "✓ O'rnatildi: $APP"
if [ "$OPEN" = 1 ]; then
    open "$APP"
    echo "  Menyu satrining o'ng tomonida grafik belgisi paydo bo'ldi."
fi
