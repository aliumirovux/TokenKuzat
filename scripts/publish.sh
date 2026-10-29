#!/bin/bash
# Token Kuzatuv — GitHub relizi: testlar, DMG (release.sh), teg va reliz bir buyruqda.
#   bash scripts/publish.sh                  VERSION dagi versiyani chiqaradi
#   bash scripts/publish.sh --notes FAYL     «Yangiliklar» qismi shu fayldan (aks holda CHANGELOG'dan)
#   bash scripts/publish.sh --dry-run        relizni yaratmaydi, faqat matnini ko'rsatadi
# Talab: o'zgarishlar commit qilingan va push qilingan, `gh` tizimga kirgan.
set -euo pipefail
cd "$(dirname "$0")/.."

NOTES_FILE=""
DRY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --notes) NOTES_FILE="$2"; shift 2 ;;
        --dry-run) DRY=1; shift ;;
        *) echo "Noma'lum parametr: $1"; exit 1 ;;
    esac
done

VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="v$VERSION"
DMG="dist/TokenKuzatuv-$VERSION.dmg"

gh auth status >/dev/null 2>&1 || { echo "✗ gh tizimga kirmagan: gh auth login"; exit 1; }
if gh release view "$TAG" >/dev/null 2>&1; then echo "✗ $TAG relizi allaqachon bor"; exit 1; fi
if [ $DRY = 0 ]; then
    [ -z "$(git status --porcelain)" ] || { echo "✗ Commit qilinmagan o'zgarishlar bor"; exit 1; }
    git fetch -q origin main
    [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "✗ main push qilinmagan yoki orqada"; exit 1; }
fi

# Oxirgi relizdan beri CHANGELOG bo'limlari («## X.Y.Z» sarlavhalar orasidagi matn)
PREV="$(gh release list --limit 1 --exclude-drafts --json tagName -q '.[0].tagName' | sed 's/^v//')"
changelog_since() {
    awk -v prev="$1" '
        /^## / { split($2, v, " "); if (v[1] == prev) exit; on = 1 }
        on { print }
    ' CHANGELOG.md
}

if [ -n "$NOTES_FILE" ]; then
    NEWS="$(cat "$NOTES_FILE")"
else
    NEWS="$(changelog_since "$PREV" | sed -e 's/^## \(.*\)/#### \1/')"
fi

BODY="$(mktemp)"
trap 'rm -f "$BODY"' EXIT
write_body() {
    cat > "$BODY" <<EOF
**Token Kuzatuv** — Claude Code tokenlari qayerga ketayotganini jonli ko'rsatadigan macOS menyu satri ilovasi. ⚠️ **Test rejimi.**

### Yangiliklar (${PREV:-birinchi reliz} dan beri)
$NEWS

### O'rnatish
1. \`TokenKuzatuv-$VERSION.dmg\` ni yuklab oling, oching va **Token Kuzatuv**ni **Applications**ga sudrang (Apple Silicon va Intel, macOS 13+).
2. Ilova hali Apple Developer ID bilan imzolanmagan, shuning uchun birinchi ochishda macOS bloklaydi: ilovani bir marta oching, keyin **System Settings → Privacy & Security → Open Anyway**.
   Yoki Terminal'da: \`xattr -dr com.apple.quarantine "/Applications/Token Kuzatuv.app"\`

Oldingi versiya o'rnatilgan bo'lsa, ilova bu versiyani o'zi topib, menyu panelida «yuklab olish» havolasini ko'rsatadi.

To'liq o'zgarishlar: [CHANGELOG.md](https://github.com/aliumirovux/TokenKuzat/blob/main/CHANGELOG.md)
EOF
    if [ -f "$DMG.sha256" ]; then
        printf '\nSHA-256 (`%s`): `%s`\n' "$(basename "$DMG")" "$(cut -d' ' -f1 < "$DMG.sha256")" >> "$BODY"
    fi
}

if [ $DRY = 1 ]; then
    write_body
    cat "$BODY"
    exit 0
fi

bash scripts/release.sh --test
write_body

git tag -a "$TAG" -m "Token Kuzatuv $VERSION"
git push -q origin "$TAG"
gh release create "$TAG" "$DMG" "$DMG.sha256" \
    --title "Token Kuzatuv $VERSION (test)" --notes-file "$BODY" --latest
echo "✓ Chiqdi: $(gh release view "$TAG" --json url -q .url)"
