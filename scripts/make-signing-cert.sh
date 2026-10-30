#!/bin/bash
# Token Kuzatuv — doimiy o'z imzosi uchun sertifikat (bir marta, bepul).
#   bash scripts/make-signing-cert.sh
# Vaqtinchalik (ad-hoc) imzo har yig'ishda o'zgaradi va macOS har yangi versiyani boshqa ilova deb biladi —
# «Hujjatlar» papkasi va Keychain ruxsatini qayta so'raydi. Shu sertifikat bilan imzolangan versiyalar bitta ilova
# hisoblanadi: ruxsat bir marta beriladi. build.sh va scripts/release.sh uni nomidan o'zi topadi.
# Apple sertifikati emas: yuklab olgan foydalanuvchiga «noma'lum ishlab chiquvchi» ogohlantirishi avvalgidek chiqadi.
set -euo pipefail

NAME="Token Kuzatuv Local"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "✓ Sertifikat allaqachon bor: $NAME"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS="$(/usr/bin/openssl rand -hex 16)"

cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

# 20 yil: muddati tugasa yangi sertifikat — macOS ruxsatni yana bir marta so'raydi
# macOS'ning o'z LibreSSL'i: Homebrew OpenSSL 3+ yasagan .p12 ni `security import` o'qiy olmaydi
OPENSSL=/usr/bin/openssl
$OPENSSL req -x509 -newkey rsa:2048 -nodes -days 7300 -config "$TMP/cert.cnf" \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem"
$OPENSSL pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" \
    -passout "pass:$PASS" -out "$TMP/cert.p12"
# -T: codesign kalitni har safar parol so'ramasdan ishlatadi
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign >/dev/null

echo "✓ Sertifikat yaratildi: $NAME"
echo "  Keyingi build.sh va reliz shu bilan imzolanadi. Ruxsatni bir marta berasiz, keyin so'ralmaydi."
echo "  Birinchi imzolashda macOS kalitdan foydalanishga ruxsat so'rasa — Mac parolini kiritib «Всегда разрешать» bosing."
